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
    var status: String? = nil

    var completed: Bool {
        get {
            return (status == "completed")
        }
        set {
            status = (newValue ? "completed" : "open")
        }
    }

    required init?(swimValue: SwimValue) {
        super.init(swimValue: swimValue)
        swim_updateWithSwimValue(swimValue)
    }

    required init() {
        super.init()
    }

    override func swim_updateWithSwimValue(swimValue: SwimValue) {
        guard let json = swimValue.json as? [String: AnyObject] else {
            if let n = swimValue.text {
                name = n
                return
            }
            else {
                return
            }
        }

        name = json["name"] as? String
        status = json["status"] as? String
    }

    override func swim_toSwimValue() -> SwimValue {
        var json = [String: AnyObject]()
        if name != nil {
            json["name"] = name
        }
        if status != nil {
            json["status"] = status
        }
        return SwimValue(json: json)
    }
}
