//
//  SwimOplogManager.swift
//  Swim
//
//  Created by Ewan Mellor on 4/4/16.
//
//

import Bolts
import SQLite


private let rootDirName = "SwimOplog"

private let log = SwimLogging.log

private let tableOplog = Table("oplog")
private let colId = Expression<Int64>("id")
private let colTimestamp = Expression<NSDate>("timestamp")
private let colCounter = Expression<Int64>("counter")
private let colSwimValue = Expression<String>("swimValue")


public class SwimOplogManager {
    public static let ErrorDomain = "SwimOplogManager.ErrorDomain"
    public static let SQLErrorDomain = "SwimOplogManager.SQLErrorDomain"


    public enum ErrorCode: Int {
        case UnknownError = 0
        case NotConnected
    }


    public class Stats {
        public var fileSize: UInt64 = UInt64.max
    }


    public var rootDir: NSURL = {
        let appSupportDir = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        return appSupportDir.URLByAppendingPathComponent(rootDirName)
    }()


    /**
     May only be accessed under objc_sync_enter(self)
     */
    private var connections = [SwimUri: Connection]()

    /**
     May only be accessed under objc_sync_enter(self)
     */
    private var stats = [NSURL: Stats]()

    /**
     Set this whenever your user signs in or out (set it to nil to sign
     out).

     Setting this will close all open DB connections.

     Note that this value will be used to name a directory on the
     filesystem.  This will be sanitized to remove troublesome characters,
     but since you need to guarantee uniqueness between users, you should
     ensure that it will be unique even after the sanitization.  Using
     an ASCII UUID is recommended.
     */
    private var userId: String? {
        didSet {
            objc_sync_enter(self)
            connections.removeAll()
            objc_sync_exit(self)
        }
    }


    public func openAsync(lane: SwimUri) -> BFTask {
        return withSelfLock {
            return self.openAsync_(lane)
        }
    }

    /// May only be called under objc_sync_enter(self)
    public func openAsync_(lane: SwimUri) -> BFTask {
        if connections[lane] != nil {
            return BFTask(result: nil)
        }

        let path = dbPath(lane)

        do {
            let dir = path.URLByDeletingLastPathComponent!.absoluteString
            let fm = NSFileManager.defaultManager()
            try fm.createDirectoryAtPath(dir, withIntermediateDirectories: true, attributes: nil)

            let db = try Connection(path.absoluteString)
            db.busyTimeout = 5
            db.busyHandler { $0 < 3 }

            connections[lane] = db

            return createTables(db).continueWithSuccessBlock { [weak self] _ in
                self?.loadStats(path)
            }.continueWithSuccessBlock { [weak self] _ in
                self?.loadTotalStats()
            }
        }
        catch Result.Error(message: let msg, code: let code, statement: _) {
            return BFTask(error: NSError(sqlErrorCode:  code, msg: msg))
        }
        catch let err {
            return BFTask(error: NSError(unknownErrorType: err))
        }
    }


    private func createTables(db: Connection) -> BFTask {
        return db.runTask(tableOplog.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: .Autoincrement)
            t.column(colTimestamp)
            t.column(colCounter)
            t.column(colSwimValue)
            })
    }


    private func loadStats(path: NSURL) -> BFTask {
        return backgroundTask { [weak self] in
            self?.loadStatsBackground(path)
        }
    }

    private func loadStatsBackground(path: NSURL) {
        let fm = NSFileManager.defaultManager()
        let fileSize = fm.fileSize(path.absoluteString)

        objc_sync_enter(self)
        setFileSize(path, fileSize)
        objc_sync_exit(self)
    }


    private func loadTotalStats() -> BFTask {
        return backgroundTask { [weak self] in
            self?.loadTotalStatsBackground()
        }
    }

    private func loadTotalStatsBackground() {
        let fm = NSFileManager.defaultManager()
        guard let sizes = fm.allFileSizes(rootDir) else {
            log.warning("Failed to load filesystem stats")
            return
        }

        objc_sync_enter(self)
        for (url, size) in sizes {
            let str = url.absoluteString
            if str.hasSuffix("/") || str.hasSuffix(".sqlite") {
                setFileSize(url, size)
            }
        }
        objc_sync_exit(self)
    }


    /// May only be called under objc_sync_enter(self)
    private func setFileSize(url: NSURL, _ size: UInt64) {
        var s = stats[url]
        if s == nil {
            s = Stats()
            stats[url] = s
        }
        s!.fileSize = size
    }


    public func addEntryAsync(lane: SwimUri, timestamp: NSDate, counter: Int64, swimValue: SwimValue) -> BFTask {
        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runTask(tableOplog.insert(
            colTimestamp <- timestamp,
            colCounter <- counter,
            colSwimValue <- swimValue.recon
            ))
    }


    public func statistics() -> [NSURL: Stats] {
        objc_sync_enter(self)
        let result = stats
        objc_sync_exit(self)
        return result
    }


    private func dbPath(lane: SwimUri) -> NSURL {
        let u = (userId ?? "ANONYMOUS")
        return (
            rootDir.URLByAppendingPathComponent(u.stringBySanitizingFilename)
                .URLByAppendingPathComponent(lane.dbFilename)
                .URLByAppendingPathExtension("sqlite")
        )
    }


    private func connectionForLane(lane: SwimUri) -> Connection? {
        return withSelfLock {
            return self.connections[lane]
        }
    }


    private func withSelfLock<T>(f: () -> T) -> T {
        objc_sync_enter(self)
        let result = f()
        objc_sync_exit(self)
        return result
    }
}


private extension NSError {
    private convenience init(errorCode: SwimOplogManager.ErrorCode, userInfo: [NSObject : AnyObject]? = nil)  {
        self.init(domain: SwimOplogManager.ErrorDomain, code: errorCode.rawValue, userInfo: userInfo)
    }

    private convenience init(unknownErrorType: ErrorType) {
        self.init(errorCode: .UnknownError, userInfo: ["error": String(unknownErrorType)])
    }

    private convenience init(sqlErrorCode: Int32, msg: String) {
        self.init(domain: SwimOplogManager.SQLErrorDomain, code: Int(sqlErrorCode), userInfo: ["message": msg])
    }
}


private extension Connection {
    private func runTask(statement: String, _ bindings: Binding?...) -> BFTask {
        return backgroundTask {
            return try self.run(statement, bindings)
        }
    }

    private func runTask(query: Insert) -> BFTask {
        return backgroundTask {
            return NSNumber(longLong: try self.run(query))
        }
    }
}


private extension SwimUri {
    private var dbFilename: String {
        return uri.stringBySanitizingFilename
    }
}


private func backgroundTask(f: () throws -> ()) -> BFTask {
    let task = BFTaskCompletionSource()
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        do {
            try f()
            task.setResult(nil)
        }
        catch Result.Error(message: let msg, code: let code, statement: _) {
            task.setError(NSError(sqlErrorCode: code, msg: msg))
        }
        catch let err {
            task.setError(NSError(unknownErrorType: err))
        }
    }
    return task.task
}


private func backgroundTask<T where T: AnyObject>(f: () throws -> T) -> BFTask {
    let task = BFTaskCompletionSource()
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        do {
            let result = try f()
            task.setResult(result)
        }
        catch Result.Error(message: let msg, code: let code, statement: _) {
            task.setError(NSError(sqlErrorCode: code, msg: msg))
        }
        catch let err {
            task.setError(NSError(unknownErrorType: err))
        }
    }
    return task.task
}
