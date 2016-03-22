public func recon(string: String) -> Value? {
  return ReconDocumentParser().parse(string).value as? Value
}
