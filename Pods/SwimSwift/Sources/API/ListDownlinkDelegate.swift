public protocol ListDownlinkDelegate: DownlinkDelegate {
    func downlink(downlink: ListDownlink, didUpdate value: SwimValue, atIndex: Int)

    func downlink(downlink: ListDownlink, didInsert value: SwimValue, atIndex: Int)

    func downlink(downlink: ListDownlink, didMove value: SwimValue, fromIndex: Int, toIndex: Int)

    func downlink(downlink: ListDownlink, didRemove value: SwimValue, atIndex: Int)
}

public extension ListDownlinkDelegate {
    public func downlink(downlink: ListDownlink, didUpdate value: SwimValue, atIndex: Int) {}

    public func downlink(downlink: ListDownlink, didInsert value: SwimValue, atIndex: Int) {}

    public func downlink(downlink: ListDownlink, didMove value: SwimValue, fromIndex: Int, toIndex: Int) {}

    public func downlink(downlink: ListDownlink, didRemove value: SwimValue, atIndex: Int) {}
}
