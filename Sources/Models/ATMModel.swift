//
//  ATMModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/12/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class ATMModel: SwimLatLongModel {
    var name: String? = nil
    var address: String? = nil

    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        if let atm = json["atm"] as? String {
            swimId = atm
        }
        name = json["name"] as? String
        address = json["address"] as? String
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["atm"] = swimId
        if name != nil {
            json["name"] = name
        }
        if address != nil {
            json["address"] = address
        }
        return json
    }
}
