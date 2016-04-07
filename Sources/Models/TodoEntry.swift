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

    // Backwards compat for when we were only persisting the name
    // of the entry.  This can be removed soon.
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

        swim_updateWithJSON(json)
    }

    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        name = json["name"] as? String
        status = json["status"] as? String
    }

    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        if name != nil {
            json["name"] = name
        }
        if status != nil {
            json["status"] = status
        }
        return json
    }
}
