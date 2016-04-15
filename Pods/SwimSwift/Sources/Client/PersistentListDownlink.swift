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


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?), laneFQUri: SwimUri) {
        self.laneFQUri = laneFQUri
        super.init(downlink: downlink, objectMaker: objectMaker)
    }


    override func remoteInsert(value: SwimValue, atIndex index: Int) -> Bool {
        guard super.remoteInsert(value, atIndex: index) else {
            return false
        }
        dbInsertOrUpdate(value, atIndex: index)
        return true
    }


    override func remoteUpdate(value: SwimValue, atIndex index: Int) -> Bool {
        guard super.remoteUpdate(value, atIndex: index) else {
            return false
        }
        dbInsertOrUpdate(value, atIndex: index)
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
        let dbTask = commandToDB(body)
        let downlinkTask = super.command(body: body)

        return BFTask(forCompletionOfAllTasks: [dbTask, downlinkTask])
    }


    private func commandToDB(body: SwimValue) -> BFTask {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        return dbManager.addEntryAsync(laneFQUri, timestamp: now, counter: 0, swimValue: body)
    }


    private func dbInsertOrUpdate(value: SwimValue, atIndex index: Int) {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        dbManager.insertOrUpdateListEntry(laneFQUri, timestamp: now, swimValue: value, index: index).continueWithBlock(handleDBErrors)
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
            log.error("DB operation to \(laneFQUri) failed: \(err).  Lane is broken now.")
        }
        if let exn = task.exception {
            log.error("DB operation to \(laneFQUri) failed: \(exn).  Lane is broken now.")
        }
        return task
    }
}


func == (lhs: PersistentListDownlink, rhs: PersistentListDownlink) -> Bool {
    return lhs === rhs
}
