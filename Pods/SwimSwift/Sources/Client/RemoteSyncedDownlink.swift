class RemoteSyncedDownlink: RemoteDownlink {
    override func onConnect() {
        super.onConnect()
        sendSyncRequest()
    }
}
