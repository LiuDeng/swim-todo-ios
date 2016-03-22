/**
 A `ListDownlink` is a remotely synchronized sequence of values.  It behaves
 just like an ordinary Swift `Array`, but it's transparently synchronized with
 a `ListLane` of a remote Swim service in the background.
 */
public protocol ListDownlink: Downlink {
    var state: [SwimValue] { get }

    var isEmpty: Bool { get }

    var count: Int { get }

    subscript(index: Int) -> SwimValue { get set }

    var first: SwimValue? { get }

    var last: SwimValue? { get }

    func append(value: SwimValue)

    func insert(value: SwimValue, atIndex: Int)

    func moveFromIndex(from: Int, toIndex to: Int)

    func removeAtIndex(index: Int) -> SwimValue

    func removeAll()

    func popLast() -> SwimValue?

    func removeLast() -> SwimValue

    func forEach(f: SwimValue throws -> ()) rethrows
}
