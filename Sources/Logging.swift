//
//  Logging.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/16/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation

let DEBUG_LOGGING = true

func DLog(@autoclosure msgClosure: () -> String?) {
    if DEBUG_LOGGING {
        guard let msg = msgClosure() else {
            return
        }
        NSLog("%@ %@", NSDate(), msg)
    }
}
