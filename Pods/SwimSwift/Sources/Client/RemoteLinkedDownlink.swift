class RemoteLinkedDownlink: RemoteDownlink {
    override func onConnect() {
        super.onConnect()
        delegate?.downlinkWillLink(self)
        channel.pushLinkRequest(node: nodeUri, lane: laneUri, prio: laneProperties.prio)
    }
}
