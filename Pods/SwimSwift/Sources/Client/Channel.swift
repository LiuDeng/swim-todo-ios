import Foundation
import Recon

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

    private var credentials: Value = Value.Absent

    init(host: SwimUri, protocols: [String] = []) {
        self.hostUri = host
        self.protocols = protocols
        self.uriCache = UriCache(baseUri: host)
    }

    var isConnected: Bool {
        return socket != nil && socket!.readyState == .Open
    }

    func resolve(uri: SwimUri) -> SwimUri {
        return uriCache.resolve(uri)
    }

    func unresolve(uri: SwimUri) -> SwimUri {
        return uriCache.unresolve(uri)
    }


    func scope(node node: SwimUri) -> NodeScope {
        return RemoteNode(channel: self, host: hostUri, node: node)
    }

    func scope(node node: SwimUri, lane: SwimUri) -> LaneScope {
        return RemoteLane(channel: self, host: hostUri, node: node, lane: lane)
    }

    func downlink() -> DownlinkBuilder {
        return RemoteDownlinkBuilder(channel: self)
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

    func syncList(scope scope: RemoteScope?, node: SwimUri, lane: SwimUri, prio: Double) -> RemoteListDownlink {
        let downlink = RemoteListDownlink(channel: self, scope: scope, host: hostUri, node: resolve(node), lane: lane, prio: prio)
        registerDownlink(downlink)
        return downlink
    }

    func syncList(node node: SwimUri, lane: SwimUri, prio: Double) -> ListDownlink {
        return syncList(scope: nil, node: node, lane: lane, prio: prio)
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
        if var nodeDownlinks = downlinks[node] {
            if var laneDownlinks = nodeDownlinks[lane] {
                if laneDownlinks.remove(downlink) != nil {
                    if laneDownlinks.isEmpty {
                        nodeDownlinks.removeValueForKey(lane)
                        if nodeDownlinks.isEmpty {
                            downlinks.removeValueForKey(node)
                            watchIdle()
                        }
                        if socket?.readyState == .Open {
                            let request = UnlinkRequest(node: unresolve(node), lane: lane)
                            downlink.onUnlinkRequest(request)
                            push(envelope: request)
                        }
                    }
                    downlink.onClose()
                }
            }
        }
    }


    private func onEnvelope(envelope: Envelope) {
        log.verbose("\(envelope)")

        switch envelope {
        case let message as EventMessage:
            onEventMessage(message)
        case let message as CommandMessage:
            onCommandMessage(message)
        case let request as LinkRequest:
            onLinkRequest(request)
        case let response as LinkedResponse:
            onLinkedResponse(response)
        case let request as SyncRequest:
            onSyncRequest(request)
        case let response as SyncedResponse:
            onSyncedResponse(response)
        case let request as UnlinkRequest:
            onUnlinkRequest(request)
        case let response as UnlinkedResponse:
            onUnlinkedResponse(response)
        default:
            log.warning("Unknown envelope \(envelope)")
        }
    }

    private func onEventMessage(message: EventMessage) {
        let node = resolve(message.node)
        let lane = message.lane
        if let nodeDownlinks = downlinks[node] {
            if let laneDownlinks = nodeDownlinks[lane] {
                let resolvedMessage = message.withNode(node)
                for downlink in laneDownlinks {
                    downlink.onEventMessage(resolvedMessage)
                }
            }
        }
    }

    private func onCommandMessage(message: CommandMessage) {
        // TODO: Support client services.
    }

    private func onLinkRequest(request: LinkRequest) {
        // TODO: Support client services.
    }

    private func onLinkedResponse(response: LinkedResponse) {
        let node = resolve(response.node)
        let lane = response.lane
        if let nodeDownlinks = downlinks[node] {
            if let laneDownlinks = nodeDownlinks[lane] {
                let resolvedResponse = response.withNode(node)
                for downlink in laneDownlinks {
                    downlink.onLinkedResponse(resolvedResponse)
                }
            }
        }
    }

    private func onSyncRequest(request: SyncRequest) {
        // TODO: Support client services.
    }

    private func onSyncedResponse(response: SyncedResponse) {
        let node = resolve(response.node)
        let lane = response.lane
        if let nodeDownlinks = downlinks[node] {
            if let laneDownlinks = nodeDownlinks[lane] {
                let resolvedResponse = response.withNode(node)
                for downlink in laneDownlinks {
                    downlink.onSyncedResponse(resolvedResponse)
                }
            }
        }
    }

    private func onUnlinkRequest(request: UnlinkRequest) {
        // TODO: Support client services.
    }

    private func onUnlinkedResponse(response: UnlinkedResponse) {
        let node = resolve(response.node)
        let lane = response.lane
        if var nodeDownlinks = downlinks[node] {
            if let laneDownlinks = nodeDownlinks[lane] {
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
            socket = WebSocket(hostUri.uri, subProtocols: protocols)
            socket!.delegate = self
        }
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
        reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(reconnectTimeout, target: self, selector: "doReconnect:", userInfo: nil, repeats: false)
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
            idleTimer = NSTimer.scheduledTimerWithTimeInterval(idleTimeout, target: self, selector: "checkIdle:", userInfo: nil, repeats: false)
        }
    }

    @objc private func checkIdle(timer: NSTimer) {
        if sendBuffer.isEmpty && downlinks.isEmpty {
            log.verbose("Channel is idle.")
            close()
        }
    }

    func push(envelope envelope: Envelope) {
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
        if let envelope = Proto.parse(recon: text) {
            onEnvelope(envelope)
        }
    }

    @objc func webSocketError(error: NSError) {
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
