//
//  OplogRetryManager.swift
//  Swim
//
//  Created by Ewan Mellor on 5/9/16.
//
//

import Bolts
import Foundation


private let initialRetryInterval = 5.0
private let maxRetryInterval = 60.0

private let log = SwimLogging.log


public class OplogRetryManager {
    private let laneFQUri: SwimUri
    private unowned let downlink: RemoteDownlink
    private unowned let dbManager: SwimDBManager
    private unowned let networkMonitor: SwimNetworkConditionMonitor.ServerMonitor

    // All vars may only be accessed under objc_sync_enter(self)

    private var needsRetry = false
    private var retryInProgress = false

    /**
     This is kept in reverse order from what came out of the database,
     so that we can use popLast to get each entry in turn.
     */
    private var commandsBeingRetried = [OplogEntry]()

    private var retryInterval = initialRetryInterval
    private var timer: NSTimer?


    init(laneFQUri: SwimUri, downlink: RemoteDownlink, dbManager: SwimDBManager, networkMonitor: SwimNetworkConditionMonitor.ServerMonitor) {
        self.laneFQUri = laneFQUri
        self.downlink = downlink
        self.dbManager = dbManager
        self.networkMonitor = networkMonitor

        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(OplogRetryManager.applicationDidEnterBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(OplogRetryManager.networkConditionChanged), name: SwimNetworkConditionMonitor.conditionChangedNotification, object: networkMonitor)
    }


    @objc func applicationDidEnterBackground() {
        objc_sync_enter(self)

        if needsRetry {
            retryCommands()
        }

        objc_sync_exit(self)
    }


    @objc func networkConditionChanged() {
        objc_sync_enter(self)

        if needsRetry && networkMonitor.networkCondition == .Healthy {
            retryCommands()
        }

        objc_sync_exit(self)
    }

    
    func scheduleRetry() {
        objc_sync_enter(self)

        needsRetry = true
        if let t = timer {
            t.invalidate()
        }
        timer = NSTimer.scheduledTimerWithTimeInterval(retryInterval, target: self, selector: #selector(OplogRetryManager.tick), userInfo: nil, repeats: false)

        objc_sync_exit(self)
    }

    @objc private func tick() {
        retryCommands()
    }


    private func retryCommands() {
        objc_sync_enter(self)

        if retryInProgress {
            log.verbose("Retries already in progress, skipping this request")
        }
        else {
            log.verbose("Starting retry")
            retryInProgress = true
            dbManager.getOplogEntries(laneFQUri).continueWithBlock(retryCommands)
        }

        objc_sync_exit(self)
    }


    private func retryCommands(commandTask: BFTask) -> AnyObject? {
        if commandTask.faulted {
            log.error("Failed to get oplog entries: \(commandTask.error) \(commandTask.exception)")
            objc_sync_enter(self)
            retryInProgress = false
            objc_sync_exit(self)
            return nil
        }

        objc_sync_enter(self)
        commandsBeingRetried = (commandTask.result as! [OplogEntry]).reverse()
        log.verbose("Will retry \(commandsBeingRetried.count) commands")
        objc_sync_exit(self)

        retryNextCommand()
        return nil
    }

    private func retryNextCommand() {
        objc_sync_enter(self)

        guard let command = commandsBeingRetried.popLast() else {
            log.verbose("All retries done.")
            retryInProgress = false
            objc_sync_exit(self)
            return
        }

        objc_sync_exit(self)

        downlink.command(body: command.swimValue).continueWithBlock { [weak self] task in
            self?.checkRetryStatus(command, task)
            return nil
        }
    }

    private func checkRetryStatus(command: OplogEntry, _ task: BFTask) {
        if task.faulted {
            handleRetryFailure(command, task)
            return
        }

        let rowId = command.rowId
        log.verbose("Success after retrying \(rowId)")
        dbManager.ackOplogEntryAsync(laneFQUri, rowId: rowId)

        retryNextCommand()
    }

    private func handleRetryFailure(command: OplogEntry, _ task: BFTask) {
        var isPerm: Bool

        if let err = task.error {
            if OplogRetryManager.isErrorRetriable(err) {
                log.debug("Will retry command again: \(err)")
                isPerm = false
            }
            else {
                log.debug("Permanent failure: \(err)")
                isPerm = true
            }
        }
        else if let exn = task.exception {
            log.error("Exception retrying command, treating as permanent failure: \(exn)")
            isPerm = true
        }
        else {
            // The caller has guaranteed that this is impossible.
            preconditionFailure()
        }

        objc_sync_enter(self)
        log.verbose("Aborting retries following failure.")
        commandsBeingRetried.removeAll()
        retryInProgress = false

        if isPerm {
            downlink.didLoseSync()
        }
        else {
            extendRetryInterval()
        }

        objc_sync_exit(self)
    }


    /// Must be called under objc_sync_enter(self)
    private func extendRetryInterval() {
        if retryInterval < maxRetryInterval {
            retryInterval *= 2
        }

        scheduleRetry()
    }


    class func isErrorRetriable(err: NSError) -> Bool {
        if err.domain == SwimErrorDomain {
            let swimErr = SwimError(rawValue: err.code) ?? SwimError.Unknown
            switch swimErr {
            case .NotAuthorized, .NetworkError:
                return true

            default:
                return false
            }
        }
        else {
            return false
        }
    }
}
