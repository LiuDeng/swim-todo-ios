struct UriCache {
    struct CacheEntry {
        let unresolved: SwimUri
        let resolved: SwimUri

        init(unresolved: SwimUri, resolved: SwimUri) {
            self.unresolved = unresolved
            self.resolved = resolved
        }
    }

    let baseUri: SwimUri

    let size: Int

    var resolveCache: [CacheEntry?]

    var unresolveCache: [CacheEntry?]

    init(baseUri: SwimUri, size: Int = 32) {
        self.baseUri = baseUri
        self.size = size
        self.resolveCache = [CacheEntry?](count: size, repeatedValue: nil)
        self.unresolveCache = [CacheEntry?](count: size, repeatedValue: nil)
    }

    mutating func resolve(unresolvedUri: SwimUri) -> SwimUri {
        let hashBucket = abs(unresolvedUri.hashValue % size)
        if let cacheEntry = resolveCache[hashBucket] where unresolvedUri == cacheEntry.unresolved {
            return cacheEntry.resolved
        } else {
            let resolvedUri = baseUri.resolve(unresolvedUri)
            resolveCache[hashBucket] = CacheEntry(unresolved: unresolvedUri, resolved: resolvedUri)
            return resolvedUri
        }
    }

    mutating func unresolve(resolvedUri: SwimUri) -> SwimUri {
        let hashBucket = abs(resolvedUri.hashValue % size)
        if let cacheEntry = unresolveCache[hashBucket] where resolvedUri == cacheEntry.resolved {
            return cacheEntry.unresolved
        } else {
            let unresolvedUri = baseUri.unresolve(resolvedUri)
            unresolveCache[hashBucket] = CacheEntry(unresolved: unresolvedUri, resolved: resolvedUri)
            return unresolvedUri
        }
    }
}
