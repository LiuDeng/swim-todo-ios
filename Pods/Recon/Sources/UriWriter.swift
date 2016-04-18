extension String {
  mutating func writeUriScheme(scheme: String) throws {
    var first = true
    for c in scheme.unicodeScalars {
      if !first && !isSchemeChar(c) || first && !isAlpha(c) {
        throw Uri.SerializationError.InvalidScheme
      }
      first = false
    }
    self.appendContentsOf(scheme)
  }

  mutating func writeUriUserInfo(userInfo: String) {
    for c in userInfo.unicodeScalars {
      if isUserInfoChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriUser(user: String) {
    for c in user.unicodeScalars {
      if isUserChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriHost(address: String) {
    for c in address.unicodeScalars {
      if isHostChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriHostLiteral(address: String) {
    for c in address.unicodeScalars {
      if isHostChar(c) || c == ":" {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriPort(port: UInt16) {
    var digits = [UInt8](count: 5, repeatedValue: 0)
    var n = port
    var i = 4
    while n > 0 {
      digits[i] = UInt8(n % 10)
      n /= 10
      i -= 1
    }
    i += 1
    while i < 5 {
      self.append(UnicodeScalar(UnicodeScalar("0").value + UInt32(digits[i])))
      i += 1
    }
  }

  mutating func writeUriPathSegment(segment: String) {
    for c in segment.unicodeScalars {
      if isPathChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriQuery(query: String) {
    for c in query.unicodeScalars {
      if isQueryChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriParam(param: String) {
    for c in param.unicodeScalars {
      if isParamChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  mutating func writeUriFragment(fragment: String) {
    for c in fragment.unicodeScalars {
      if isFragmentChar(c) {
        self.append(c)
      } else {
        writeUriEscaped(c.value)
      }
    }
  }

  private mutating func writeUriEscaped(c: UInt32) {
    if c == 0x00 { // modified UTF-8
      writeUriPercentEncoded(0xC0)
      writeUriPercentEncoded(0x80)
    }
    else if c >= 0x00 && c <= 0x7F { // U+0000..U+007F
      writeUriPercentEncoded(c)
    }
    else if (c >= 0x80 && c <= 0x07FF) { // U+0080..U+07FF
      writeUriPercentEncoded(0xC0 | (c >> 6))
      writeUriPercentEncoded(0x80 | (c & 0x3F))
    }
    else if c >= 0x0800 && c <= 0xFFFF || // U+0800..U+D7FF
      c >= 0xE000 && c <= 0xFFFF {  // U+E000..U+FFFF
        writeUriPercentEncoded(0xE0 | (c >> 12))
        writeUriPercentEncoded(0x80 | (c >>  6 & 0x3F))
        writeUriPercentEncoded(0x80 | (c       & 0x3F))
    }
    else if (c >= 0x10000 && c <= 0x10FFFF) { // U+10000..U+10FFFF
      writeUriPercentEncoded(0xF0 | (c >> 18))
      writeUriPercentEncoded(0x80 | (c >> 12 & 0x3F))
      writeUriPercentEncoded(0x80 | (c >>  6 & 0x3F))
      writeUriPercentEncoded(0x80 | (c       & 0x3F))
    }
    else { // surrogate or invalid code point
      writeUriPercentEncoded(0xEF)
      writeUriPercentEncoded(0xBF)
      writeUriPercentEncoded(0xBD)
    }
  }

  private mutating func writeUriPercentEncoded(c: UInt32) {
    self.append("%" as UnicodeScalar)
    self.append(encodeHex(c >> 4 & 0xF))
    self.append(encodeHex(c      & 0xF))
  }

  private func encodeHex(x: UInt32) -> UnicodeScalar {
    if x < 10 {
      return UnicodeScalar(UnicodeScalar("0").value + x)
    } else {
      return UnicodeScalar(UnicodeScalar("A").value + (x - 10))
    }
  }
}
