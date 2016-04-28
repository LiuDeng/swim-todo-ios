import Foundation
import Recon
import SwiftWebSocket


private let log = SwimLogging.log


class Channel: WebSocketDelegate {
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


    func link(node node: SwimUri, lane: SwimUri, properties: LaneProperties) -> Downlink {
        let downlink = RemoteLinkedDownlink(channel: self, host: hostUri, node: resolve(node), lane: lane, laneProperties: properties)
        registerDownlink(downlink)
        return downlink
    }

    func sync(node node: SwimUri, lane: SwimUri, properties: LaneProperties) -> Downlink {
        let downlink = RemoteSyncedDownlink(channel: self, host: hostUri, node: resolve(node), lane: lane, laneProperties: properties)
        registerDownlink(downlink)
        return downlink
    }

    func syncList(node node: SwimUri, lane: SwimUri, properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> ListDownlink {
        let (remoteDownlink, listDownlink) = createListDownlinks(node: node, lane: lane, properties: properties, objectMaker: objectMaker)

        registerDownlink(remoteDownlink)

        return listDownlink
    }

    /**
     - returns: The RemoteDownlink that's actually connected to the server,
     and the Downlink that is to be returned to the caller.  If this request
     is for a transient lane then these two will be equal, otherwise the
     second Downlink will impose the requested persistence.
     */
    private func createListDownlinks(node node: SwimUri, lane: SwimUri, properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?)) -> (RemoteDownlink, ListDownlink) {
        let nodeUri = resolve(node)
        let remoteDownlink = RemoteDownlink(channel: self, host: hostUri, node: nodeUri, lane: lane, laneProperties: properties)

        if properties.isTransient {
            let listDownlink = ListDownlinkAdapter(downlink: remoteDownlink, objectMaker: objectMaker)
            return (remoteDownlink, listDownlink)
        }

        let globals = SwimGlobals.instance
        if globals.dbManager == nil {
            globals.dbManager = SwimDBManager()
        }
        let laneFQUri = SwimUri("\(nodeUri)/\(lane)")!
        let listDownlink = PersistentListDownlink(downlink: remoteDownlink, objectMaker: objectMaker, laneFQUri: laneFQUri)
        listDownlink.loadFromDBAsync()

        return (remoteDownlink, listDownlink)
    }


    func syncMap(node node: SwimUri, lane: SwimUri, properties: LaneProperties, primaryKey: Value -> Value) -> MapDownlink {
        let downlink = RemoteMapDownlink(channel: self, host: hostUri, node: resolve(node), lane: lane, laneProperties: properties, primaryKey: primaryKey)
        registerDownlink(downlink)
        return downlink
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


    private func onAcks(acks: [AckResponse]) {
        log.verbose("Received acks: \(acks)")

        let resolvedMessages = resolveAndSortMessages(acks)
        routeMessages(resolvedMessages) { downlink, laneMessages in
            downlink.onAcks(laneMessages)
        }
    }


    private func onEventMessages(messages: [EventMessage]) {
        let resolvedMessages = resolveAndSortMessages(messages)
        routeMessages(resolvedMessages) { downlink, laneMessages in
            downlink.onEventMessages(laneMessages)
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
        response.node = node
        let lane = response.lane
        guard let nodeDownlinks = downlinks[node], laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        for downlink in laneDownlinks {
            downlink.onLinkedResponse(response)
        }
    }

    private func onSyncRequest(request: SyncRequest) {
        // TODO: Support client services.
    }

    private func onSyncedResponse(response: SyncedResponse) {
        let node = resolve(response.node)
        response.node = node
        let lane = response.lane
        guard let nodeDownlinks = downlinks[node], laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        for downlink in laneDownlinks {
            downlink.onSyncedResponse(response)
        }
    }

    private func onUnlinkRequest(request: UnlinkRequest) {
        // TODO: Support client services.
    }

    private func onUnlinkedResponse(response: UnlinkedResponse) {
        let node = resolve(response.node)
        response.node = node
        let lane = response.lane
        guard var nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        nodeDownlinks.removeValueForKey(lane)
        if nodeDownlinks.isEmpty {
            downlinks.removeValueForKey(node)
        }
        for downlink in laneDownlinks {
            downlink.onUnlinkedResponse(response)
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

    private func onError(error_: NSError) {
        log.info("\(error_)")

        var error = error_
        if error.domain == "SwiftWebSocket.WebSocketError" {
            error = SwimError.NetworkError as NSError
        }

        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                for downlink in laneDownlinks {
                    downlink.onError(error)
                }
            }
        }
    }


    private func resolveAndSortMessages<T where T : RoutableEnvelope>(messages: [T]) -> [SwimUri: [SwimUri: [T]]] {
        var result = [SwimUri: [SwimUri: [T]]]()
        for message in messages {
            let node = resolve(message.node)
            message.node = node
            let lane = message.lane

            var nodeMessages = result[node] ?? [SwimUri: [T]]()
            var laneMessages = nodeMessages[lane] ?? [T]()
            laneMessages.append(message)
            nodeMessages[lane] = laneMessages
            result[node] = nodeMessages
        }
        return result
    }


    private func routeMessages<T where T : RoutableEnvelope>(messages: [SwimUri: [SwimUri: [T]]], _ f: (RemoteDownlink, [T]) -> Void) {
        for (node, nodeMessages) in messages {
            for (lane, laneMessages) in nodeMessages {
                if let nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] {
                    for downlink in laneDownlinks {
                        f(downlink, laneMessages)
                    }
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


    func closeDownlinks(node node: SwimUri) {
        let node = resolve(node)
        guard let nodeDownlinks = downlinks[node] else {
            return
        }
        downlinks.removeValueForKey(node)

        for laneDownlinks in nodeDownlinks.values {
            laneDownlinks.forEach {
                $0.onClose()
            }
        }
    }


    func closeDownlinks(node node: SwimUri, lane: SwimUri) {
        let node = resolve(node)
        guard var nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] else {
            return
        }
        nodeDownlinks.removeValueForKey(lane)
        downlinks[node] = nodeDownlinks

        laneDownlinks.forEach {
            $0.onClose()
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
        var ackBatch = [AckResponse]()
        var commandBatch = [CommandMessage]()
        var eventBatch = [EventMessage]()

        func flushAckBatch() {
            if ackBatch.count > 0 {
                onAcks(ackBatch)
                ackBatch = []
            }
        }

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
            flushAckBatch()
            flushCommandBatch()
            flushEventBatch()
        }

        for envelope in messages {
            log.verbose("\(envelope)")

            switch envelope {
            case let message as EventMessage:
                flushAckBatch()
                flushCommandBatch()
                eventBatch.append(message)

            case let message as CommandMessage:
                flushAckBatch()
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

            case let ack as AckResponse:
                flushCommandBatch()
                flushEventBatch()
                ackBatch.append(ack)

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
