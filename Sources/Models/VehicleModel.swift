//
//  VehicleModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


extension SwimLatLongModel {
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude ?? 0.0),
                                      longitude: CLLocationDegrees(longitude ?? 0.0))
    }
}


class VehicleModel: SwimLatLongModel {
    var agencyId: String?
    var dirId: String?
    var routeId: String?
    var onRoute: Bool?
    var secsSinceReport: Int?
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
        agencyId = json["agencyId"] as? String
        dirId = json["dirId"] as? String
        routeId = json["routeId"] as? String
        onRoute = (json["onRoute"] as? String) == "true"
        if let secsStr = json["secsSinceReport"] as? String {
            secsSinceReport = Int(secsStr)
        }
        if let speedStr = json["speed"] as? String {
            speedKph = Int(speedStr)
        }
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        json["id"] = swimId
        if agencyId != nil {
            json["agencyId"] = agencyId!
        }
        if dirId != nil {
            json["dirId"] = dirId!
        }
        if routeId != nil {
            json["routeId"] = routeId!
        }
        json["onRoute"] = (onRoute ?? true ? "true" : "false")
        if secsSinceReport != nil {
            json["secsSinceReport"] = String(secsSinceReport!)
        }
        if speedKph != nil {
            json["speed"] = String(speedKph!)
        }
        return json
    }
}
