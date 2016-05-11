//
//  SwimDBManager.swift
//  Swim
//
//  Created by Ewan Mellor on 4/4/16.
//
//

import Bolts
import Recon
import SQLite


private let rootDirName = "SwimOplog"

private let log = SwimLogging.log

private let tableOplog = Table("oplog")
private let colId = Expression<Int64>("id")
private let colTimestamp = Expression<NSDate>("timestamp")
private let colCounter = Expression<Int64>("counter")
private let colSwimValue = Expression<String>("swimValue")

private let tableList = Table("list")
private let colIndex = Expression<Int>("index")

private let oneBillion = 1000000000


public class SwimDBManager {
    public static let ErrorDomain = "SwimDBManager.ErrorDomain"
    public static let SQLErrorDomain = "SwimDBManager.SQLErrorDomain"


    public enum PersistenceType {
        case None
        case List
    }


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
            closeAllConnections()
        }
    }


    public func openAsync(lane: SwimUri, persistenceType: PersistenceType) -> BFTask {
        return withSelfLock {
            return self.openAsync_(lane, persistenceType)
        }
    }

    /// May only be called under objc_sync_enter(self)
    private func openAsync_(lane: SwimUri, _ persistenceType: PersistenceType) -> BFTask {
        if connections[lane] != nil {
            return BFTask(result: nil)
        }

        let path = dbPath(lane)

        do {
            let dir = path.URLByDeletingLastPathComponent!.path!
            let fm = NSFileManager.defaultManager()
            try fm.createDirectoryAtPath(dir, withIntermediateDirectories: true, attributes: nil)

            let db = try Connection(path.path!)
            db.busyTimeout = 5
            db.busyHandler { $0 < 3 }

            connections[lane] = db

            return db.runConfigureConnection().continueWithSuccessBlock { [weak self] _ in
                self?.createTables(db, persistenceType)
            }.continueWithSuccessBlock { [weak self] _ in
                self?.loadStats(path)
            }.continueWithSuccessBlock { [weak self] _ in
                self?.loadTotalStats()
            }.continueWithSuccessBlock { _ in
                log.verbose("Opened connection to \(path)")
                return nil
            }
        }
        catch Result.Error(message: let msg, code: let code, statement: _) {
            return BFTask(error: NSError(sqlErrorCode:  code, msg: msg))
        }
        catch let err {
            return BFTask(error: NSError(unknownErrorType: err))
        }
    }


    private func createTables(db: Connection, _ persistenceType: PersistenceType) -> BFTask {
        var tasks = [
            tableOplog.create(ifNotExists: true) { t in
                t.column(colId, primaryKey: .Autoincrement)
                t.column(colTimestamp)
                t.column(colCounter)
                t.column(colSwimValue)
            }
        ]
        if persistenceType == .List {
            tasks.append(tableList.create(ifNotExists: true) { t in
                t.column(colIndex, primaryKey: true)
                t.column(colTimestamp)
                t.column(colSwimValue)
            })
        }
        return db.runTasks(tasks)
    }


    private func loadStats(path: NSURL) -> BFTask {
        return backgroundTask { [weak self] in
            self?.loadStatsBackground(path)
        }
    }

    private func loadStatsBackground(path: NSURL) {
        let fm = NSFileManager.defaultManager()
        let fileSize = fm.fileSize(path)

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
            log.warning("Failed to load filesystem stats for \(rootDir)")
            return
        }

        objc_sync_enter(self)
        for (url, size) in sizes {
            let str = url.absoluteString
            if str.hasSuffix("/") || str.hasSuffix(".sqlite") || str.hasSuffix(".sqlite-shm") || str.hasSuffix(".sqlite-wal") {
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


    public func addOplogEntryAsync(lane: SwimUri, timestamp: NSDate, counter: Int64, swimValue: SwimValue) -> BFTask {
        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runTask(tableOplog.insert(
            colTimestamp <- timestamp,
            colCounter <- counter,
            colSwimValue <- swimValue.recon
            ))
    }


    public func ackOplogEntryAsync(lane: SwimUri, rowId: Int64) -> BFTask {
        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runTask(tableOplog.filter(colId == rowId).delete())
    }


    @warn_unused_result
    public func getOplogEntries(lane: SwimUri) -> BFTask {
        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runQueryTask(tableOplog.select(colId, colTimestamp, colCounter, colSwimValue).order(colId)) { row -> OplogEntry? in
            let rowId = row.get(colId)
            let ts = row.get(colTimestamp)
            let c = row.get(colCounter)
            let valStr = row.get(colSwimValue)
            guard let val = recon(valStr) else {
                log.error("Unparsable value \(valStr) in database!  Ignoring row.")
                return nil
            }
            return OplogEntry(rowId, ts, c, val)
        }
    }


    /**
     - returns: A task that will have a NSArray as the result.  The contents
     of that array will SwimRecord instances if the value is a record.
     TODO: Unimplemented: returning primitive types.
     */
    public func loadListContents(lane: SwimUri) -> BFTask {
        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        var expectedIdx = 1
        return db.runQueryTask(tableList.select(colSwimValue, colIndex).order(colIndex)) { row -> SwimRecord? in
            let reconStr = row.get(colSwimValue)
            let idx = row.get(colIndex)
            guard idx == expectedIdx else {
                log.error("DB row index \(idx) out of sync.  Ignoring row.")
                return nil
            }
            guard let value = recon(reconStr)?.record else {
                log.error("Unparsable value \(reconStr) in database!  Ignoring row.")
                return nil
            }
            log.verbose("Loaded row \(idx) \(reconStr)")
            expectedIdx = expectedIdx + 1
            return value
        }
    }


    public func insertListEntry(lane: SwimUri, timestamp: NSDate, swimValue: SwimValue, index index_: Int) -> BFTask {
        precondition(index_ >= 0)
        let index = index_ + 1

        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        // colIndex is the primary key, so we need to renumber all rows
        // after the insertion point.  This has to be done by leaping
        // them to index + oneBillion and then back down again, to avoid
        // primary key conflicts during the update.
        return backgroundTask { () -> NSNumber in
            var rowId = Int64(0)
            try db.transaction {
                let others = tableList.filter(colIndex >= index)
                try db.run(others.update(colIndex <- colIndex + oneBillion))

                rowId = try db.run(tableList.insert(
                    colIndex <- index,
                    colTimestamp <- timestamp,
                    colSwimValue <- swimValue.recon
                    ))

                let adjustedOthers = tableList.filter(colIndex >= (index + oneBillion))
                try db.run(adjustedOthers.update(colIndex <- colIndex - (oneBillion - 1)))
            }
            return NSNumber(longLong: rowId)
        }
    }


    public func updateListEntry(lane: SwimUri, timestamp: NSDate, swimValue: SwimValue, index index_: Int) -> BFTask {
        precondition(index_ >= 0)
        let index = index_ + 1

        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runTask(tableList.insert(or: .Replace,
            colIndex <- index,
            colTimestamp <- timestamp,
            colSwimValue <- swimValue.recon
            ))
    }


    public func moveListEntry(lane: SwimUri, timestamp: NSDate, fromIndex fromIndex_: Int, toIndex toIndex_: Int) -> BFTask {
        precondition(fromIndex_ >= 0)
        precondition(toIndex_ >= 0)
        precondition(fromIndex_ != toIndex_)
        let fromIndex = fromIndex_ + 1
        let toIndex = toIndex_ + 1

        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }

        // Moving down the list, everything in the gap moves to index - 1.
        // Moving up the list, everything in the gap moves to index + 1.
        // This has to be done by leaping them to index + oneBillion and
        // then back down again, to avoid primary key conflicts during the
        // update.
        let gapOffset = (fromIndex < toIndex ? -1 : 1)
        func f() throws -> NSNumber {
            var rowId = Int64(0)
            try db.transaction {
                guard let oldValue = db.pluck(tableList.select(colSwimValue).filter(colIndex == fromIndex))?.get(colSwimValue) else {
                    return
                }

                tableList.filter(colIndex == fromIndex).delete()
                let gap = tableList.filter(colIndex > fromIndex && colIndex <= toIndex)
                try db.run(gap.update(colIndex <- colIndex + oneBillion))
                rowId = try db.run(tableList.insert(
                    colTimestamp <- timestamp,
                    colIndex <- toIndex,
                    colSwimValue <- oldValue
                ))
                let offsetGap = tableList.filter(colIndex > fromIndex + oneBillion)
                try db.run(offsetGap.update(colIndex <- colIndex - oneBillion + gapOffset))
            }
            return NSNumber(longLong: rowId)
        }
        return backgroundTask(f)
    }


    public func removeListEntry(lane: SwimUri, index index_: Int) -> BFTask {
        precondition(index_ >= 0)
        let index = index_ + 1

        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        // Remove the specified row, and change all the rows after that one
        // to adjust the index.
        return backgroundTask { () -> NSNumber in
            var affectedRowCount = 0
            try db.transaction {
                let entry = tableList.filter(colIndex == index)
                affectedRowCount = try db.run(entry.delete())
                if affectedRowCount == 0 {
                    return
                }

                // This has to be done by leaping them to index + oneBillion and
                // then back down again, to avoid primary key conflicts during the
                // update.
                let others = tableList.filter(colIndex > index)
                try db.run(others.update(colIndex <- colIndex + oneBillion))
                let movedOthers = tableList.filter(colIndex > index)
                try db.run(movedOthers.update(colIndex <- colIndex - oneBillion - 1))
            }
            return NSNumber(long: affectedRowCount)
        }
    }


    public func removeAllListEntries(lane: SwimUri) -> BFTask {
        guard let db = connectionForLane(lane) else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runTask(tableList.delete())
    }


    public func statistics() -> [NSURL: Stats] {
        objc_sync_enter(self)
        let result = stats
        objc_sync_exit(self)
        return result
    }


    public func deleteAllBackingFiles() {
        closeAllConnections()

        let fm = NSFileManager.defaultManager()
        let _ = try? fm.removeItemAtURL(rootDir)
    }


    public func deleteBackingFile(lane: SwimUri) {
        closeConnection(lane)

        let path = dbPath(lane)
        let extlessPath = path.URLByDeletingPathExtension!
        let fm = NSFileManager.defaultManager()
        let _ = try? fm.removeItemAtURL(path)
        let _ = try? fm.removeItemAtURL(extlessPath.URLByAppendingPathExtension("sqlite-shm"))
        let _ = try? fm.removeItemAtURL(extlessPath.URLByAppendingPathExtension("sqlite-wal"))
    }


    func applicationWillResignActive() {
        for (_, conn) in connections {
            conn.runIncrementalVacuum().continueWithBlock(logFailures)
        }
    }


    private func logFailures(task: BFTask) -> BFTask {
        if let err = task.error {
            log.warning("Operation failed: \(err).")
        }
        if let exn = task.exception {
            log.warning("Operation failed: \(exn).")
        }
        return task
    }


    public func dbPath(lane: SwimUri) -> NSURL {
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


    func closeAllConnections() {
        withSelfLock {
            self.connections.removeAll()
        }
    }


    func closeConnection(lane: SwimUri) {
        withSelfLock {
            self.connections.removeValueForKey(lane)
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
    private convenience init(errorCode: SwimDBManager.ErrorCode, userInfo: [NSObject : AnyObject]? = nil)  {
        self.init(domain: SwimDBManager.ErrorDomain, code: errorCode.rawValue, userInfo: userInfo)
    }

    private convenience init(unknownErrorType: ErrorType) {
        self.init(errorCode: .UnknownError, userInfo: ["error": String(unknownErrorType)])
    }

    private convenience init(sqlErrorCode: Int32, msg: String) {
        self.init(domain: SwimDBManager.SQLErrorDomain, code: Int(sqlErrorCode), userInfo: ["message": msg])
    }
}


private extension Connection {
    private func runConfigureConnection() -> BFTask {
        return backgroundTask {
            try self.execute("PRAGMA journal_mode=WAL; PRAGMA auto_vacuum=INCREMENTAL")
        }
    }

    private func runIncrementalVacuum() -> BFTask {
        return backgroundTask {
            try self.execute("PRAGMA incremental_vacuum")
        }
    }

    /**
     - returns: A task which will have [T] as the result.
     */
    private func runQueryTask<T: AnyObject>(query: QueryType, f: Row -> T?) -> BFTask {
        return backgroundTask {
            return try self.prepare(query).flatMap(f) as NSArray
        }
    }

    /**
     - returns: A task which will have a Statement as the result.
     */
    private func runTask(statement: String, _ bindings: Binding?...) -> BFTask {
        return backgroundTask {
            return try self.run(statement, bindings)
        }
    }

    /**
     - returns: A task which will have rowId: NSNumber as the result.
     */
    private func runTask(query: Insert) -> BFTask {
        return backgroundTask {
            return NSNumber(longLong: try self.run(query))
        }
    }

    /**
     - returns: A task which will have affectedRowCount: NSNumber as the
       result.
     */
    private func runTask(query: Delete) -> BFTask {
        return backgroundTask {
            return NSNumber(long: try self.run(query))
        }
    }

    /**
     - returns: A task which will have [Statement] as the result.
     */
    private func runTasks(statements: [String], _ bindings: Binding?...) -> BFTask {
        func f() throws -> NSArray {
            return try statements.map { statement in
                return try self.run(statement, bindings)
            }
        }
        return backgroundTask(f)
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


@objc class OplogEntry: NSObject {
    let rowId: Int64
    let timestamp: NSDate
    let counter: Int64
    let swimValue: SwimValue

    private init(_ rowId: Int64, _ timestamp: NSDate, _ counter: Int64, _ swimValue: SwimValue) {
        self.rowId = rowId
        self.timestamp = timestamp
        self.counter = counter
        self.swimValue = swimValue
    }
}
