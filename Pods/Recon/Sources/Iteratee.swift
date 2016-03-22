public protocol Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput

  func cont(parser: Iteratee, _ input: IterateeInput) -> IterateeOutput

  func done(value: Any, _ input: IterateeInput) -> IterateeOutput

  func fail(reason: String, _ input: IterateeInput) -> IterateeOutput

  func expected(expected: String, _ input: IterateeInput) -> IterateeOutput

  func unexpected(input: IterateeInput) -> IterateeOutput

  func run(input: IterateeInput) -> IterateeOutput

  func parse(string: String) -> IterateeOutput
}

extension Iteratee {
  func cont(parser: Iteratee, _ input: IterateeInput) -> IterateeOutput {
    return IterateeOutput.Cont(parser, input)
  }

  func done(value: Any, _ input: IterateeInput) -> IterateeOutput {
    return IterateeOutput.Done(value, input)
  }

  func fail(reason: String, _ input: IterateeInput) -> IterateeOutput {
    return IterateeOutput.Fail(reason, input)
  }

  func expected(expected: String, _ input: IterateeInput) -> IterateeOutput {
    if let found = input.head {
      return fail("expected \(expected), but found \(found)", input)
    } else {
      return fail("unexpected \(expected)", input)
    }
  }

  func unexpected(input: IterateeInput) -> IterateeOutput {
    if let found = input.head {
      return fail("Unexpected \(found)", input)
    } else {
      return fail("Unexpected end of input", input)
    }
  }

  func run(input: IterateeInput) -> IterateeOutput {
    var output = cont(self, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, _):
      return next.feed(IterateeInputDone())
    default:
      return output
    }
  }

  func parse(string: String) -> IterateeOutput {
    return run(IterateeInputString(string))
  }
}


public protocol IterateeInput {
  var isEmpty: Bool { get }

  var isDone: Bool { get }

  var head: UnicodeScalar? { get }

  var tail: IterateeInput { get }
}

public struct IterateeInputEmpty: IterateeInput {
  public var isEmpty: Bool {
    return true
  }

  public var isDone: Bool {
    return false
  }

  public var head: UnicodeScalar? {
    return nil
  }

  public var tail: IterateeInput {
    fatalError("tail of empty input")
  }
}

public struct IterateeInputDone: IterateeInput {
  public var isEmpty: Bool {
    return true
  }

  public var isDone: Bool {
    return true
  }

  public var head: UnicodeScalar? {
    return nil
  }

  public var tail: IterateeInput {
    fatalError("tail of done input")
  }
}

public struct IterateeInputString: IterateeInput {
  var scalars: String.UnicodeScalarView
  var index: String.UnicodeScalarView.Index

  public init(scalars: String.UnicodeScalarView, index: String.UnicodeScalarView.Index) {
    self.scalars = scalars
    self.index = index
  }

  public init(_ string: String) {
    let scalars = string.unicodeScalars
    let index = scalars.startIndex
    self.init(scalars: scalars, index: index)
  }

  public var isEmpty: Bool {
    return self.index >= self.scalars.endIndex
  }

  public var isDone: Bool {
    return false
  }

  public var head: UnicodeScalar? {
    if (self.index < self.scalars.endIndex) {
      return self.scalars[self.index]
    }
    else {
      return nil
    }
  }

  public var tail: IterateeInput {
    if (self.index < self.scalars.endIndex) {
      return IterateeInputString(scalars: self.scalars, index: self.index.successor())
    }
    else {
      return IterateeInputEmpty()
    }
  }
}


public enum IterateeOutput {
  case Cont(Iteratee, IterateeInput)

  case Done(Any, IterateeInput)

  case Fail(String, IterateeInput)

  public var isCont: Bool {
    if case Cont = self {
      return true
    } else {
      return false
    }
  }

  public var isDone: Bool {
    if case Done = self {
      return true
    } else {
      return false
    }
  }

  public var isFail: Bool {
    if case Fail = self {
      return true
    } else {
      return false
    }
  }

  public var value: Any? {
    if case Done(let value, _) = self {
      return value
    } else {
      return nil
    }
  }

  public var remaining: IterateeInput {
    switch self {
    case Cont(_, let remaining):
      return remaining
    case Done(_, let remaining):
      return remaining
    case Fail(_, let remaining):
      return remaining
    }
  }
}
