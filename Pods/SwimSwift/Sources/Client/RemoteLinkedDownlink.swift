class RemoteLinkedDownlink: RemoteDownlink {
    override func onConnect() {
        super.onConnect()
        forEachDelegate {
            $0.swimDownlinkWillLink($1)
        }
        channel.pushLinkRequest(node: nodeUri, lane: laneUri, prio: laneProperties.prio)
    }
}
