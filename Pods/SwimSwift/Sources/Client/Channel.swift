import Bolts
import Foundation
import Recon
import SwiftWebSocket


private let log = SwimLogging.log

private let idleTimeout: NSTimeInterval = 30.0
private let sendBufferSize: Int = 1024


/**
 Note that Channel is handling the WebSocket, which often calls on a
 background thread.  Channel is responsible for getting all calls to
 Downlink onto the main thread so that the UI layer can handle delegate
 callbacks and model objects easily.
 */
class Channel: WebSocketDelegate {
    let hostUri: SwimUri

    private let protocols: [String]

    private var uriCache: UriCache

    /// May only be accessed under objc_sync_enter(self).
    private var downlinks = [SwimUri: [SwimUri: Set<RemoteDownlink>]]()

    /**
     Retry managers, one per lane.  These are responsible for making sure
     that writes are pushed back to the server whenever we can.  Note
     that nothing ever leaves this dictionary, even once the lane is
     deregistered.  That way, if the downlink is closed then we'll
     still be there to retry when it is re-opened.

     May only be accessed under objc_sync_enter(self).
     */
    private var retryManagers = [SwimUri: OplogRetryManager]()

    /// May only be accessed under objc_sync_enter(self).
    private var sendBuffer = [Envelope]()

    /// May only be accessed under objc_sync_enter(self).
    private var reconnectTimer: NSTimer?

    /// May only be accessed under objc_sync_enter(self).
    private var reconnectTimeout: NSTimeInterval = 0.0

    /// May only be accessed under objc_sync_enter(self).
    private var idleTimer: NSTimer?

    /// May only be accessed under objc_sync_enter(self).
    private var socket: WebSocket?

    private let socketQueue = dispatch_queue_create("it.swim.Channel", DISPATCH_QUEUE_SERIAL)

    private var pendingMessages: Batcher<Envelope>!

    /// May only be accessed under objc_sync_enter(self).
    private var credentials: Value = Value.Absent

    /// May only be accessed under objc_sync_enter(self).
    private var networkMonitor: SwimNetworkConditionMonitor.ServerMonitor?

    /**
     AuthRequests that have been sent to the server and for which we have
     not yet received an AuthedResponse.
     */
    private let inFlightAuthRequests = TaskQueue()


    init(host: SwimUri, protocols: [String] = []) {
        self.hostUri = host
        self.protocols = protocols
        self.uriCache = UriCache(baseUri: host)

        pendingMessages = Batcher<Envelope>(minDelay: 0.01, maxDelay: 0.1, dispatchQueue: dispatch_get_main_queue(), onBatch: { [weak self] messages in
            self?.handlePendingMessages(messages)
        })
    }

    var isConnected: Bool {
        objc_sync_enter(self)
        let result = (socket != nil && socket!.readyState == .Open)
        objc_sync_exit(self)
        return result
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

        startDBManagerIfNecessary()

        let laneFQUri = SwimUri("\(nodeUri)/\(lane)")!

        let retryManager = retryManagerForLane(node: node, lane: lane, laneFQUri: laneFQUri, remoteDownlink: remoteDownlink)

        let listDownlink = PersistentListDownlink(downlink: remoteDownlink, objectMaker: objectMaker, laneFQUri: laneFQUri, retryManager: retryManager)
        listDownlink.loadFromDBAsync()

        return (remoteDownlink, listDownlink)
    }


    func syncMap(node node: SwimUri, lane: SwimUri, properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?), primaryKey: SwimModelProtocolBase -> SwimValue) -> MapDownlink {
        let (remoteDownlink, mapDownlink) = createMapDownlinks(node: node, lane: lane, properties: properties, objectMaker: objectMaker, primaryKey: primaryKey)

        registerDownlink(remoteDownlink)

        return mapDownlink
    }

    /**
     - returns: The RemoteDownlink that's actually connected to the server,
     and the Downlink that is to be returned to the caller.  If this request
     is for a transient lane then these two will be equal, otherwise the
     second Downlink will impose the requested persistence.
     */
    private func createMapDownlinks(node node: SwimUri, lane: SwimUri, properties: LaneProperties, objectMaker: (SwimValue -> SwimModelProtocolBase?), primaryKey: SwimModelProtocolBase -> SwimValue) -> (RemoteDownlink, MapDownlink) {
        let nodeUri = resolve(node)
        let remoteDownlink = RemoteDownlink(channel: self, host: hostUri, node: nodeUri, lane: lane, laneProperties: properties)

        if properties.isTransient {
            let mapDownlink = MapDownlinkAdapter(downlink: remoteDownlink, objectMaker: objectMaker, primaryKey: primaryKey)
            return (remoteDownlink, mapDownlink)
        }
        else {
            preconditionFailure("Persistent maps unimplemented")
        }
    }


    private func startDBManagerIfNecessary() {
        let globals = SwimGlobals.instance

        objc_sync_enter(globals)

        if globals.dbManager == nil {
            globals.dbManager = SwimDBManager()
        }

        objc_sync_exit(globals)
    }

    private func retryManagerForLane(node node: SwimUri, lane: SwimUri, laneFQUri: SwimUri, remoteDownlink: RemoteDownlink) -> OplogRetryManager {
        objc_sync_enter(self)

        var mgr = retryManagers[lane]
        if mgr == nil {
            startNetworkMonitorIfNecessary()
            mgr = OplogRetryManager(laneFQUri: laneFQUri, downlink: remoteDownlink, dbManager: SwimGlobals.instance.dbManager!, networkMonitor: networkMonitor!)
            retryManagers[lane] = mgr
        }

        objc_sync_exit(self)
        return mgr!
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

    func auth(credentials credentials: Value) -> BFTask {
        objc_sync_enter(self)
        self.credentials = credentials
        objc_sync_exit(self)

        if socket?.readyState == .Open {
            let request = AuthRequest(body: credentials)
            push(envelope: request)
        }
        else if socket == nil {
            open()
        }

        let task = BFTaskCompletionSource()
        inFlightAuthRequests.append(task)
        return task.task
    }

    func registerDownlink(downlink: RemoteDownlink) {
        let node = downlink.nodeUri
        let lane = downlink.laneUri

        objc_sync_enter(self)

        clearIdle()

        var nodeDownlinks = downlinks[node] ?? [SwimUri: Set<RemoteDownlink>]()
        var laneDownlinks = nodeDownlinks[lane] ?? Set<RemoteDownlink>()
        laneDownlinks.insert(downlink)
        nodeDownlinks[lane] = laneDownlinks
        downlinks[node] = nodeDownlinks

        let isOpen = (socket?.readyState == .Open)

        objc_sync_exit(self)

        if isOpen {
            downlink.onConnect()
        }
        else {
            open()
        }
    }

    func unregisterDownlink(downlink: RemoteDownlink) {
        let node = downlink.nodeUri
        let lane = downlink.laneUri
        var shouldSendUnlinkRequest = false

        objc_sync_enter(self)

        guard var nodeDownlinks = downlinks[node], laneDownlinks = nodeDownlinks[lane] else {
            objc_sync_exit(self)
            return
        }
        laneDownlinks.remove(downlink)
        if laneDownlinks.isEmpty {
            unregisterLane(node, lane)
            shouldSendUnlinkRequest = (socket?.readyState == .Open)
        }
        else {
            nodeDownlinks[lane] = laneDownlinks
            downlinks[node] = nodeDownlinks
        }

        objc_sync_exit(self)

        if shouldSendUnlinkRequest {
            let request = UnlinkRequest(node: unresolve(node), lane: lane)
            downlink.onUnlinkRequest()
            push(envelope: request)
        }

        downlink.onClose()
    }

    /// Must be called under objc_sync_enter(self).
    private func unregisterLane(node: SwimUri, _ lane: SwimUri) {
        guard var nodeDownlinks = downlinks[node] else {
            return
        }
        nodeDownlinks.removeValueForKey(lane)
        if nodeDownlinks.isEmpty {
            unregisterNode(node)
        }
        else {
            downlinks[node] = nodeDownlinks
        }

    }

    /// Must be called under objc_sync_enter(self).
    private func unregisterNode(node: SwimUri) {
        downlinks.removeValueForKey(node)
        watchIdle()
    }


    private func onAcks(acks: [AckResponse]) {
        log.verbose("Received acks: \(acks)")

        let resolvedMessages = resolveAndSortMessages(acks)
        routeMessages(resolvedMessages) { downlink, laneMessages in
            downlink.onAcks(laneMessages)
        }
    }

    private func onAuthedResponse(response: AuthedResponse) {
        inFlightAuthRequests.ack(1)
    }

    private func onDeauthedResponse(response: DeauthedResponse) {
        let tag = response.body.tag
        let err: SwimError = (
            tag == "notAuthorized" ? .NotAuthorized :
            tag == "invalid" ? .MalformedRequest :
                               .Unknown
        )
        inFlightAuthRequests.failFirst(err as NSError)
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
        resolveNodeAndSendToDownlinks(response) {
            $0.onLinkedResponse(response)
        }
    }

    private func onSyncRequest(request: SyncRequest) {
        // TODO: Support client services.
    }

    private func onSyncedResponse(response: SyncedResponse) {
        resolveNodeAndSendToDownlinks(response) {
            $0.onSyncedResponse(response)
        }
    }

    private func onUnlinkRequest(request: UnlinkRequest) {
        // TODO: Support client services.
    }

    private func onUnlinkedResponse(response: UnlinkedResponse) {
        objc_sync_enter(self)

        let node = resolve(response.node)
        response.node = node
        let lane = response.lane
        guard var nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] else {
            objc_sync_exit(self)
            return
        }
        nodeDownlinks.removeValueForKey(lane)
        if nodeDownlinks.isEmpty {
            downlinks.removeValueForKey(node)
        }

        objc_sync_exit(self)

        dispatch_async(dispatch_get_main_queue()) {
            for downlink in laneDownlinks {
                downlink.onUnlinkedResponse(response)
                downlink.onClose()
            }
        }
    }


    private func onConnect() {
        forAllDownlinks {
            $0.onConnect()
        }
    }


    private func onDisconnect() {
        forAllDownlinks {
            $0.onDisconnect()
        }
    }


    private func onError(error_: NSError) {
        log.info("\(error_)")

        var error = error_
        if error.domain == "SwiftWebSocket.WebSocketError" {
            error = SwimError.NetworkError as NSError
        }

        // We have to discard the send buffer now, because we're about to
        // fail all the in-flight commands.
        objc_sync_enter(self)
        self.sendBuffer.removeAll()
        objc_sync_exit(self)

        forAllDownlinks {
            $0.onError(error)
        }
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.inFlightAuthRequests.failAll(error)
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
                forEachDownlink(node: node, lane: lane) {
                    f($0, laneMessages)
                }
            }
        }
    }


    private func open() {
        log.verbose("")

        objc_sync_enter(self)

        if let timer = reconnectTimer {
            timer.invalidate()
            reconnectTimer = nil
            reconnectTimeout = 0.0
        }
        if socket == nil {
            startNetworkMonitorIfNecessary()

            let s = WebSocket(hostUri.uri, subProtocols: protocols)
            s.eventQueue = socketQueue
            s.delegate = self
            socket = s
        }

        objc_sync_exit(self)
    }


    /// Must be called under objc_sync_enter(self)
    private func startNetworkMonitorIfNecessary() -> SwimNetworkConditionMonitor.ServerMonitor {
        if networkMonitor == nil {
            startNetworkMonitor(hostUri.authority!.host.description)
        }
        return networkMonitor!
    }

    /// Must be called under objc_sync_enter(self)
    private func startNetworkMonitor(host: String) {
        let globals = SwimGlobals.instance
        objc_sync_enter(globals)
        if globals.networkConditionMonitor == nil {
            globals.networkConditionMonitor = SwimNetworkConditionMonitor()
        }
        objc_sync_exit(globals)
        networkMonitor = globals.networkConditionMonitor.startMonitoring(host)
    }


    func close() {
        log.verbose("")

        objc_sync_enter(self)

        clearIdle()
        socket?.close()
        // Note that we don't set socket = nil here -- we need to retain
        // it until webSocketClose is called.

        let downlinks = self.downlinks
        let monitor = networkMonitor
        self.downlinks.removeAll()

        objc_sync_exit(self)

        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                for downlink in laneDownlinks {
                    downlink.onClose()
                }
            }
        }

        if let monitor = monitor {
            let ncm = SwimGlobals.instance.networkConditionMonitor
            ncm.stopMonitoring(monitor)
            networkMonitor = nil
        }
    }


    func closeDownlinks(node node: SwimUri) {
        let node = resolve(node)

        objc_sync_enter(self)

        guard let nodeDownlinks = downlinks[node] else {
            objc_sync_exit(self)
            return
        }
        downlinks.removeValueForKey(node)

        objc_sync_exit(self)

        for laneDownlinks in nodeDownlinks.values {
            laneDownlinks.forEach {
                $0.onClose()
            }
        }
    }


    func closeDownlinks(node node: SwimUri, lane: SwimUri) {
        let node = resolve(node)

        objc_sync_enter(self)

        guard var nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] else {
            objc_sync_exit(self)
            return
        }
        nodeDownlinks.removeValueForKey(lane)
        downlinks[node] = nodeDownlinks

        objc_sync_exit(self)

        laneDownlinks.forEach {
            $0.onClose()
        }
    }


    private func reconnect() {
        objc_sync_enter(self)

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

        objc_sync_exit(self)
    }

    @objc private func doReconnect(timer: NSTimer) {
        self.open()
    }

    private func clearIdle() {
        objc_sync_enter(self)

        if let timer = idleTimer {
            timer.invalidate()
            idleTimer = nil
        }

        objc_sync_exit(self)
    }

    private func watchIdle() {
        objc_sync_enter(self)

        if socket?.readyState == .Open && sendBuffer.isEmpty && downlinks.isEmpty {
            idleTimer = NSTimer.scheduledTimerWithTimeInterval(idleTimeout, target: self, selector: #selector(Channel.checkIdle(_:)), userInfo: nil, repeats: false)
        }

        objc_sync_exit(self)
    }

    @objc private func checkIdle(timer: NSTimer) {
        objc_sync_enter(self)

        if sendBuffer.isEmpty && downlinks.isEmpty {
            log.verbose("Channel is idle.")
            close()
        }

        objc_sync_exit(self)
    }

    private func push(envelope envelope: Envelope) {
        objc_sync_enter(self)

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
        }
        else if envelope is SyncRequest {
            // This is usually only sent by the downlink when the socket
            // opens (in response to the onConnect callback) so the fact
            // that the socket isn't ready suggests that it opened and then
            // closed again immediately.  This happens if the server is
            // down.
            //
            // It's possible for app code to send this message any time they
            // want, but that's unlikely because we're handling it all
            // internally.
            //
            // On the assumption that the server is down, drop this message.
        }
        else {
            log.error("Buffering this message is unimplemented; the message has been dropped! \(envelope)")
        }

        objc_sync_exit(self)
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

            case let response as AuthedResponse:
                flushAllBatches()
                onAuthedResponse(response)

            case let response as DeauthedResponse:
                flushAllBatches()
                onDeauthedResponse(response)

            default:
                log.warning("Unknown envelope \(envelope)")
            }
        }

        flushAllBatches()
    }


    // MARK: Helpers

    private func resolveNodeAndSendToDownlinks(envelope: RoutableEnvelope, _ f: (RemoteDownlink -> Void)) {
        let node = resolve(envelope.node)
        envelope.node = node
        forEachDownlink(node: node, lane: envelope.lane) {
            f($0)
        }
    }


    private func forEachDownlink(node node: SwimUri, lane: SwimUri, _ f: (RemoteDownlink -> Void)) {
        objc_sync_enter(self)

        guard let nodeDownlinks = downlinks[node], let laneDownlinks = nodeDownlinks[lane] else {
            return
        }

        objc_sync_exit(self)

        dispatchFor(laneDownlinks, f)
    }


    private func forAllDownlinks(f: (RemoteDownlink -> Void)) {
        var allDownlinks = [RemoteDownlink]()

        objc_sync_enter(self)

        for nodeDownlinks in downlinks.values {
            for laneDownlinks in nodeDownlinks.values {
                allDownlinks.appendContentsOf(laneDownlinks)
            }
        }

        objc_sync_exit(self)

        dispatchFor(allDownlinks, f)
    }


    // MARK: WebSocketDelegate

    @objc func webSocketOpen() {
        objc_sync_enter(self)
        let creds = credentials
        objc_sync_exit(self)

        if creds.isDefined {
            auth(credentials: creds)
        }

        onConnect()

        objc_sync_enter(self)
        let sendBuffer = self.sendBuffer
        self.sendBuffer.removeAll()
        objc_sync_exit(self)

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

        objc_sync_enter(self)

        socket?.close()
        // Note that we don't set socket = nil here -- we need to retain
        // it until webSocketClose is called.

        objc_sync_exit(self)
    }

    @objc func webSocketClose(code: Int, reason: String, wasClean: Bool) {
        objc_sync_enter(self)

        socket?.delegate = nil
        socket = nil
        onDisconnect()
        clearIdle()
        if !sendBuffer.isEmpty || !downlinks.isEmpty {
            reconnect()
        }

        objc_sync_exit(self)
    }
}


private func dispatchFor<T where T : SequenceType>(l: T, _ f: T.Generator.Element -> Void) {
    dispatch_async(dispatch_get_main_queue()) {
        for x in l {
            f(x)
        }
    }
}
