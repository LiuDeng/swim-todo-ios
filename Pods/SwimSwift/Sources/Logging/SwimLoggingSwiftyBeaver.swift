//
//  SwimLoggingSwiftyBeaver.swift
//  Swim
//
//  Created by Ewan Mellor on 3/18/16.
//
//

#if SWIMLOGGINGSWIFTYBEAVER

import Foundation
import SwiftyBeaver


public class SwimLoggingSwiftyBeaver: SwimLogging {
    public static func enableConsoleDestination(minLevel: SwiftyBeaver.Level = .Debug) {
        let console = ConsoleDestination()
        console.minLevel = minLevel
        SwiftyBeaver.self.addDestination(console)
    }

    private let sb: SwiftyBeaver.Type = SwiftyBeaver.self

    public override func verbose(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        sb.verbose(message, path, function, line: line)
    }

    public override func debug(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        sb.debug(message, path, function, line: line)
    }

    public override func info(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        sb.info(message, path, function, line: line)
    }

    public override func warning(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        sb.warning(message, path, function, line: line)
    }

    public override func error(@autoclosure message: () -> Any, _ path: String = #file, _ function: String = #function, line: Int = #line) {
        sb.error(message, path, function, line: line)
    }

    public override func flush(secondTimeout: Int64) -> Bool {
        return sb.flush(secondTimeout) ?? true
    }
}


#endif
