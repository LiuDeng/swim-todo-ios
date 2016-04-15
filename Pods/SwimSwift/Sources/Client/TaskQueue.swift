//
//  CommandQueue.swift
//  Swim
//
//  Created by Ewan Mellor on 4/12/16.
//
//

import Bolts
import Foundation


private let log = SwimLogging.log


class TaskQueue {
    /**
     The first element is the oldest, and therefore the next to be acked.

     May only be accessed inside objc_sync_enter(self).
     */
    private var queue = [BFTaskCompletionSource]()


    func append(task: BFTaskCompletionSource) {
        objc_sync_enter(self)
        queue.append(task)
        objc_sync_exit(self)
    }


    func ack(count_: Int) {
        var count = count_

        objc_sync_enter(self)

        if queue.count < count {
            log.error("Received ack for command that we didn't send!  Recovering by just acking everything!")
            assertionFailure()
            count = queue.count
        }

        let tasks = queue[0 ..< count]
        queue.removeFirst(count)

        objc_sync_exit(self)

        tasks.forEach {
            $0.setResult(nil)
        }
    }


    func failAll(error: NSError) {
        objc_sync_enter(self)

        let tasks = queue
        queue.removeAll()

        objc_sync_exit(self)

        tasks.forEach {
            $0.setError(error)
        }
    }
}
