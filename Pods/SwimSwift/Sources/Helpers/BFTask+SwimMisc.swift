//
//  BFTask+SwimMisc.swift
//  Swim
//
//  Created by Ewan Mellor on 4/20/16.
//
//

import Bolts
import Foundation


extension BFTask {
    convenience init(swimError: SwimError) {
        self.init(error: swimError as NSError)
    }
}
