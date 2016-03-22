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
    public static func enableConsoleDestination() {
        let console = ConsoleDestination()
        SwiftyBeaver.self.addDestination(console)
    }

    private let sb: SwiftyBeaver.Type = SwiftyBeaver.self

    public override func verbose(@autoclosure message: () -> Any, _ path: String = __FILE__, _ function: String = __FUNCTION__, line: Int = __LINE__) {
        sb.verbose(message, path, function, line: line)
    }

    public override func debug(@autoclosure message: () -> Any, _ path: String = __FILE__, _ function: String = __FUNCTION__, line: Int = __LINE__) {
        sb.debug(message, path, function, line: line)
    }

    public override func info(@autoclosure message: () -> Any, _ path: String = __FILE__, _ function: String = __FUNCTION__, line: Int = __LINE__) {
        sb.info(message, path, function, line: line)
    }

    public override func warning(@autoclosure message: () -> Any, _ path: String = __FILE__, _ function: String = __FUNCTION__, line: Int = __LINE__) {
        sb.warning(message, path, function, line: line)
    }

    public override func error(@autoclosure message: () -> Any, _ path: String = __FILE__, _ function: String = __FUNCTION__, line: Int = __LINE__) {
        sb.error(message, path, function, line: line)
    }

    public override func flush(secondTimeout: Int64) -> Bool {
        return sb.flush(secondTimeout) ?? true
    }
}


#endif
