//
//  ValueDownlink.swift
//  Swim
//
//  Created by Ewan Mellor on 5/14/16.
//
//

import Foundation


/**
 A `ValueDownlink` remotely synchronizes a single object.

 Only support for read-only, non-persistent value lanes has been
 implemented.
 */
public protocol ValueDownlink: Downlink {
    var object: SwimModelProtocolBase? { get }
}


public protocol ValueDownlinkDelegate: DownlinkDelegate {
    func swimValueDownlink(downlink: ValueDownlink, didUpdate object: SwimModelProtocolBase)
}

public extension ListDownlinkDelegate {
    func swimValueDownlink(downlink: ValueDownlink, didUpdate object: SwimModelProtocolBase) {}
}
