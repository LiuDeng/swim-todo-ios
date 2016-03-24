//
//  SwimTypes.swift
//  Swim
//
//  Created by Ewan Mellor on 3/18/16.
//
//

import Recon


public typealias SwimUri = Recon.Uri
public typealias SwimValue = Recon.ReconValue


public extension SwimUri {
    /**
     Assuming that this SwimUri is for a node or lane, this is the corresponding SwimUri for the host.
     */
    public var hostUri: SwimUri {
        let hostScheme = (scheme == nil || scheme!.name == "swim" ? "ws" : scheme!)
        return SwimUri(scheme: hostScheme, authority: authority)
    }
}
