//
//  AgencyModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class AgencyModel: SwimModelBase {
    var name: String? = nil


    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        swimId = json["agency"] as! String
        name = swimId
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["agency"] = swimId
        if name != nil {
            json["name"] = name
        }
        return json
    }
}
