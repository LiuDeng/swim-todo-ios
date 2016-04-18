#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
import Foundation
#endif

public typealias ReconData = Data

public class Data: CustomStringConvertible, Comparable, Hashable {
  var buffer: ManagedBuffer<(Int, Int), UInt8>

  public init(capacity: Int) {
    buffer = ManagedBuffer<(Int, Int), UInt8>.create(capacity, initialValue: { _ in (0, capacity) })
  }

#if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
  init(data: NSData) {
    let capacity = data.length
    buffer = ManagedBuffer<(Int, Int), UInt8>.create(capacity, initialValue: { protoBuffer in
      protoBuffer.withUnsafeMutablePointerToElements { pointer in
        data.getBytes(pointer, length: capacity)
      }
      return (capacity, capacity)
    })
  }
#endif

  public convenience init?(base64 string: String) {
    let cs = string.unicodeScalars
    var size = (cs.count / 4) * 3
    switch cs.count % 3 {
    case 1, 2: size += 1
    case 3: size += 2
    default: break
    }
    self.init(capacity: size)
    let decoder = Base64Decoder(data: self)
    do {
      for c in cs {
        try decoder.append(c)
      }
    } catch {
      return nil
    }
  }

  public convenience init() {
    self.init(capacity: Data.initialCapacity)
  }

  private(set) public var size: Int {
    get {
      return buffer.value.0
    }
    set {
      buffer.value.0 = newValue
    }
  }

  public var capacity: Int {
    return buffer.value.1
  }

  public subscript(index: Int) -> UInt8 {
    get {
      precondition(0 <= index && index < size)
      return buffer.withUnsafeMutablePointerToElements { $0[index] }
    }
    set {
      precondition(0 <= index && index < size)
      buffer.withUnsafeMutablePointerToElements { $0[index] = newValue }
    }
  }

  func writeBase64(inout string: String) {
    func encodeDigit(digit: UInt8) -> UnicodeScalar {
      if digit >= 0 && digit < 26 {
        return UnicodeScalar(UInt8(UnicodeScalar("A").value) + digit)
      } else if digit >= 26 && digit < 52 {
        return UnicodeScalar(UInt8(UnicodeScalar("a").value) + (digit - 26))
      } else if digit >= 52 && digit < 62 {
        return UnicodeScalar(UInt8(UnicodeScalar("0").value) + (digit - 52))
      } else if digit == 62 {
        return UnicodeScalar("+")
      } else if digit == 63 {
        return UnicodeScalar("/")
      } else {
        preconditionFailure()
      }
    }
    let n = self.size
    var i = 0
    buffer.withUnsafeMutablePointerToElements { bytes in
      while (i + 2 < n) {
        let x = bytes[i]
        let y = bytes[i + 1]
        let z = bytes[i + 2]
        string.append(encodeDigit(x >> 2))
        string.append(encodeDigit((x << 4 | y >> 4) & 0x3F))
        string.append(encodeDigit((y << 2 | z >> 6) & 0x3F))
        string.append(encodeDigit(z & 0x3F))
        i += 3
      }
      if i + 1 < n {
        let x = bytes[i]
        let y = bytes[i + 1]
        string.append(encodeDigit(x >> 2))
        string.append(encodeDigit((x << 4 | y >> 4) & 0x3F))
        string.append(encodeDigit(y << 2 & 0x3F))
        string.append(UnicodeScalar("="))
      } else if i < n {
        let x = bytes[i]
        string.append(encodeDigit(x >> 2))
        string.append(encodeDigit(x << 4 & 0x3F))
        string.append(UnicodeScalar("="))
        string.append(UnicodeScalar("="))
      }
    }
  }

  public func writeRecon(inout string: String) {
    string.append(UnicodeScalar("%"))
    writeBase64(&string)
  }

  public var recon: String {
    var string = ""
    writeRecon(&string)
    return string
  }

  public var description: String {
    return recon
  }

  public var hashValue: Int {
    let n = size
    return buffer.withUnsafeMutablePointerToElements { bytes in
      var k = Int(bitPattern: 0xa1c905c7)
      var i = 0
      while i < n {
        k = MurmurHash3.mix(k, Int(bytes[i]))
        i += 1
      }
      return MurmurHash3.mash(k)
    }
  }

  public func withUnsafePointer<R>(body: (UnsafePointer<UInt8>) -> R) -> R {
    return buffer.withUnsafeMutablePointerToElements { body(UnsafePointer($0)) }
  }

  public func withUnsafeMutablePointer<R>(body: (UnsafeMutablePointer<UInt8>) -> R) -> R {
    dealias()
    return buffer.withUnsafeMutablePointerToElements { body($0) }
  }

  public func appendByte(byte: UInt8) {
    prepare(1)
    let i = size
    buffer.withUnsafeMutablePointerToElements { pointer in
      pointer[i] = byte
    }
    size = i + 1
  }

  public func appendBytes(bytes: UInt8...) {
    let n = bytes.count
    prepare(n)
    let i = size
    buffer.withUnsafeMutablePointerToElements { pointer in
      pointer.advancedBy(i).initializeFrom(bytes)
    }
    size = i + n
  }

  func prepare(count: Int) {
    let newSize = size + count
    if newSize >= capacity {
      resize(Data.expand(newSize))
    } else if !isUniquelyReferencedNonObjC(&buffer) {
      dealias()
    }
  }

  func resize(newCapacity: Int) {
    let size = self.size
    buffer = ManagedBuffer<(Int, Int), UInt8>.create(newCapacity, initialValue: { buffer in
      buffer.withUnsafeMutablePointerToElements { newBytes in
        self.buffer.withUnsafeMutablePointerToElements { oldBytes in
          newBytes.initializeFrom(oldBytes, count: size)
          return (size, newCapacity)
        }
      }
    })
  }

  func dealias() {
    resize(capacity)
  }

  private static let initialCapacity: Int = 32
  private static let minCapacity: Int = 32

  private static func expand(size: Int) -> Int {
    var n = max(size, minCapacity) - 1
    n |= n >> 1
    n |= n >> 2
    n |= n >> 4
    n |= n >> 8
    n |= n >> 16
    return n + 1
  }
}

public func == (lhs: Data, rhs: Data) -> Bool {
  let n = lhs.size
  if n == rhs.size {
    return lhs.buffer.withUnsafeMutablePointerToElements { xs in
      rhs.buffer.withUnsafeMutablePointerToElements { ys in
        var i = 0
        while i < n && xs[i] == ys[i] {
          i += 1
        }
        return i == n
      }
    }
  } else {
    return false
  }
}

public func < (lhs: Data, rhs: Data) -> Bool {
  let p = lhs.size
  let q = rhs.size
  let n = min(p, q)
  return lhs.buffer.withUnsafeMutablePointerToElements { xs in
    rhs.buffer.withUnsafeMutablePointerToElements { ys in
      var i = 0
      while i < n {
        if xs[i] < ys[i] {
          return true
        }
        i += 1
      }
      return p < q
    }
  }
}


class Base64Decoder {
  private var data: Data
  private var p: UnicodeScalar = "\0"
  private var q: UnicodeScalar = "\0"
  private var r: UnicodeScalar = "\0"
  private var s: UnicodeScalar = "\0"

  init(data: Data) {
    self.data = data
  }

  private func decodeDigit(c: UnicodeScalar) throws -> UInt8 {
    if c >= "A" && c <= "Z" {
      return UInt8(c.value - UnicodeScalar("A").value)
    } else if c >= "a" && c <= "z" {
      return UInt8(26 + c.value - UnicodeScalar("a").value)
    } else if c >= "0" && c <= "9" {
      return UInt8(52 + c.value - UnicodeScalar("0").value)
    } else if c == "+" || c == "-" {
      return 62
    } else if c == "/" || c == "_" {
      return 63
    } else {
      throw DataError.InvalidEncoding
    }
  }

  private func decodeQuantum() throws {
    let x = try decodeDigit(p)
    let y = try decodeDigit(q)
    if r != "=" {
      let z = try decodeDigit(r)
      if s != "=" {
        let w = try decodeDigit(s)
        data.appendBytes(x << 2 | y >> 4, y << 4 | z >> 2, z << 6 | w)
      } else {
        data.appendBytes(x << 2 | y >> 4, y << 4 | z >> 2)
      }
    } else {
      precondition(s == "=")
      data.appendByte(x << 2 | y >> 4)
    }
  }

  func append(c: UnicodeScalar) throws {
    if self.p == "\0" {
      self.p = c
    } else if self.q == "\0" {
      self.q = c
    } else if self.r == "\0" {
      self.r = c
    } else {
      self.s = c
      try decodeQuantum()
      s = "\0"
      r = "\0"
      q = "\0"
      p = "\0"
    }
  }
}


enum DataError: ErrorType {
  case InvalidEncoding
}
