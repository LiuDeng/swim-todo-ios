class RemoteSyncedDownlink: RemoteDownlink {
    override func onConnect() {
        super.onConnect()
        delegate?.downlinkWillSync(self)
        channel.pushSyncRequest(node: nodeUri, lane: laneUri, prio: laneProperties.prio)
    }
}
