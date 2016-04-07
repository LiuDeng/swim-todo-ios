import Foundation
import Recon
import SwiftWebSocket

private let log = SwimLogging.log


class Channel: HostScope, WebSocketDelegate {
    let hostUri: SwimUri

    private let protocols: [String]

    private var uriCache: UriCache

    private var downlinks = [SwimUri: [SwimUri: Set<RemoteDownlink>]]()

    private var sendBuffer = [Envelope]()

    private var reconnectTimer: NSTimer?

    private var reconnectTimeout: NSTimeInterval = 0.0

    private var idleTimer: NSTimer?

    private let idleTimeout: NSTimeInterval = 30.0 // TODO: make configurable

    private let sendBufferSize: Int = 1024 // TODO: make configurable

    private var socket: WebSocket?
    private let socketQueue = dispatch_queue_create("it.swim.Channel", DISPATCH_QUEUE_SERIAL)

    private var pendingMessages: Batcher<Envelope>!

    private var credentials: Value = Value.Absent

    private var networkMonitor: SwimNetworkConditionMonitor.ServerMonitor?

    init(host: SwimUri, protocols: [String] = []) {
        self.hostUri = host
        self.protocols = protocols
        self.uriCache = UriCache(baseUri: host)

        pendingMessages = Batcher<Envelope>(minDelay: 0.01, maxDelay: 0.1, dispatchQueue: dispatch_get_main_queue(), onBatch: { [weak self] messages in
            self?.handlePendingMessages(messages)
        })
    }

    var isConnected: Bool {
        return socket != nil && socket!.readyState == .Open
    }

    private func resolve(uri: SwimUri) -> SwimUri {
        return uriCache.resolve(uri)
    }

    private func unresolve(uri: SwimUri) -> SwimUri {
        return uriCache.unresolve(uri)
    }


    func link(scope scope: RemoteScope?, node: SwimUri, lane: SwimUri, prio: Double) -> RemoteDownlink {
        let downlink = RemoteLinkedDownlink(channel: self, scope: scope, host: hostUri, node: resolve(node), lane: lane, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func link(node node: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        return link(scope: nil, node: node, lane: lane, prio: prio)
    }

    func sync(scope scope: RemoteScope?, node: SwimUri, lane: SwimUri, prio: Double) -> RemoteDownlink {
        let downlink = RemoteSyncedDownlink(channel: self, scope: scope, host: hostUri, node: resolve(node), lane: lane, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func sync(node node: SwimUri, lane: SwimUri, prio: Double) -> Downlink {
        return sync(scope: nil, node: node, lane: lane, prio: prio)
    }

    func syncList(scope scope: RemoteScope?, node: SwimUri, lane: SwimUri, prio: Double, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ListDownlink {
        let downlink = RemoteListDownlink(channel: self, scope: scope, host: hostUri, node: resolve(node), lane: lane, prio: prio, objectMaker: objectMaker)
        registerDownlink(downlink)
        return downlink
    }

    func syncList(node node: SwimUri, lane: SwimUri, prio: Double, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ListDownlink {
        return syncList(scope: nil, node: node, lane: lane, prio: prio, objectMaker: objectMaker)
    }

    func syncMap(scope scope: RemoteScope?, node: SwimUri, lane: SwimUri, prio: Double, primaryKey: Value -> Value) -> RemoteMapDownlink {
        let downlink = RemoteMapDownlink(channel: self, scope: scope, host: hostUri, node: resolve(node), lane: lane, prio: prio, primaryKey: primaryKey)
        registerDownlink(downlink)
        return downlink
    }

    func syncMap(node node: SwimUri, lane: SwimUri, prio: Double, primaryKey: Value -> Value) -> MapDownlink {
        return syncMap(scope: nil, node: node, lane: lane, prio: prio, primaryKey: primaryKey)
    }

    func command(node node: SwimUri, lane: SwimUri, body: Value) {
        let message = CommandMessage(node: unresolve(node), lane: lane, body: body)
        push(envelope: message)
    }

    func pushLinkRequest(node node: SwimUri, lane: SwimUri, prio: Double) {
        let request = LinkRequest(node: unresolve(node), lane: lane, prio: prio)
        push(envelope: request)
    }

    func pushSyncRequest(node node: SwimUri, lane: SwimUri, prio: Double) {
        let request = SyncRequest(node: unresolve(node), lane: lane, prio: prio)
        push(envelope: request)
    }

    func pushUnlinkRequest(node node: SwimUri, lane: SwimUri) {
        let request = UnlinkRequest(node: unresolve(node), lane: lane)
        push(envelope: request)
    }

    func auth(credentials credentials: Value) {
        self.credentials = credentials
        if socket?.readyState == .Open {
            let request = AuthRequest(body: credentials)
            push(envelope: request)
        }
    }

    func registerDownlink(downlink: RemoteDownlink) {
        clearIdle()
        let node = downlink.nodeUri
        let lane = downlink.laneUri
        var nodeDownlinks = downlinks[node] ?? [SwimUri: Set<RemoteDownlink>]()
        var laneDownlinks = nodeDownlinks[lane] ?? Set<RemoteDownlink>()
        laneDownlinks.insert(downlink)
        nodeDownlinks[lane] = laneDownlinks
        downlinks[node] = nodeDownlinks
        if socket?.readyState == .Open {
            downlink.onConnect()
        } else {
            open()
        }
    }

    func unregisterDownlink(downlink: RemoteDownlink) {
        let node = downlink.nodeUri
        let lane = downlink.laneUri
        guard var nodeDownlinks = downlinks[node], laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        laneDownlinks.remove(downlink)
        if laneDownlinks.isEmpty {
            nodeDownlinks.removeValueForKey(lane)
            if nodeDownlinks.isEmpty {
                downlinks.removeValueForKey(node)
                watchIdle()
            }
            if socket?.readyState == .Open {
                let request = UnlinkRequest(node: unresolve(node), lane: lane)
                downlink.onUnlinkRequest()
                push(envelope: request)
            }
        }
        downlink.onClose()
    }


    private func onEventMessages(messages: [EventMessage]) {
        var resolvedMessages = [SwimUri: [SwimUri: [EventMessage]]]()
        for message in messages {
            let node = resolve(message.node)
            let lane = message.lane
            let resolvedMessage = message.withNode(node)

            var nodeMessages = resolvedMessages[node] ?? [SwimUri: [EventMessage]]()
            var laneMessages = nodeMessages[lane] ?? [EventMessage]()
            laneMessages.append(resolvedMessage)
            nodeMessages[lane] = laneMessages
            resolvedMessages[node] = nodeMessages
        }

        for (node, nodeMessages) in resolvedMessages {
            for (lane, laneMessages) in nodeMessages {
                if let nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] {
                    for downlink in laneDownlinks {
                        downlink.onEventMessages(laneMessages)
                    }
                }
            }
        }
    }

    private func onCommandMessages(messages: [CommandMessage]) {
        // TODO: Support client services.
    }

    private func onLinkRequest(request: LinkRequest) {
        // TODO: Support client services.
    }

    private func onLinkedResponse(response: LinkedResponse) {
        let node = resolve(response.node)
        let lane = response.lane
        guard let nodeDownlinks = downlinks[node], laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        let resolvedResponse = response.withNode(node)
        for downlink in laneDownlinks {
            downlink.onLinkedResponse(resolvedResponse)
        }
    }

    private func onSyncRequest(request: SyncRequest) {
        // TODO: Support client services.
    }

    private func onSyncedResponse(response: SyncedResponse) {
        let node = resolve(response.node)
        let lane = response.lane
        guard let nodeDownlinks = downlinks[node], laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        let resolvedResponse = response.withNode(node)
        for downlink in laneDownlinks {
            downlink.onSyncedResponse(resolvedResponse)
        }
    }

    private func onUnlinkRequest(request: UnlinkRequest) {
        // TODO: Support client services.
    }

    private func onUnlinkedResponse(response: UnlinkedResponse) {
        let node = resolve(response.node)
        let lane = response.lane
        guard var nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        nodeDownlinks.removeValueForKey(lane)
        if nodeDownlinks.isEmpty {
            downlinks.removeValueForKey(node)
        }
        let resolvedResponse = response.withNode(node)
        for downlink in laneDownlinks {
            downlink.onUnlinkedResponse(resolvedResponse)
            downlink.onClose()
        }
    }

    private func onConnect() {
        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                for downlink in laneDownlinks {
                    downlink.onConnect()
                }
            }
        }
    }

    private func onDisconnect() {
        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                for downlink in laneDownlinks {
                    downlink.onDisconnect()
                }
            }
        }
    }

    private func onError(error: NSError) {
        log.info("\(error)")

        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                for downlink in laneDownlinks {
                    downlink.onError(error)
                }
            }
        }
    }


    private func open() {
        log.verbose("")

        if let timer = reconnectTimer {
            timer.invalidate()
            reconnectTimer = nil
            reconnectTimeout = 0.0
        }
        if socket == nil {
            startNetworkMonitor(hostUri.authority!.host.description)

            let s = WebSocket(hostUri.uri, subProtocols: protocols)
            s.eventQueue = socketQueue
            s.delegate = self
            socket = s
        }
    }

    private func startNetworkMonitor(host: String) {
        let globals = SwimGlobals.instance
        if globals.networkConditionMonitor == nil {
            globals.networkConditionMonitor = SwimNetworkConditionMonitor()
        }
        networkMonitor = globals.networkConditionMonitor.startMonitoring(host)
    }

    func close() {
        log.verbose("")

        clearIdle()
        socket?.close()
        socket = nil
        let downlinks = self.downlinks
        self.downlinks.removeAll()
        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                for downlink in laneDownlinks {
                    downlink.onClose()
                }
            }
        }

        if let monitor = networkMonitor {
            let ncm = SwimGlobals.instance.networkConditionMonitor
            ncm.stopMonitoring(monitor)
            networkMonitor = nil
        }
    }

    private func reconnect() {
        if reconnectTimer != nil {
            return
        }
        if reconnectTimeout == 0.0 {
            let jitter = Double(arc4random()) / 0xFFFFFFFF // 0..1
            reconnectTimeout = 0.5 + jitter
        } else {
            reconnectTimeout = min(1.8 * reconnectTimeout, 30.0)
        }
        reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(reconnectTimeout, target: self, selector: #selector(Channel.doReconnect(_:)), userInfo: nil, repeats: false)
    }

    @objc private func doReconnect(timer: NSTimer) {
        self.open()
    }

    private func clearIdle() {
        if let timer = idleTimer {
            timer.invalidate()
            idleTimer = nil
        }
    }

    private func watchIdle() {
        if socket?.readyState == .Open && sendBuffer.isEmpty && downlinks.isEmpty {
            idleTimer = NSTimer.scheduledTimerWithTimeInterval(idleTimeout, target: self, selector: #selector(Channel.checkIdle(_:)), userInfo: nil, repeats: false)
        }
    }

    @objc private func checkIdle(timer: NSTimer) {
        if sendBuffer.isEmpty && downlinks.isEmpty {
            log.verbose("Channel is idle.")
            close()
        }
    }

    private func push(envelope envelope: Envelope) {
        if socket?.readyState == .Open {
            clearIdle()
            let text = envelope.recon
            socket!.send(text)
            watchIdle()
        } else if envelope is CommandMessage {
            if sendBuffer.count < sendBufferSize {
                sendBuffer.append(envelope)
            } else {
                // TODO
                log.error("Send buffer overflow! Handling this situation is unimplemented; the message has been dropped. \(envelope)")
            }
            open()
        } else {
            log.error("Buffering this message is unimplemented; the message has been dropped! \(envelope)")
        }
    }


    private func handlePendingMessages(messages: [Envelope]) {
        var commandBatch = [CommandMessage]()
        var eventBatch = [EventMessage]()

        func flushCommandBatch() {
            if commandBatch.count > 0 {
                onCommandMessages(commandBatch)
                commandBatch = []
            }
        }

        func flushEventBatch() {
            if eventBatch.count > 0 {
                onEventMessages(eventBatch)
                eventBatch = []
            }
        }

        func flushAllBatches() {
            flushCommandBatch()
            flushEventBatch()
        }

        for envelope in messages {
            log.verbose("\(envelope)")

            switch envelope {
            case let message as EventMessage:
                flushCommandBatch()
                eventBatch.append(message)

            case let message as CommandMessage:
                flushEventBatch()
                commandBatch.append(message)

            case let request as LinkRequest:
                flushAllBatches()
                onLinkRequest(request)

            case let response as LinkedResponse:
                flushAllBatches()
                onLinkedResponse(response)

            case let request as SyncRequest:
                flushAllBatches()
                onSyncRequest(request)

            case let response as SyncedResponse:
                flushAllBatches()
                onSyncedResponse(response)

            case let request as UnlinkRequest:
                flushAllBatches()
                onUnlinkRequest(request)

            case let response as UnlinkedResponse:
                flushAllBatches()
                onUnlinkedResponse(response)

            default:
                log.warning("Unknown envelope \(envelope)")
            }
        }

        flushAllBatches()
    }


    // MARK: WebSocketDelegate

    @objc func webSocketOpen() {
        if credentials.isDefined {
            let request = AuthRequest(body: credentials)
            push(envelope: request)
        }
        onConnect()
        let sendBuffer = self.sendBuffer
        self.sendBuffer.removeAll()
        for envelope in sendBuffer {
            push(envelope: envelope)
        }
        watchIdle()
    }

    @objc func webSocketMessageText(text: String) {
        networkMonitor?.networkResponseReceived()

        guard let envelope = Proto.parse(recon: text) else {
            log.warning("Received unparsable message \(text)")
            return
        }

        pendingMessages.addObject(envelope)
    }

    @objc func webSocketError(error: NSError) {
        networkMonitor?.networkErrorReceived()

        onError(error)
        clearIdle()
        socket?.delegate = nil
        socket?.close()
        socket = nil
    }

    @objc func webSocketClose(code: Int, reason: String, wasClean: Bool) {
        socket = nil
        onDisconnect()
        clearIdle()
        if !sendBuffer.isEmpty || !downlinks.isEmpty {
            reconnect()
        }
    }
}
