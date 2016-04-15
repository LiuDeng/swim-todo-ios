public protocol Envelope: class {
  var recon: String { get }
}


protocol RoutableEnvelope: Envelope {
    var node: SwimUri { get set }
    var lane: SwimUri { get }
}
