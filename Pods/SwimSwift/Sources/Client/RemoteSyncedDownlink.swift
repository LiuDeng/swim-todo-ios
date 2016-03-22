class RemoteSyncedDownlink: RemoteDownlink {
    override func onConnect() {
        super.onConnect()
        let request = SyncRequest(node: channel.unresolve(nodeUri), lane: laneUri, prio: prio)
        onSyncRequest(request)
        channel.push(envelope: request)
    }
}
