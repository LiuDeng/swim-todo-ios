//
//  SwimLogging.swift
//  Pods
//
//  Created by Ewan Mellor on 3/17/16.
//
//

import Foundation


public class SwimLogging {
#if SWIMLOGGINGSWIFTYBEAVER
    public static let log = SwimLoggingSwiftyBeaver()
#else
    public static let log = SwimLogging()
#endif

    public func verbose(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
    }

    public func debug(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
    }

    public func info(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        NSLog("\(message())")
    }

    public func warning(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        NSLog("\(message())")
    }

    public func error(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        NSLog("\(message())")
    }

    public func flush(secondTimeout: Int64) -> Bool {
        return true
    }
}
