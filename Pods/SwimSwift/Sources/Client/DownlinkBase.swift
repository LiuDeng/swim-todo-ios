//
//  DownlinkBase.swift
//  Swim
//
//  Created by Ewan Mellor on 5/3/16.
//
//

import Bolts
import Foundation


private let log = SwimLogging.log


public class DownlinkBase: Hashable {
    /**
     May only be accessed under objc_sync_enter(self)
     */
    var delegates = WeakArray<AnyObject>()


    public func addDelegate(delegate: DownlinkDelegate) {
        objc_sync_enter(self)
        delegates.append(delegate)
        objc_sync_exit(self)
    }

    public func removeDelegate(delegate: DownlinkDelegate) {
        objc_sync_enter(self)
        delegates.remove(delegate)
        objc_sync_exit(self)
    }


    func sendDidReceiveError(err: ErrorType) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.sendDidReceiveError_(err)
        }
    }

    private func sendDidReceiveError_(err: ErrorType) {
        forEachDelegate {
            $0.swimDownlink($1, didReceiveError: err)
        }
    }


    func sendDidCompleteServerWrites(object: SwimModelProtocolBase) {
        forEachDelegate {
            $0.swimDownlink($1, didCompleteServerWritesOfObject: object)
        }
    }


    func handleFailures(task: BFTask) -> BFTask {
        if let err = task.error {
            log.warning("Operation failed: \(err).")
            sendDidReceiveError(err)
        }
        if let exn = task.exception {
            log.warning("Operation failed: \(exn).")
            let err = SwimError.Unknown
            sendDidReceiveError(err)
        }
        return task
    }

    func logFailures(task: BFTask) -> BFTask {
        if let err = task.error {
            log.warning("Operation failed: \(err).")
        }
        if let exn = task.exception {
            log.warning("Operation failed: \(exn).")
        }
        return task
    }


    func forEachDelegate(f: (DownlinkDelegate, Downlink) -> ()) {
        SwimAssertOnMainThread()

        objc_sync_enter(self)
        var copiedDelegates = [DownlinkDelegate]()
        for delegate in delegates {
            copiedDelegates.append(delegate as! DownlinkDelegate)
        }
        objc_sync_exit(self)

        let downlink = self as! Downlink
        for delegate in copiedDelegates {
            f(delegate, downlink)
        }
    }


    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}


public func == (lhs: DownlinkBase, rhs: DownlinkBase) -> Bool {
    return lhs === rhs
}
