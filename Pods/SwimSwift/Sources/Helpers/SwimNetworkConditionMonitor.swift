//
//  NetworkConditionMonitor.swift
//  Swim
//
//  Created by Ewan Mellor on 3/29/16.
//
//

import Foundation
import ReachabilitySwift

private let log = SwimLogging.log

private let EMA_ALPHA: Double = 0.25


/**
 A monitor for network health.  This uses the Reachability framework to give
 a reachable / unreachable indication from the OS, and uses statistics
 provided by the network layer (Channel) to give a more fine-grained
 understanding of network health, so that we can indicate whether the
 connection is healthy or degraded.
 */
public class SwimNetworkConditionMonitor {
    public static let conditionChangedNotification = "NetworkConditionMonitor.conditionChangedNotification"


    public enum NetworkCondition {
        /**
         Network health unknown. This is the normal state before a network
         request has been made, because we don't get reachability info
         until a network request is attempted and so the radios have been
         turned on.
         */
        case Unknown

        /**
         Reported unreachable by the OS.  The network is down or
         unreachable, or the phone is in airplane mode.
         */
        case Unreachable

        /**
         The OS reports that the host is reachable, but our stats show
         that we have recently failed to communicate nonetheless.

         This indicates a network connection that is transmitting slower
         than our timeout allows, or is dropping packets, or is bouncing up
         and down.
         */
        case Degraded

        /**
         Happy happy joy joy.
         */
        case Healthy

        /**
         The monitoring has been shut down.  This ServerMonitor is now
         useless.
         */
        case Unmonitored
    }
    
    
    public class ServerMonitor {
        public let host: String
        public let isWWANAllowed: Bool

        /**
         The network condition the last time we received any information
         on the matter.

         Use NSNotificationCenter with conditionChangedNotification
         to listen for changes that will affect this property.
         */
        public private(set) var networkCondition: NetworkCondition = .Unknown

        private let reachability: Reachability?


        // All var fields may only be accessed under objc_sync_enter(self).

        private var refCount = 1

        private var isDegraded: Bool = false
        private var isShutdown: Bool = false

        private var hasEverSeenAnEvent = false

        private var tickPassed: Int = 0
        private var tickPassedPrev: Int = 0
        private var tickFailed: Int = 0
        private var tickFailedPrev: Int = 0
        private var lastSampleAt: NSTimeInterval = 0
        private var periodPassedEMA: Double = 0
        private var periodFailedEMA: Double = 0


        private init(host: String, isWWANAllowed: Bool) {
            self.host = host
            self.isWWANAllowed = isWWANAllowed

            do {
                reachability = try Reachability(hostname: host)
                reachability?.whenReachable = reachabilityChanged
                reachability?.whenUnreachable = reachabilityChanged
            }
            catch let err {
                log.error("Unable to create Reachability to \(host): \(err)")
                reachability = nil
            }

            log.verbose("Monitoring connection to \(host)")
        }

        private func startMonitoring() {
            do {
                try reachability?.startNotifier()
            }
            catch let err {
                log.error("Unable to start Reachability to \(host): \(err)")
            }
        }

        private func stopMonitoring() {
            reachability?.stopNotifier()
            isShutdown = true
        }

        private func reachabilityChanged(_: Reachability) {
            log.verbose("Reachability to \(host) changed")

            objc_sync_enter(self)
            hasEverSeenAnEvent = true
            recalcNetworkCondition()
            objc_sync_exit(self)
        }

        /**
         Call this to indicate that a response was successfully received on
         this network.  This drives the Healthy / Degraded stats.
         */
        public func networkResponseReceived() {
            objc_sync_enter(self)

            let now = NSDate.timeIntervalSinceReferenceDate()
            tickPassed += 1

            if lastSampleAt == 0 {
                lastSampleAt = now
            }

            let delta = now - lastSampleAt
            if delta < 1 {
                objc_sync_exit(self)
                return
            }
            periodPassedEMA = calcEMA(sample: Double(tickPassed), prevSample: Double(tickPassedPrev), prevEMA: periodPassedEMA, delta: delta)
            tickPassedPrev = tickPassed
            lastSampleAt = now

            recalcScore()

            objc_sync_exit(self)
        }

        /**
         Call this to indicate that a network request timed out or failed.
         This drives the Healthy / Degraded stats.
         */
        public func networkErrorReceived() {
            objc_sync_enter(self)

            let now = NSDate.timeIntervalSinceReferenceDate()
            tickFailed += 1

            if lastSampleAt == 0 {
                lastSampleAt = now
            }

            let delta = now - lastSampleAt
            if delta < 1 {
                objc_sync_exit(self)
                return
            }
            periodFailedEMA = calcEMA(sample: Double(tickFailed), prevSample: Double(tickFailedPrev), prevEMA: periodFailedEMA, delta: delta)
            tickFailedPrev = tickFailed
            lastSampleAt = now

            recalcScore()

            objc_sync_exit(self)
        }

        /// May only be called under objc_sync_enter(self)
        private func recalcScore() {
            let newScore = networkConditionScore()
            log.verbose("Network condition for \(host) = \(newScore)")
            let newIsDegraded = (newScore < 0.5)
            if newIsDegraded == isDegraded {
                return
            }
            isDegraded = newIsDegraded
            recalcNetworkCondition()
        }

        /// May only be called under objc_sync_enter(self)
        private func recalcNetworkCondition() {
            let newNetworkCondition = currentNetworkCondition()
            if newNetworkCondition == networkCondition {
                return
            }
            networkCondition = newNetworkCondition
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName(SwimNetworkConditionMonitor.conditionChangedNotification, object: self)
            }
        }

        /// May only be called under objc_sync_enter(self)
        private func currentNetworkCondition() -> NetworkCondition {
            if isShutdown {
                return .Unmonitored
            }
            if !hasEverSeenAnEvent {
                return .Unknown
            }

            switch reachability?.currentReachabilityStatus {
            case .NotReachable?:
                return .Unreachable

            case .ReachableViaWiFi?, nil:
                return (isDegraded ? .Degraded : .Healthy)

            case .ReachableViaWWAN?:
                return (!isWWANAllowed ? .Unreachable : isDegraded ? .Degraded : .Healthy)
            }
        }
        
        /// May only be called under objc_sync_enter(self)
        private func networkConditionScore() -> Double {
            if periodPassedEMA + periodFailedEMA == 0.0 {
                return 1.0
            }
            return (periodPassedEMA - periodFailedEMA) / (periodPassedEMA + periodFailedEMA)
        }
    }


    /**
     May only be accessed under objc_sync_enter(monitors).
     */
    private var monitors = [String: ServerMonitor]()


    /**
     Start monitoring the network to the specified host.  This will start
     Reachability monitoring if necessary.

     Note that this is reference counted per host: you should pair your
     `startMonitoring` and `stopMonitoring` calls and the monitoring will
     be torn down once the last monitor for a given host is stopped.
     */
    public func startMonitoring(host: String, isWWLANAllowed: Bool = true) -> ServerMonitor {
        objc_sync_enter(monitors)

        if let monitor = monitors[host] {
            objc_sync_enter(monitor)
            monitor.refCount += 1
            objc_sync_exit(monitor)

            objc_sync_exit(monitors)
            return monitor
        }

        let monitor = ServerMonitor(host: host, isWWANAllowed: isWWLANAllowed)
        monitors[host] = monitor

        objc_sync_exit(monitors)

        monitor.startMonitoring()

        return monitor
    }


    /**
     - returns: The ServerMonitor for the given host, if any.  This does
     not change the reference count on the ServerMonitor.
     */
    public func getMonitor(host: String) -> ServerMonitor? {
        objc_sync_enter(monitors)
        let monitor = monitors[host]
        objc_sync_exit(monitors)
        return monitor
    }


    /**
     Decrement the reference count on the given ServerMonitor, and stop it
     monitoring if the refcount drops to 0.
     */
    public func stopMonitoring(monitor: ServerMonitor) {
        stopMonitoring(monitor.host)
    }

    /**
     Decrement the reference count on the ServerMonitor for the given
     host, if any, and stop it monitoring if the refcount drops to 0.
     */
    public func stopMonitoring(host: String) {
        objc_sync_enter(monitors)

        guard let monitor = monitors[host] else {
            objc_sync_exit(monitors)
            return
        }

        objc_sync_enter(monitor)
        monitor.refCount -= 1
        let refCount = monitor.refCount
        objc_sync_exit(monitor)
        precondition(refCount >= 0)

        if refCount == 0 {
            monitor.stopMonitoring()
            monitors.removeValueForKey(host)
        }

        objc_sync_exit(monitors)
    }


    /**
     Stop monitoring everything.
     */
    public func stopMonitoringAll() {
        objc_sync_enter(monitors)

        for (_, monitor) in monitors {
            monitor.stopMonitoring()
        }
        monitors.removeAll()

        objc_sync_exit(monitors)
    }


    deinit {
        stopMonitoringAll()
    }
}


/**
 Exponential moving average with irregular intervals.
 http://oroboro.com/irregular-ema/
 */
private func calcEMA(sample sample: Double, prevSample: Double, prevEMA: Double, delta: Double) -> Double {
    let a = delta / EMA_ALPHA
    let u = exp(a * -1)
    let v = (1 - u) / a

    return (u * prevEMA) + ((v - u) * prevSample) + ((1.0 - v) * sample)
}
