//
//  SwimError.swift
//  Swim
//
//  Created by Ewan Mellor on 4/20/16.
//
//

import Foundation


public let SwimErrorDomain = "SwimSwift.SwimError"


public enum SwimError: Int, ErrorType {
    case Unknown = 0
    case DownlinkIsClientReadOnly = 1
    case NodeNotFound = 2
    case LaneNotFound = 3
    case NetworkError = 4
}
