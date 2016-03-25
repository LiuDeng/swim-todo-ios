//
//  Batcher.swift
//  Swim
//
//  Created by Ewan Mellor on 3/24/16.
//
//

import Foundation


/**
 A Batcher will hold onto objects for you for a while, and then give you them back in a batch.

 It will hold onto the first object in the batch for at least minDelay, to give you a chance
 to add more objects.  If you add another object then the batch will be delayed further,
 to allow it to get even bigger.  This will continue until the first object has been delayed
 by maxDelay, at which point the batch is sent even if new objects are still being added.

 This class does no thread operations of its own.  It uses performSelector on the thread that
 you call addObject on, and you will be called back on that thread.
 */
class Batcher<T> {
    private let minDelay: NSTimeInterval
    private let maxDelay: NSTimeInterval
    private let dispatchQueue: dispatch_queue_t
    private let onBatch: ([T] -> Void)

    /**
     May only be accessed under objc_sync_enter(self).
     */
    private var objectArray: [T]?

    /**
     May only be accessed under objc_sync_enter(self).
     */
    private var firstInsertion: NSTimeInterval = 0

    /**
     May only be accessed under objc_sync_enter(self).
     */
    private var delayBlock: dispatch_block_t?


    init(minDelay: NSTimeInterval, maxDelay: NSTimeInterval, dispatchQueue: dispatch_queue_t, onBatch: ([T] -> Void)) {
        precondition(minDelay > 0.0)
        precondition(maxDelay > 0.0)

        self.minDelay = minDelay
        self.maxDelay = maxDelay
        self.dispatchQueue = dispatchQueue
        self.onBatch = onBatch
    }


    func addObject(object: T) {
        let now = NSDate.timeIntervalSinceReferenceDate()

        objc_sync_enter(self)

        if objectArray == nil {
            objectArray = [object]
            firstInsertion = now
            sendBatchAfter(minDelay)
        }
        else {
            objectArray!.append(object)
            let delta = now - firstInsertion
            let diff = maxDelay - delta
            if diff > 0 {
                // This batch can wait a bit longer.
                dispatch_block_cancel(delayBlock!)
                let newDelay = min(diff, minDelay)
                sendBatchAfter(newDelay)
            }
            else {
                // This batch is going as soon as its timer fires, which is any moment now.
            }
        }

        objc_sync_exit(self)
    }


    /// Must only be called under objc_sync_enter(self)
    private func sendBatchAfter(delay: NSTimeInterval) {
        let db = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS) { [weak self] in
            self?.sendBatch()
        }
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC)))
        dispatch_after(when, dispatchQueue, db)
        delayBlock = db
    }


    /**
     Force a batch to be sent immediately, rather than waiting for the timeout to expire.
     */
    func sendBatch() {
        var batch: [T]? = nil

        objc_sync_enter(self)
        batch = objectArray
        objectArray = nil
        delayBlock = nil
        objc_sync_exit(self)

        if let b = batch where b.count > 0 {
            onBatch(b)
        }
    }
}
