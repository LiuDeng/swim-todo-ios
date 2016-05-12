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
    var speedKph: Int?

    var speedMph: Int? {
        if let speedKph = speedKph {
            return Int(Float(speedKph) * 0.621371)
        }
        else {
            return nil
        }
    }

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude ?? 0.0),
                                      longitude: CLLocationDegrees(longitude ?? 0.0))
    }


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
            speedKph = Int(speedStr)
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
        if speedKph != nil {
            json["speed"] = String(speedKph!)
        }
        return json
    }
}
