//
//  LaneProperties.swift
//  Swim
//
//  Created by Ewan Mellor on 4/11/16.
//
//

import Foundation


public class LaneProperties {
    /**
     Read-only from this client's point of view.

     This means that no command buffer will be created, and any
     attempted writes will fail immediately.

     This does not mean that the lane contents won't change; the server
     may still push changes to us.
     */
    public var isClientReadOnly: Bool = false

    /**
     Whether this lane has no client-side persistent store.
     */
    public var isTransient: Bool = false

    public var prio: Double = 0.0
}
