class RemoteLinkedDownlink: RemoteDownlink {
    override func onConnect() {
        super.onConnect()
        let request = LinkRequest(node: channel.unresolve(nodeUri), lane: laneUri, prio: prio)
        onLinkRequest(request)
        channel.push(envelope: request)
    }
}
