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

    func insert(object: SwimModelProtocolBase, atIndex index: Int) -> BFTask

    func moveFromIndex(from: Int, toIndex to: Int) -> BFTask

    func removeAtIndex(index: Int) -> (SwimModelProtocolBase?, BFTask)

    func removeAll() -> BFTask

    func replace(object: SwimModelProtocolBase, atIndex index: Int) -> BFTask

    func updateObjectAtIndex(index: Int) -> BFTask

    func setHighlightAtIndex(index: Int, isHighlighted: Bool) -> BFTask
}


public protocol ListDownlinkDelegate: DownlinkDelegate {
    /**
     Will be called whenever commands are received that will change
     `ListDownlink.objects`, and before those commands are processed.

     In other words, this indicates the start of a batch of calls to
     `swimListDownlink(:did{Insert,Move,Remove,Update}:atIndex:)` or
     `swimListDownlinkDidRemoveAll(:objects:)`.
     */
    func swimListDownlinkWillChangeObjects(downlink: ListDownlink)

    /**
     Will be called after a batch of changes to `ListDownlink.objects` has
     been processed.

     In other words, this indicates the end of a batch of calls to
     `swimListDownlink(:did{Insert,Move,Remove,Update}:atIndex:)` or
     `swimListDownlinkDidRemoveAll(:objects:)`.
     */
    func swimListDownlinkDidChangeObjects(downlink: ListDownlink)

    func swimListDownlink(downlink: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int)

    func swimListDownlink(downlink: ListDownlink, didInsert objects: [SwimModelProtocolBase], atIndexes indexes: [Int])

    func swimListDownlink(downlink: ListDownlink, didMove object: SwimModelProtocolBase, fromIndex: Int, toIndex: Int)

    func swimListDownlink(downlink: ListDownlink, didRemove object: SwimModelProtocolBase, atIndex index: Int)

    func swimListDownlinkDidRemoveAll(downlink: ListDownlink, objects: [SwimModelProtocolBase])
}

public extension ListDownlinkDelegate {
    func swimListDownlinkWillChangeObjects(downlink: ListDownlink) {}
    func swimListDownlinkDidChangeObjects(downlink: ListDownlink) {}

    func swimListDownlink(downlink: ListDownlink, didUpdate object: SwimModelProtocolBase, atIndex index: Int) {}
    func swimListDownlink(downlink: ListDownlink, didInsert objects: [SwimModelProtocolBase], atIndexes indexes: [Int]) {}
    func swimListDownlink(downlink: ListDownlink, didMove object: SwimModelProtocolBase, fromIndex: Int, toIndex: Int) {}
    func swimListDownlink(downlink: ListDownlink, didRemove object: SwimModelProtocolBase, atIndex index: Int) {}
    func swimListDownlinkDidRemoveAll(downlink: ListDownlink, objects: [SwimModelProtocolBase]) {}
}
