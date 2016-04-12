public protocol Envelope {
  var recon: String { get }
}


protocol RoutableEnvelope: Envelope {
    var node: SwimUri! { get set }
    var lane: SwimUri! { get }
}
