//
//  RouteModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class RouteModel: SwimModelBase {
    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        swimId = json["route"] as! String
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["route"] = swimId
        return json
    }
}
