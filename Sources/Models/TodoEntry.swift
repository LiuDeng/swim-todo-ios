//
//  TodoEntry.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Recon

class TodoEntry : SwimModel {
    var name : String? = nil
    var notes : String? = nil
    var deadline : NSDate? = nil
    var reminder : NSDate? = nil
    var image : NSData? = nil
    var activity : [String : NSDate] = [:]
    var assignees : [String] = []
    var highlighters : [String] = []

    required init?(reconValue: ReconValue) {
        name = reconValue.text
        super.init(reconValue: reconValue)
    }

    required init() {
        super.init()
    }

    override func toReconValue() -> ReconValue {
        return Value(name ?? "")
    }
}
