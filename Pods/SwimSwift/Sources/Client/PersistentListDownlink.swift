//
//  PersistentDownlink.swift
//  Swim
//
//  Created by Ewan Mellor on 4/12/16.
//
//

import Bolts
import Foundation


private let log = SwimLogging.log


class PersistentListDownlink: ListDownlinkAdapter {
    private let laneFQUri: SwimUri
    private unowned let retryManager: OplogRetryManager


    private var dbPath: String {
        return SwimGlobals.instance.dbManager!.dbPath(laneFQUri).path!
    }


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?), laneFQUri: SwimUri, retryManager: OplogRetryManager) {
        self.laneFQUri = laneFQUri
        self.retryManager = retryManager
        super.init(downlink: downlink, objectMaker: objectMaker)
    }


    func loadFromDBAsync() -> BFTask {
        let laneUri = laneFQUri
        let dbManager = SwimGlobals.instance.dbManager!
        return dbManager.openAsync(laneUri, persistenceType: .List).continueWithSuccessBlock { _ in
            return dbManager.loadListContents(laneUri).continueWithSuccessBlock { [weak self] task in
                let contents = task.result as! [SwimRecord]
                let values = contents.map({ SwimValue($0) })
                dispatch_async(dispatch_get_main_queue()) {
                    self?.loadValues(values)
                }
                return nil
            }
        }.continueWithBlock(handleDBErrors)
    }


    override func insert(object: SwimModelProtocolBase, value: SwimValue, atIndex index: Int) -> BFTask {
        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        dbInsert(value, atIndex: index)
        return super.insert(object, value: value, atIndex: index)
    }


    override func replace(value: SwimValue, atIndex index: Int) -> BFTask {
        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        dbUpdate(value, atIndex: index)
        return super.replace(value, atIndex: index)
    }


    override func moveFromIndex(from: Int, toIndex to: Int) -> BFTask {
        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        dbMove(fromIndex: from, toIndex: to)
        return super.moveFromIndex(from, toIndex: to)
    }


    override func removeAtIndex(index: Int) -> (SwimModelProtocolBase?, BFTask) {
        if laneProperties.isClientReadOnly {
            return (nil, BFTask(swimError: .DownlinkIsClientReadOnly))
        }

        dbRemoveAtIndex(index)
        return super.removeAtIndex(index)
    }


    override func removeAll() -> BFTask {
        if laneProperties.isClientReadOnly {
            return BFTask(swimError: .DownlinkIsClientReadOnly)
        }

        dbRemoveAll()
        return super.removeAll()
    }


    override func remoteInsert(value: SwimValue, atIndex index: Int) -> Bool {
        guard super.remoteInsert(value, atIndex: index) else {
            return false
        }
        dbInsert(value, atIndex: index)
        return true
    }


    override func remoteUpdate(value: SwimValue, atIndex index: Int) -> Bool {
        guard super.remoteUpdate(value, atIndex: index) else {
            return false
        }
        dbUpdate(value, atIndex: index)
        return true
    }


    override func remoteMove(value: SwimValue, fromIndex from: Int, toIndex to: Int) -> Bool {
        guard super.remoteMove(value, fromIndex: from, toIndex: to) else {
            return false
        }
        dbMove(fromIndex: from, toIndex: to)
        return true
    }


    override func remoteRemove(value: SwimValue, atIndex index: Int) -> Bool {
        guard super.remoteRemove(value, atIndex: index) else {
            return false
        }
        dbRemoveAtIndex(index)
        return true
    }


    override func remoteRemoveAll() {
        super.remoteRemoveAll()
        dbRemoveAll()
    }


    override func command(body body: SwimValue) -> BFTask {
        // Write the command to both the DB and the server, then ack
        // the command in the DB once the server acks the command.
        //
        // We run the DB write and the server write in parallel.  We need
        // the results of both before we can process the ack though,
        // because we need the rowId of the DB entry.
        //
        // We run the DB ack asynchronously (i.e. we don't wait for it to
        // complete before we return success to the server).  If the app
        // dies before the ack is written then we're going to have an
        // outstanding command in the oplog, and we'll handle that like
        // any other.

        let dbTask = commandToDB(body)
        let downlinkTask = super.command(body: body)

        let joinTask = BFTask(forCompletionOfAllTasks: [dbTask, downlinkTask])

        return joinTask.continueWithBlock { [weak self] _ in
            if downlinkTask.faulted {
                return self?.handleFaultedCommand(body, dbTask, downlinkTask)
            }
            else {
                if dbTask.faulted {
                    log.warning("Command to server succeeded but DB write failed: \(dbTask.error).  Ignoring!")
                    assertionFailure()
                }
                else {
                    self?.ackDBCommand(dbTask)
                }
                return downlinkTask
            }
        }
    }


    private func commandToDB(body: SwimValue) -> BFTask {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        return dbManager.addOplogEntryAsync(laneFQUri, timestamp: now, counter: 0, swimValue: body)
    }


    private func ackDBCommand(dbTask: BFTask) -> BFTask {
        let dbRowId = (dbTask.result as! NSNumber).longLongValue

        log.verbose("Acking \(dbRowId)")

        let dbManager = SwimGlobals.instance.dbManager!
        return dbManager.ackOplogEntryAsync(laneFQUri, rowId: dbRowId).continueWithBlock(warnAboutAckFailures)
    }


    private func warnAboutAckFailures(task: BFTask) -> BFTask {
        if let err = task.error {
            log.warning("Error acking DB command: \(err).  Ignoring!")
            assertionFailure()
        }
        if let exn = task.exception {
            log.warning("Exception acking DB command: \(exn).  Ignoring!")
            assertionFailure()
        }
        return task
    }


    private func handleFaultedCommand(body: SwimValue, _ dbTask: BFTask, _ downlinkTask: BFTask) -> BFTask {
        if dbTask.faulted {
            log.warning("Failing command because both server and DB writes failed: \(downlinkTask.error) \(downlinkTask.exception) \(dbTask.error) \(dbTask.exception)")
            return downlinkTask
        }

        if let err = downlinkTask.error {
            if OplogRetryManager.isErrorRetriable(err) {
                log.verbose("Will retry command after error from server: \(err)")
                retryManager.scheduleRetry()
                return BFTask(result: nil)
            }
            else {
                log.warning("Failing command after error from server: \(err)")
                ackDBCommand(dbTask)
                return downlinkTask
            }
        }
        else if let exn = downlinkTask.exception {
            log.error("Failing command after internal exception: \(exn)")
            ackDBCommand(dbTask)
            return downlinkTask
        }
        else {
            // The caller has guaranteed that this is impossible.
            preconditionFailure()
        }
    }


    override func swimDownlinkDidLoseSync(downlink: Downlink) {
        super.swimDownlinkDidLoseSync(downlink)

        log.warning("Lost sync with \(laneFQUri).  Will resync.")
        // TODO!
    }


    private func dbInsert(value: SwimValue, atIndex index: Int) {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        dbManager.insertListEntry(laneFQUri, timestamp: now, swimValue: value, index: index).continueWithBlock(handleDBErrors)
    }

    private func dbUpdate(value: SwimValue, atIndex index: Int) {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        dbManager.updateListEntry(laneFQUri, timestamp: now, swimValue: value, index: index).continueWithBlock(handleDBErrors)
    }

    private func dbMove(fromIndex from: Int, toIndex to: Int) {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        dbManager.moveListEntry(laneFQUri, timestamp: now, fromIndex: from, toIndex: to).continueWithBlock(handleDBErrors)
    }

    private func dbRemoveAtIndex(index: Int) {
        let dbManager = SwimGlobals.instance.dbManager!
        dbManager.removeListEntry(laneFQUri, index: index).continueWithSuccessBlock(checkForOneRow).continueWithBlock(handleDBErrors)
    }

    private func dbRemoveAll() {
        let dbManager = SwimGlobals.instance.dbManager!
        dbManager.removeAllListEntries(laneFQUri).continueWithBlock(handleDBErrors)
    }

    private func checkForOneRow(task: BFTask) -> BFTask {
        let number = task.result as! NSNumber
        let rowCount = number.intValue
        if rowCount == 1 {
            return task
        }
        else {
            log.error("DB operation to \(laneFQUri) failed.  Lane is broken now.")
            // TODO: Better error response, trigger reset
            let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: nil)
            return BFTask(error: err)
        }
    }

    private func handleDBErrors(task: BFTask) -> BFTask {
        // TODO: Better error response, trigger reset
        if let err = task.error {
            log.error("DB operation to \(laneFQUri) \(dbPath) failed: \(err).  Lane is broken now.")
        }
        if let exn = task.exception {
            log.error("DB operation to \(laneFQUri) \(dbPath) failed: \(exn).  Lane is broken now.")
        }
        return task
    }
}


func == (lhs: PersistentListDownlink, rhs: PersistentListDownlink) -> Bool {
    return lhs === rhs
}
