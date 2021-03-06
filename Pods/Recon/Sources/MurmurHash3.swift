struct MurmurHash3 {
  private init() {}

  private static func rotl(v: UInt32, _ n: UInt32) -> UInt32 {
    return v << n | v >> (32 - n)
  }

  static func hash<T1: Hashable>(seed: Int, _ _1: T1) -> Int {
    return mash(mix(seed, _1.hashValue))
  }

  static func hash<T1: Hashable, T2: Hashable>(seed: Int, _ _1: T1, _ _2: T2) -> Int {
    return mash(mix(mix(seed, _1.hashValue), _2.hashValue))
  }

  static func hash<T1: Hashable, T2: Hashable, T3: Hashable>(seed: Int, _ _1: T1, _ _2: T2, _ _3: T3) -> Int {
    return mash(mix(mix(mix(seed, _1.hashValue), _2.hashValue), _3.hashValue))
  }

  static func hash<T1: Hashable, T2: Hashable, T3: Hashable, T4: Hashable>(seed: Int, _ _1: T1, _ _2: T2, _ _3: T3, _ _4: T4) -> Int {
    return mash(mix(mix(mix(mix(seed, _1.hashValue), _2.hashValue), _3.hashValue), _4.hashValue))
  }

  static func hash<T1: Hashable, T2: Hashable, T3: Hashable, T4: Hashable, T5: Hashable>(seed: Int, _ _1: T1, _ _2: T2, _ _3: T3, _ _4: T4, _ _5: T5) -> Int {
    return mash(mix(mix(mix(mix(mix(seed, _1.hashValue), _2.hashValue), _3.hashValue), _4.hashValue), _5.hashValue))
  }

  private static func mix(h_: UInt32, _ k_: UInt32) -> UInt32 {
    var h = h_
    var k = k_
    k = k &* 0xcc9e2d51
    k = rotl(k, 15)
    k = k &* 0x1b873593

    h ^= k

    h = rotl(h, 13)
    h = h &* 5 &+ 0xe6546b64

    return h
  }

  static func mix(h: Int, _ k: Int) -> Int {
    let result = mix(UInt32(truncatingBitPattern: h), UInt32(truncatingBitPattern: k))
    return Int(truncatingBitPattern: UInt64(result))
  }

  private static func mash(h_: UInt32) -> UInt32 {
    var h = h_
    h ^= h >> 16
    h = h &* 0x85ebca6b
    h ^= h >> 13
    h = h &* 0xc2b2ae35
    h ^= h >> 16

    return h
  }

  static func mash(h: Int) -> Int {
    let result = mash(UInt32(truncatingBitPattern: h))
    return Int(truncatingBitPattern: UInt64(result))
  }
}
