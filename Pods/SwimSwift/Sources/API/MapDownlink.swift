/**
 A `MapDownlink` is a remotely synchronized key-value map.  It behaves just
 like an ordinary Swift `Dictionary`, but it's transparently synchronized with
 a `MapLane` of a remote Swim service in the background.
 */
public protocol MapDownlink: Downlink {
    var primaryKey: SwimValue -> SwimValue { get }

    var state: [SwimValue: SwimValue] { get }

    var isEmpty: Bool { get }

    var count: Int { get }

    subscript(key: SwimValue) -> SwimValue { get set }

    func updateValue(value: SwimValue, forKey key: SwimValue) -> SwimValue?

    func removeValueForKey(key: SwimValue) -> SwimValue?

    func removeAll()

    func forEach(f: (SwimValue, SwimValue) throws -> ()) rethrows
}
