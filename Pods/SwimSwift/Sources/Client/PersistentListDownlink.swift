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


    private var dbPath: String {
        return SwimGlobals.instance.dbManager!.dbPath(laneFQUri).path!
    }


    init(downlink: Downlink, objectMaker: (SwimValue -> SwimModelProtocolBase?), laneFQUri: SwimUri) {
        self.laneFQUri = laneFQUri
        super.init(downlink: downlink, objectMaker: objectMaker)
    }


    func loadFromDBAsync() -> BFTask {
        let laneUri = laneFQUri
        let dbManager = SwimGlobals.instance.dbManager!
        return dbManager.openAsync(laneUri, persistenceType: .List).continueWithSuccessBlock { _ in
            return dbManager.loadListContents(laneUri).continueWithSuccessBlock { [weak self] task in
                let contents = task.result as! [SwimRecord]
                dispatch_async(dispatch_get_main_queue()) {
                    self?.loadContents(contents)
                }
                return nil
            }
        }.continueWithBlock(handleDBErrors)
    }


    private func loadContents(contents: [SwimRecord]) {
        guard count == 0 else {
            log.verbose("\(laneFQUri) Not loading from DB; the server has already sent us some rows")
            return
        }

        sendWillChangeObjects()

        var idx = 0
        for content in contents {
            // Note, calling super because we don't want to try and insert
            // these rows into the DB, because that's where they just came
            // from.
            guard super.remoteInsert(SwimValue(content), atIndex: idx) else {
                log.error("Aborting loadContents; insert has failed")
                return
            }
            idx = idx + 1
        }

        sendDidChangeObjects()
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
        let dbTask = commandToDB(body)
        let downlinkTask = super.command(body: body)

        return BFTask(forCompletionOfAllTasks: [dbTask, downlinkTask])
    }


    private func commandToDB(body: SwimValue) -> BFTask {
        let dbManager = SwimGlobals.instance.dbManager!
        let now = NSDate()
        return dbManager.addEntryAsync(laneFQUri, timestamp: now, counter: 0, swimValue: body)
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
