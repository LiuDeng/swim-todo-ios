//
//  TodoEntry.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/15/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import SwimSwift

class TodoEntry : SwimModelBase {
    var name : String? = nil
    var notes : String? = nil
    var deadline : NSDate? = nil
    var reminder : NSDate? = nil
    var image : NSData? = nil
    var activity : [String : NSDate] = [:]
    var assignees : [String] = []
    var highlighters : [String] = []

    required init?(swimValue: SwimValue) {
        name = swimValue.text
        super.init(swimValue: swimValue)
    }

    required init() {
        super.init()
    }

    override func swim_toSwimValue() -> SwimValue {
        return SwimValue(name ?? "")
    }
}
