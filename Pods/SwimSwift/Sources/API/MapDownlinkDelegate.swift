public protocol MapDownlinkDelegate: DownlinkDelegate {
    func downlink(downlink: MapDownlink, didUpdate value: SwimValue, forKey key: SwimValue)

    func downlink(downlink: MapDownlink, didRemove value: SwimValue, forKey key: SwimValue)
}

public extension MapDownlinkDelegate {
    public func downlink(downlink: MapDownlink, didUpdate value: SwimValue, forKey key: SwimValue) {}

    public func downlink(downlink: MapDownlink, didRemove value: SwimValue, forKey key: SwimValue) {}
}
