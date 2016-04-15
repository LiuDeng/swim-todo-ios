import Bolts

/**
 A `ListDownlink` is a remotely synchronized sequence of values.  It behaves
 just like an ordinary Swift `Array`, but it's transparently synchronized with
 a `ListLane` of a remote Swim service in the background.
 */
public protocol ListDownlink: Downlink {
    var objects: [SwimModelProtocolBase] { get }

    var isEmpty: Bool { get }

    var count: Int { get }

    subscript(index: Int) -> SwimModelProtocolBase { get }

    func insert(object: SwimModelProtocolBase, atIndex: Int) -> BFTask

    func moveFromIndex(from: Int, toIndex to: Int) -> BFTask

    func removeAtIndex(index: Int) -> (SwimModelProtocolBase, BFTask)

    func removeAll() -> BFTask

    func replace(object: SwimModelProtocolBase, atIndex: Int) -> BFTask

    func updateObjectAtIndex(index: Int) -> BFTask
}


public protocol ListDownlinkDelegate: DownlinkDelegate {
    func downlinkWillChangeObjects(downlink: ListDownlink)
    func downlinkDidChangeObjects(downlink: ListDownlink)

    func downlink(downlink: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int)

    func downlink(downlink: ListDownlink, didInsert object: SwimModelProtocolBase, atIndex index: Int)

    func downlink(downlink: ListDownlink, didMove object: SwimModelProtocolBase, fromIndex: Int, toIndex: Int)

    func downlink(downlink: ListDownlink, didRemove object: SwimModelProtocolBase, atIndex index: Int)
}

public extension ListDownlinkDelegate {
    func downlinkWillChangeObjects(downlink: ListDownlink) {}
    func downlinkDidChangeObjects(downlink: ListDownlink) {}

    func downlink(downlink: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int) {}
    func downlink(downlink: ListDownlink, didInsert object: SwimModelProtocolBase, atIndex index: Int) {}
    func downlink(downlink: ListDownlink, didMove object: SwimModelProtocolBase, fromIndex: Int, toIndex: Int) {}
    func downlink(downlink: ListDownlink, didRemove object: SwimModelProtocolBase, atIndex index: Int) {}
}
