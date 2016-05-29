//
//  RouteStopModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/28/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import SwimSwift


class RouteStopModel: SwimLatLongModel {
    var tag: String?
    var title: String?


    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        swimId = json["stopId"] as? String ?? ""
        tag = json["tag"] as? String
        title = json["title"] as? String
        if let latStr = json["lat"] as? String {
            latitude = Float(latStr)
        }
        if let longStr = json["long"] as? String {
            longitude = Float(longStr)
        }
    }


    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        if tag != nil {
            json["tag"] = tag!
        }
        if title != nil {
            json["title"] = title!
        }
        return json
    }
}
