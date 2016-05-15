//
//  VehicleModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class LocatableModel: SwimModelBase {
    var latitude: Float?
    var longitude: Float?

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude ?? 0.0),
                                      longitude: CLLocationDegrees(longitude ?? 0.0))
    }

    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        if let latStr = json["latitude"] as? String {
            latitude = Float(latStr)
        }
        else if let lat = json["latitude"] as? NSNumber {
            latitude = lat.floatValue
        }
        if let longStr = json["longitude"] as? String {
            longitude = Float(longStr)
        }
        else if let longit = json["longitude"] as? NSNumber {
            longitude = longit.floatValue
        }
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        if latitude != nil {
            json["latitude"] = String(latitude!)
        }
        if longitude != nil {
            json["longitude"] = String(longitude!)
        }
        return json
    }
}


class VehicleModel: LocatableModel {
    var routeId: String?
    var speedKph: Int?

    var speedMph: Int? {
        if let speedKph = speedKph {
            return Int(Float(speedKph) * 0.621371)
        }
        else {
            return nil
        }
    }

    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        swimId = json["id"] as? String ?? "MissingID"
        routeId = json["routeId"] as? String
        if let speedStr = json["speed"] as? String {
            speedKph = Int(speedStr)
        }
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["id"] = swimId
        json["routeId"] = routeId
        if speedKph != nil {
            json["speed"] = String(speedKph!)
        }
        return json
    }
}
