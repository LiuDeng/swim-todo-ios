import Recon

public protocol Envelope {
  var node: Uri { get }

  var lane: Uri { get }

  var body: Value { get }

  var reconValue: Value { get }

  var recon: String { get }
}
