//
//  VehicleModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class VehicleModel: SwimModelBase {
    var latitude: Float?
    var longitude: Float?
    var speed: Int?

    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        swimId = json["id"] as? String ?? "MissingID"
        if let latStr = json["latitude"] as? String {
            latitude = Float(latStr)
        }
        if let longStr = json["longitude"] as? String {
            longitude = Float(longStr)
        }
        if let speedStr = json["speed"] as? String {
            speed = Int(speedStr)
        }
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["id"] = swimId
        if latitude != nil {
            json["latitude"] = String(latitude!)
        }
        if longitude != nil {
            json["longitude"] = String(longitude!)
        }
        if speed != nil {
            json["speed"] = String(speed!)
        }
        return json
    }
}
