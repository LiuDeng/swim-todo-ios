//
//  BankModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/12/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class BankModel: SwimModelBase {
    var name: String? = nil


    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        swimId = json["bank"] as! String
        name = json["name"] as? String
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["bank"] = swimId
        if name != nil {
            json["name"] = name
        }
        return json
    }
}
