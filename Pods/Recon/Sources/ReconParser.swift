struct ReconDocumentParser: Iteratee {
  let value: Iteratee

  init(_ value: Iteratee) {
    self.value = value
  }

  init() {
    self.init(ReconBlockParser())
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconDocumentParser(next), remaining)
    case IterateeOutput.Done(_, let remaining) where !input.isEmpty:
      return expected("end of input", remaining)
    default:
      return output
    }
  }
}


struct ReconBlockParser: Iteratee {
  let builder: ValueBuilder

  init(_ builder: ValueBuilder) {
    self.builder = builder
  }

  init() {
    self.init(ValueBuilder())
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isWhitespace(c) {
      input = input.tail
    }
    if let c = input.head {
      if c == "@" || c == "{" || c == "[" || isNameStartChar(c) || c == "\"" || c == "-" || c >= "0" && c <= "9" || c == "%" {
        return cont(ReconBlockKeyParser(builder), input)
      } else {
        return expected("block value", input)
      }
    } else if input.isDone {
      return done(builder.state, input)
    }
    return cont(ReconBlockParser(builder), input)
  }
}

struct ReconBlockKeyParser: Iteratee {
  let key: Iteratee
  let builder: ValueBuilder

  init(_ key: Iteratee, _ builder: ValueBuilder) {
    self.key = key
    self.builder = builder
  }

  init(_ builder: ValueBuilder) {
    self.init(ReconBlockItemParser(), builder)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.key, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconBlockKeyParser(next, builder), remaining)
    case IterateeOutput.Done(let key as Value, let remaining):
      if remaining.isDone {
        var builder = self.builder
        builder.appendValue(key)
        return done(builder.state, remaining)
      } else {
        return cont(ReconBlockKeyThenParser(key, builder), remaining)
      }
    default:
      return output
    }
  }
}

struct ReconBlockKeyThenParser: Iteratee {
  let key: Value
  let builder: ValueBuilder

  init(_ key: Value, _ builder: ValueBuilder) {
    self.key = key
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if let c = input.head where c == ":" {
      return cont(ReconBlockKeyThenValueParser(key, builder), input.tail)
    } else if !input.isEmpty {
      var builder = self.builder
      builder.appendValue(key)
      return cont(ReconBlockSeparatorParser(builder), input)
    } else if input.isDone {
      var builder = self.builder
      builder.appendValue(key)
      return done(builder.state, input)
    }
    return cont(ReconBlockKeyThenParser(key, builder), input)
  }
}

struct ReconBlockKeyThenValueParser: Iteratee {
  let key: Value
  let builder: ValueBuilder

  init(_ key: Value, _ builder: ValueBuilder) {
    self.key = key
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if !input.isEmpty {
      return cont(ReconBlockKeyValueParser(key, builder), input)
    } else if input.isDone {
      var builder = self.builder
      builder.appendSlot(key)
      return done(builder.state, input)
    }
    return cont(ReconBlockKeyThenValueParser(key, builder), input)
  }
}

struct ReconBlockKeyValueParser: Iteratee {
  let key: Value
  let value: Iteratee
  let builder: ValueBuilder

  init(_ key: Value, _ value: Iteratee, _ builder: ValueBuilder) {
    self.key = key
    self.value = value
    self.builder = builder
  }

  init(_ key: Value, _ builder: ValueBuilder) {
    self.init(key, ReconBlockItemParser(), builder)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconBlockKeyValueParser(key, next, builder), remaining)
    case IterateeOutput.Done(let value as Value, let remaining):
      var builder = self.builder
      builder.appendSlot(key, value)
      return cont(ReconBlockSeparatorParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconBlockSeparatorParser: Iteratee {
  let builder: ValueBuilder

  init(_ builder: ValueBuilder) {
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if let c = input.head where c == "," || c == ";" || isNewline(c) {
      return cont(ReconBlockParser(builder), input.tail)
    } else if !input.isEmpty || input.isDone {
      return done(builder.state, input)
    }
    return cont(self, input)
  }
}


struct ReconAttrParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == "@" {
      return cont(ReconAttrIdentParser(), input.tail)
    } else if !input.isEmpty {
      return expected("attribute", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconAttrIdentParser: Iteratee {
  let ident: Iteratee

  init(_ ident: Iteratee) {
    self.ident = ident
  }

  init() {
    self.init(ReconIdentParser())
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(ident, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconAttrIdentParser(next), remaining)
    case IterateeOutput.Done(let key as String, let remaining):
      if !remaining.isDone {
        return cont(ReconAttrIdentRestParser(key), remaining)
      } else {
        return done(Field.Attr(key, Value.Extant), remaining)
      }
    default:
      return output
    }
  }
}

struct ReconAttrIdentRestParser: Iteratee {
  let key: String

  init(_ key: String) {
    self.key = key
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == "(" {
      return cont(ReconAttrParamBlockParser(key), input.tail)
    } else if !input.isEmpty || input.isDone {
      return done(Field.Attr(key, Value.Extant), input)
    }
    return cont(self, input)
  }
}

struct ReconAttrParamBlockParser: Iteratee {
  let key: String

  init(_ key: String) {
    self.key = key
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isWhitespace(c) {
      input = input.tail
    }
    if let c = input.head where c == ")" {
      return done(Field.Attr(key, Value.Extant), input.tail)
    } else if !input.isEmpty {
      return cont(ReconAttrParamParser(key), input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(ReconAttrParamBlockParser(key), input)
  }
}

struct ReconAttrParamParser: Iteratee {
  let key: String
  let value: Iteratee

  init(_ key: String, _ value: Iteratee) {
    self.key = key
    self.value = value
  }

  init(_ key: String) {
    self.init(key, ReconBlockParser())
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconAttrParamParser(key, next), remaining)
    case IterateeOutput.Done(let value as Value, let remaining):
      return cont(ReconAttrParamRestParser(key, value), remaining)
    default:
      return output
    }
  }
}

struct ReconAttrParamRestParser: Iteratee {
  let key: String
  let value: Value

  init(_ key: String, _ value: Value) {
    self.key = key
    self.value = value
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isWhitespace(c) {
      input = input.tail
    }
    if let c = input.head where c == ")" {
      return done(Field.Attr(key, value), input.tail)
    } else if !input.isEmpty {
      return expected(")", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(ReconAttrParamRestParser(key, value), input)
  }
}


struct ReconBlockItemParser: Iteratee {
  let builder: ReconBuilder?

  init(_ builder: ReconBuilder?) {
    self.builder = builder
  }

  init() {
    self.init(nil)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      switch c {
      case "@":
        return cont(ReconBlockItemFieldParser(ReconAttrParser(), builder), input)
      case "{":
        let builder = self.builder ?? RecordBuilder()
        let value = ReconRecordParser(builder)
        return cont(ReconBlockItemInnerParser(value, builder), input)
      case "[":
        let builder = self.builder ?? RecordBuilder()
        let value = ReconMarkupParser(builder)
        return cont(ReconBlockItemInnerParser(value, builder), input)
      case _ where isNameStartChar(c):
        return cont(ReconBlockItemValueParser(ReconIdentParser(), builder), input)
      case "\"":
        return cont(ReconBlockItemValueParser(ReconStringParser(), builder), input)
      case _ where c == "-" || c >= "0" && c <= "9":
        return cont(ReconBlockItemValueParser(ReconNumberParser(), builder), input)
      case "%":
        return cont(ReconBlockItemValueParser(ReconDataParser(), builder), input)
      default:
        if let builder = self.builder {
          return done(builder.state, input)
        } else {
          return done(Value.Extant, input)
        }
      }
    } else if input.isDone {
      if let builder = self.builder {
        return done(builder.state, input)
      } else {
        return done(Value.Extant, input)
      }
    }
    return cont(ReconBlockItemParser(builder), input)
  }
}

struct ReconBlockItemFieldParser: Iteratee {
  let field: Iteratee
  let builder: ReconBuilder?

  init(_ field: Iteratee, _ builder: ReconBuilder?) {
    self.field = field
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.field, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconBlockItemFieldParser(next, builder), remaining)
    case IterateeOutput.Done(let field as Field, let remaining):
      var builder = self.builder ?? ValueBuilder()
      builder.appendField(field)
      return cont(ReconBlockItemFieldRestParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconBlockItemFieldRestParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if !input.isEmpty {
      return cont(ReconBlockItemParser(builder), input)
    } else if input.isDone {
      return done(builder.state, input)
    }
    return cont(ReconBlockItemFieldRestParser(builder), input)
  }
}

struct ReconBlockItemValueParser: Iteratee {
  let value: Iteratee
  let builder: ReconBuilder?

  init(_ value: Iteratee, _ builder: ReconBuilder?) {
    self.value = value
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconBlockItemValueParser(next, builder), remaining)
    case IterateeOutput.Done(let value, let remaining):
      var builder = self.builder ?? ValueBuilder()
      builder.appendAny(value)
      if remaining.isDone {
        return done(builder.state, remaining)
      } else {
        return cont(ReconBlockItemRestParser(builder), remaining)
      }
    default:
      return output
    }
  }
}

struct ReconBlockItemInnerParser: Iteratee {
  let value: Iteratee
  let builder: ReconBuilder

  init(_ value: Iteratee, _ builder: ReconBuilder) {
    self.value = value
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconBlockItemInnerParser(next, builder), remaining)
    case IterateeOutput.Done(_, let remaining):
      return cont(ReconBlockItemRestParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconBlockItemRestParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if let c = input.head where c == "@" {
      return cont(ReconBlockItemParser(builder), input)
    } else if !input.isEmpty || input.isDone {
      return done(builder.state, input)
    }
    return cont(ReconBlockItemRestParser(builder), input)
  }
}


struct ReconInlineItemParser: Iteratee {
  let builder: ReconBuilder?

  init(_ builder: ReconBuilder?) {
    self.builder = builder
  }

  init() {
    self.init(nil)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      switch c {
      case "@":
        return cont(ReconInlineItemFieldParser(ReconAttrParser(), builder), input)
      case "{":
        if let builder = self.builder {
          return cont(ReconInlineItemInnerParser(ReconRecordParser(builder), builder), input)
        } else {
          return cont(ReconInlineItemValueParser(ReconRecordParser()), input)
        }
      case "[":
        if let builder = self.builder {
          return cont(ReconInlineItemInnerParser(ReconMarkupParser(builder), builder), input)
        } else {
          return cont(ReconInlineItemValueParser(ReconMarkupParser()), input)
        }
      default:
        if let builder = self.builder {
          return done(builder.state, input)
        } else {
          return done(Value.Extant, input)
        }
      }
    } else if input.isDone {
      if let builder = self.builder {
        return done(builder.state, input)
      } else {
        return done(Value.Extant, input)
      }
    }
    return cont(ReconInlineItemParser(builder), input)
  }
}

struct ReconInlineItemFieldParser: Iteratee {
  let field: Iteratee
  let builder: ReconBuilder?

  init(_ field: Iteratee, _ builder: ReconBuilder?) {
    self.field = field
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.field, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconInlineItemFieldParser(next, builder), remaining)
    case IterateeOutput.Done(let field as Field, let remaining):
      var builder = self.builder ?? ValueBuilder()
      builder.appendField(field)
      return cont(ReconInlineItemFieldRestParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconInlineItemFieldRestParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      switch c {
      case "{":
        return cont(ReconInlineItemInnerParser(ReconRecordParser(builder), builder), input)
      case "[":
        return cont(ReconInlineItemInnerParser(ReconMarkupParser(builder), builder), input)
      default:
        return done(builder.state, input)
      }
    } else if input.isDone {
      return done(builder.state, input)
    }
    return cont(self, input)
  }
}

struct ReconInlineItemValueParser: Iteratee {
  let value: Iteratee
  let builder: ReconBuilder?

  init(_ value: Iteratee, _ builder: ReconBuilder?) {
    self.value = value
    self.builder = builder
  }

  init(_ value: Iteratee) {
    self.init(value, nil)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconInlineItemValueParser(next, builder), remaining)
    case IterateeOutput.Done(let value as Value, let remaining):
      var builder = self.builder ?? ValueBuilder()
      builder.appendValue(value)
      return done(builder.state, remaining)
    default:
      return output
    }
  }
}

struct ReconInlineItemInnerParser: Iteratee {
  let value: Iteratee
  let builder: ReconBuilder

  init(_ value: Iteratee, _ builder: ReconBuilder) {
    self.value = value
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconInlineItemInnerParser(next, builder), remaining)
    case IterateeOutput.Done(_, let remaining):
      return done(builder.state, remaining)
    default:
      return output
    }
  }
}


struct ReconRecordParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  init() {
    self.init(RecordBuilder())
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == "{" {
      return cont(ReconRecordRestParser(builder), input.tail)
    } else if !input.isEmpty {
      return expected("{", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconRecordRestParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isWhitespace(c) {
      input = input.tail
    }
    if let c = input.head where c == "}" {
      return done(builder.state, input.tail)
    } else if !input.isEmpty {
      return cont(ReconRecordKeyParser(builder), input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconRecordKeyParser: Iteratee {
  let key: Iteratee
  let builder: ReconBuilder

  init(_ key: Iteratee, _ builder: ReconBuilder) {
    self.key = key
    self.builder = builder
  }

  init(_ builder: ReconBuilder) {
    self.init(ReconBlockItemParser(), builder)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.key, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconRecordKeyParser(next, builder), remaining)
    case IterateeOutput.Done(let key as Value, let remaining):
      return cont(ReconRecordKeyThenParser(key, builder), remaining)
    default:
      return output
    }
  }
}

struct ReconRecordKeyThenParser: Iteratee {
  let key: Value
  let builder: ReconBuilder

  init(_ key: Value, _ builder: ReconBuilder) {
    self.key = key
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if let c = input.head where c == ":" {
      return cont(ReconRecordKeyThenValueParser(key, builder), input.tail)
    } else if !input.isEmpty {
      var builder = self.builder
      builder.appendValue(key)
      return cont(ReconRecordSeparatorParser(builder), input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(ReconRecordKeyThenParser(key, builder), input)
  }
}

struct ReconRecordKeyThenValueParser: Iteratee {
  let key: Value
  let builder: ReconBuilder

  init(_ key: Value, _ builder: ReconBuilder) {
    self.key = key
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if !input.isEmpty {
      return cont(ReconRecordKeyValueParser(key, builder), input)
    } else if input.isDone {
      var builder = self.builder
      builder.appendSlot(key)
      return done(builder.state, input)
    }
    return cont(ReconRecordKeyThenValueParser(key, builder), input)
  }
}

struct ReconRecordKeyValueParser: Iteratee {
  let key: Value
  let value: Iteratee
  let builder: ReconBuilder

  init(_ key: Value, _ value: Iteratee, _ builder: ReconBuilder) {
    self.key = key
    self.value = value
    self.builder = builder
  }

  init(_ key: Value, _ builder: ReconBuilder) {
    self.init(key, ReconBlockItemParser(), builder)
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconRecordKeyValueParser(key, next, builder), remaining)
    case IterateeOutput.Done(let value as Value, let remaining):
      var builder = self.builder
      builder.appendSlot(key, value)
      return cont(ReconRecordSeparatorParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconRecordSeparatorParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    while let c = input.head where isSpace(c) {
      input = input.tail
    }
    if let c = input.head {
      switch c {
      case ",", ";", _ where isNewline(c):
        return cont(ReconRecordRestParser(builder), input.tail)
      case "}":
        return done(builder.state, input.tail)
      default:
        return expected("'}', ';', ',', or newline", input)
      }
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}


struct ReconMarkupParser: Iteratee {
  let builder: ReconBuilder

  init(_ builder: ReconBuilder) {
    self.builder = builder
  }

  init() {
    self.init(RecordBuilder())
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == "[" {
      return cont(ReconMarkupRestParser(builder), input.tail)
    } else if !input.isEmpty {
      return expected("[", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconMarkupRestParser: Iteratee {
  let text: String
  let builder: ReconBuilder

  init(_ text: String, _ builder: ReconBuilder) {
    self.text = text
    self.builder = builder
  }

  init(_ builder: ReconBuilder) {
    self.init("", builder)
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var text = self.text
    while let c = input.head where c != "@" && c != "[" && c != "\\" && c != "]" && c != "{" && c != "}" {
      text.append(c)
      input = input.tail
    }
    if let c = input.head {
      switch c {
      case "]":
        var builder = self.builder
        if !text.isEmpty {
          builder.appendText(text)
        }
        return done(builder.state, input.tail)
      case "@":
        var builder = self.builder
        if !text.isEmpty {
          builder.appendText(text)
        }
        return cont(ReconMarkupValueParser(ReconInlineItemParser(), builder), input)
      case "{":
        var builder = self.builder
        if !text.isEmpty {
          builder.appendText(text)
        }
        return cont(ReconMarkupInnerParser(ReconRecordParser(builder), builder), input)
      case "[":
        var builder = self.builder
        if !text.isEmpty {
          builder.appendText(text)
        }
        return cont(ReconMarkupInnerParser(ReconMarkupParser(builder), builder), input)
      case "\\":
        return cont(ReconMarkupEscapeParser(text, builder), input.tail)
      default:
        return unexpected(input)
      }
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(ReconMarkupRestParser(text, builder), input)
  }
}

struct ReconMarkupValueParser: Iteratee {
  let value: Iteratee
  let builder: ReconBuilder

  init(_ value: Iteratee, _ builder: ReconBuilder) {
    self.value = value
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconMarkupValueParser(next, builder), remaining)
    case IterateeOutput.Done(let value as Value, let remaining):
      var builder = self.builder
      builder.appendValue(value)
      return cont(ReconMarkupRestParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconMarkupInnerParser: Iteratee {
  let value: Iteratee
  let builder: ReconBuilder

  init(_ value: Iteratee, _ builder: ReconBuilder) {
    self.value = value
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var output = cont(self.value, input)
    while case IterateeOutput.Cont(let next, let remaining) = output where !remaining.isEmpty || remaining.isDone {
      output = next.feed(remaining)
    }
    switch output {
    case IterateeOutput.Cont(let next, let remaining):
      return cont(ReconMarkupInnerParser(next, builder), remaining)
    case IterateeOutput.Done(_, let remaining):
      return cont(ReconMarkupRestParser(builder), remaining)
    default:
      return output
    }
  }
}

struct ReconMarkupEscapeParser: Iteratee {
  let text: String
  let builder: ReconBuilder

  init(_ text: String, _ builder: ReconBuilder) {
    self.text = text
    self.builder = builder
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var text = self.text
    if let c = input.head {
      switch c {
      case "\"", "/", "@", "[", "\\", "]", "{", "}":
        text.append(c)
      case "b":
        text.append(UnicodeScalar("\u{8}"))
      case "f":
        text.append(UnicodeScalar("\u{C}"))
      case "n":
        text.append(UnicodeScalar("\n"))
      case "r":
        text.append(UnicodeScalar("\r"))
      case "t":
        text.append(UnicodeScalar("\t"))
      default:
        return expected("escape character", input)
      }
      return cont(ReconMarkupRestParser(text, builder), input.tail)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}


struct ReconIdentParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where isNameStartChar(c) {
      return cont(ReconIdentRestParser(String(c)), input.tail)
    } else if !input.isEmpty {
      return expected("identifier", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconIdentRestParser: Iteratee {
  let ident: String

  init(_ ident: String) {
    self.ident = ident;
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var ident = self.ident
    while let c = input.head where isNameChar(c) {
      ident.append(c)
      input = input.tail
    }
    if !input.isEmpty || input.isDone {
      return done(ident, input)
    }
    return cont(ReconIdentRestParser(ident), input)
  }
}


struct ReconStringParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == "\"" {
      return cont(ReconStringRestParser(), input.tail)
    } else if !input.isEmpty {
      return expected("string", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconStringRestParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  init() {
    self.init("")
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var string = self.string
    while let c = input.head where c != "\"" && c != "\\" {
      string.append(c)
      input = input.tail
    }
    if let c = input.head {
      if c == "\"" {
        return done(string, input.tail)
      } else if c == "\\" {
        return cont(ReconStringEscapeParser(string), input.tail)
      }
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(ReconStringRestParser(string), input)
  }
}

struct ReconStringEscapeParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head {
      switch c {
      case "\"", "/", "@", "[", "\\", "]", "{", "}":
        string.append(c)
      case "b":
        string.append(UnicodeScalar("\u{8}"))
      case "f":
        string.append(UnicodeScalar("\u{C}"))
      case "n":
        string.append(UnicodeScalar("\n"))
      case "r":
        string.append(UnicodeScalar("\r"))
      case "t":
        string.append(UnicodeScalar("\t"))
      default:
        return expected("escape character", input)
      }
      return cont(ReconStringRestParser(string), input.tail)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}


struct ReconNumberParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head {
      if c == "-" {
        return cont(ReconNumberIntegralParser("-"), input.tail)
      } else {
        return cont(ReconNumberIntegralParser(), input)
      }
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconNumberIntegralParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  init() {
    self.init("")
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head {
      if c == "0" {
        string.append(c)
        return cont(ReconNumberRestParser(string), input.tail)
      } else if c >= "1" && c <= "9" {
        string.append(c)
        return cont(ReconNumberIntegralRestParser(string), input.tail)
      } else {
        return expected("digit", input)
      }
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconNumberIntegralRestParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var string = self.string
    while let c = input.head where c >= "0" && c <= "9" {
      string.append(c)
      input = input.tail
    }
    if !input.isEmpty {
      return cont(ReconNumberRestParser(string), input)
    } else if input.isDone {
      return done(Int(string)!, input)
    }
    return cont(ReconNumberIntegralRestParser(string), input)
  }
}

struct ReconNumberRestParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head {
      if c == "." {
        string.append(c)
        return cont(ReconNumberFractionalParser(string), input.tail)
      }
      else if c == "E" || c == "e" {
        string.append(c)
        return cont(ReconNumberExponentialParser(string), input.tail)
      }
      else {
        return done(Int(string)!, input)
      }
    } else if input.isDone {
      return done(Int(string)!, input)
    }
    return cont(self, input)
  }
}

struct ReconNumberFractionalParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head where c >= "0" && c <= "9" {
      string.append(c)
      return cont(ReconNumberFractionalRestParser(string), input.tail)
    } else if !input.isEmpty {
      return expected("digit", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconNumberFractionalRestParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var string = self.string
    while let c = input.head where c >= "0" && c <= "9" {
      string.append(c)
      input = input.tail
    }
    if !input.isEmpty {
      return cont(ReconNumberFractionalExponentParser(string), input)
    } else if input.isDone {
      return done(Double(string)!, input)
    }
    return cont(ReconNumberFractionalRestParser(string), input)
  }
}

struct ReconNumberFractionalExponentParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head where c == "E" || c == "e" {
      string.append(c)
      return cont(ReconNumberExponentialParser(string), input.tail)
    } else if !input.isEmpty {
      return done(Double(string)!, input)
    } else if input.isDone {
      return done(Double(string)!, input)
    }
    return cont(self, input)
  }
}

struct ReconNumberExponentialParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head {
      if c == "+" || c == "-" {
        string.append(c)
        input = input.tail
      }
      return cont(ReconNumberExponentialPartParser(string), input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconNumberExponentialPartParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(input: IterateeInput) -> IterateeOutput {
    var string = self.string
    if let c = input.head where c >= "0" && c <= "9" {
      string.append(c)
      return cont(ReconNumberExponentialRestParser(string), input.tail)
    } else if !input.isEmpty {
      return expected("digit", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconNumberExponentialRestParser: Iteratee {
  let string: String

  init(_ string: String) {
    self.string = string
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var string = self.string
    while let c = input.head where c >= "0" && c <= "9" {
      string.append(c)
      input = input.tail
    }
    if !input.isEmpty || input.isDone {
      return done(Double(string)!, input)
    }
    return cont(ReconNumberExponentialRestParser(string), input)
  }
}


struct ReconDataParser: Iteratee {
  func feed(input: IterateeInput) -> IterateeOutput {
    if let c = input.head where c == "%" {
      return cont(ReconDataRestParser(), input.tail)
    } else if !input.isEmpty {
      return expected("data", input)
    } else if input.isDone {
      return unexpected(input)
    }
    return cont(self, input)
  }
}

struct ReconDataRestParser: Iteratee {
  let data: Base64Decoder
  let state: Int

  init(_ data: Base64Decoder, _ state: Int) {
    self.data = data
    self.state = state
  }

  init() {
    self.init(Base64Decoder(), 0)
  }

  func feed(var input: IterateeInput) -> IterateeOutput {
    var data = self.data
    var state = self.state
    while let c = input.head where isBase64Char(c) {
      try! data.append(c)
      input = input.tail
      state = (state + 1) % 4
    }
    if let c = input.head where state == 2 {
      if c == "=" {
        try! data.append(c)
        input = input.tail
        state = 4
      } else {
        return expected("base64 digit", input)
      }
    }
    if let c = input.head where state == 3 {
      if c == "=" {
        try! data.append(c)
        return done(data.state, input.tail)
      } else {
        return expected("base64 digit", input)
      }
    }
    if let c = input.head where state == 4 {
      if c == "=" {
        try! data.append(c)
        return done(data.state, input.tail)
      } else {
        return expected("=", input)
      }
    }
    if !input.isEmpty {
      if state == 0 {
        return done(data.state, input)
      } else {
        return expected("base64 digit", input)
      }
    } else if input.isDone {
      if state == 0 {
        return done(data.state, input)
      } else {
        return unexpected(input)
      }
    }
    return cont(ReconDataRestParser(data, state), input)
  }
}


func isSpace(c: UnicodeScalar) -> Bool {
  return c == "\u{20}" || c == "\u{9}"
}

func isNewline(c: UnicodeScalar) -> Bool {
  return c == "\u{A}" || c == "\u{D}"
}

func isWhitespace(c: UnicodeScalar) -> Bool {
  return isSpace(c) || isNewline(c)
}

func isNameStartChar(c: UnicodeScalar) -> Bool {
  return c >= "A" && c <= "Z" ||
    c == "_" ||
    c >= "a" && c <= "z" ||
    c >= "\u{C0}" && c <= "\u{D6}" ||
    c >= "\u{D8}" && c <= "\u{F6}" ||
    c >= "\u{F8}" && c <= "\u{2FF}" ||
    c >= "\u{370}" && c <= "\u{37D}" ||
    c >= "\u{37F}" && c <= "\u{1FFF}" ||
    c >= "\u{200C}" && c <= "\u{200D}" ||
    c >= "\u{2070}" && c <= "\u{218F}" ||
    c >= "\u{2C00}" && c <= "\u{2FEF}" ||
    c >= "\u{3001}" && c <= "\u{D7FF}" ||
    c >= "\u{F900}" && c <= "\u{FDCF}" ||
    c >= "\u{FDF0}" && c <= "\u{FFFD}" ||
    c >= "\u{10000}" && c <= "\u{EFFFF}"
}

func isNameChar(c: UnicodeScalar) -> Bool {
  return c == "-" ||
    c >= "0" && c <= "9" ||
    c >= "A" && c <= "Z" ||
    c == "_" ||
    c >= "a" && c <= "z" ||
    c == "\u{B7}" ||
    c >= "\u{C0}" && c <= "\u{D6}" ||
    c >= "\u{D8}" && c <= "\u{F6}" ||
    c >= "\u{F8}" && c <= "\u{37D}" ||
    c >= "\u{37F}" && c <= "\u{1FFF}" ||
    c >= "\u{200C}" && c <= "\u{200D}" ||
    c >= "\u{203F}" && c <= "\u{2040}" ||
    c >= "\u{2070}" && c <= "\u{218F}" ||
    c >= "\u{2C00}" && c <= "\u{2FEF}" ||
    c >= "\u{3001}" && c <= "\u{D7FF}" ||
    c >= "\u{F900}" && c <= "\u{FDCF}" ||
    c >= "\u{FDF0}" && c <= "\u{FFFD}" ||
    c >= "\u{10000}" && c <= "\u{EFFFF}"
}

func isBase64Char(c: UnicodeScalar) -> Bool {
  return c >= "0" && c <= "9" ||
    c >= "A" && c <= "Z" ||
    c >= "a" && c <= "z" ||
    c == "+" || c == "-" ||
    c == "/" || c == "_"
}
