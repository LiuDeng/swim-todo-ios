//
//  NSFileManager+SwimMisc.swift
//  Swim
//
//  Created by Ewan Mellor on 4/8/16.
//
//

import Foundation

private let log = SwimLogging.log


extension NSFileManager {
    func fileSize(path: NSURL) -> UInt64 {
        do {
            let attrs = try attributesOfItemAtPath(path.path!)
            return (attrs as NSDictionary).fileSize()
        }
        catch let exn {
            log.warning("Failed to get attributes from \(path): \(exn)")
            return UInt64.max
        }
    }


    func allFileSizes(dir: NSURL) -> [NSURL: UInt64]? {
        guard let enumerator = enumeratorAtURL(dir, includingPropertiesForKeys: [NSURLIsDirectoryKey, NSURLFileSizeKey], options: [], errorHandler: { (_, err) in
            log.warning("Failed to enumerate \(dir): \(err)")
            return false
        }) else {
            return nil
        }

        var result = [NSURL: UInt64]()
        while let url = enumerator.nextObject() as? NSURL {
            var isDir: AnyObject?
            try! url.getResourceValue(&isDir, forKey: NSURLIsDirectoryKey)
            if (isDir as! NSNumber).boolValue {
                guard let subResult = allFileSizes(url) else {
                    log.warning("Failed to enumerate subdir \(url); muddling on.")
                    continue
                }

                var total: UInt64 = 0
                for (k, v) in subResult {
                    result[k] = v
                    if v != UInt64.max {
                        total += v
                    }
                }

                result[url] = total
            }
            else {
                var size: AnyObject?
                try! url.getResourceValue(&size, forKey: NSURLFileSizeKey)
                result[url] = (size as! NSNumber).unsignedLongLongValue
            }
        }

        return result
    }
}
