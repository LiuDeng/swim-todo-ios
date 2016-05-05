import Bolts

/**
 A `MapDownlink` is a remotely synchronized key-value map.  It behaves just
 like an ordinary Swift `Dictionary`, but it's transparently synchronized with
 a `MapLane` of a remote Swim service in the background.
 */
public protocol MapDownlink: Downlink {
    var objects: [SwimValue: SwimModelProtocolBase] { get }

    var isEmpty: Bool { get }

    var count: Int { get }

    subscript(key: SwimValue) -> SwimModelProtocolBase? { get }

    func setObject(object: SwimModelProtocolBase, forKey key: SwimValue) -> BFTask

    func updateObjectForKey(key: SwimValue) -> BFTask

    func removeObjectForKey(key: SwimValue) -> (SwimModelProtocolBase?, BFTask)

    func removeAll() -> BFTask
}


public protocol MapDownlinkDelegate: DownlinkDelegate {
    /**
     Will be called whenever commands are received that will change
     `MapDownlink.objects`, and before those commands are processed.

     In other words, this indicates the start of a batch of calls to
     `swimMapDownlink(:did{Set,Remove,Update}:forKey:)` or
     `swimMapDownlinkDidRemoveAll(:objects:)`.
     */
    func swimMapDownlinkWillChange(downlink: MapDownlink)

    /**
     Will be called after a batch of changes to `MapDownlink.objects` has
     been processed.

     In other words, this indicates the end of a batch of calls to
     `swimMapDownlink(:did{Set,Remove,Update}:forKey:)` or
     `swimMapDownlinkDidRemoveAll(:objects:)`.
     */
    func swimMapDownlinkDidChange(downlink: MapDownlink)

    func swimMapDownlink(downlink: MapDownlink, didSet object: SwimModelProtocolBase, forKey key: SwimValue)
    func swimMapDownlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue)
    func swimMapDownlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue)
    func swimMapDownlinkDidRemoveAll(downlink: MapDownlink, objects: [SwimValue: SwimModelProtocolBase])
}

public extension MapDownlinkDelegate {
    func swimMapDownlinkWillChange(downlink: MapDownlink) {}
    func swimMapDownlinkDidChange(downlink: MapDownlink) {}

    func swimMapDownlink(downlink: MapDownlink, didSet object: SwimModelProtocolBase, forKey key: SwimValue) {}
    func swimMapDownlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue) {}
    func swimMapDownlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue) {}
    func swimMapDownlinkDidRemoveAll(downlink: MapDownlink, objects: [SwimValue: SwimModelProtocolBase]) {}
}
