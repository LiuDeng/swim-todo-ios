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


public class SwimOplogManager {
    public static let ErrorDomain = "SwimOplogManager.ErrorDomain"
    public static let SQLErrorDomain = "SwimOplogManager.SQLErrorDomain"


    public enum ErrorCode: Int {
        case UnknownError = 0
        case NotConnected
    }


    public var rootDir: NSURL = {
        let appSupportDir = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        return appSupportDir.URLByAppendingPathComponent(rootDirName)
    }()


    private var connections = [SwimUri: Connection]()
    private let tableOplog = Table("oplog")
    let colId = Expression<Int64>("id")
    let colTimestamp = Expression<NSDate>("timestamp")
    let colCounter = Expression<Int64>("counter")
    let colSwimValue = Expression<String>("swimValue")

    public func openAsync(lane: SwimUri) -> BFTask {
        if connections[lane] != nil {
            return BFTask(result: nil)
        }

        let path = dbPath(lane)

        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(rootDir.absoluteString, withIntermediateDirectories: true, attributes: nil)
            
            let db = try Connection(path.absoluteString)
            db.busyTimeout = 5
            db.busyHandler { $0 < 3 }

            connections[lane] = db

            return createTables(db)
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


    public func addEntryAsync(lane: SwimUri, timestamp: NSDate, counter: Int64, swimValue: SwimValue) -> BFTask {
        guard let db = connections[lane] else {
            return BFTask(error: NSError(errorCode: .NotConnected))
        }
        return db.runTask(tableOplog.insert(
            colTimestamp <- timestamp,
            colCounter <- counter,
            colSwimValue <- swimValue.recon
            ))
    }

    private func dbPath(lane: SwimUri) -> NSURL {
        return rootDir.URLByAppendingPathComponent(lane.dbFilename).URLByAppendingPathExtension("sqlite")
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
        return (uri.stringByReplacingOccurrencesOfString(":", withString: "_")
            .stringByReplacingOccurrencesOfString("/", withString: "_"))
    }
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
