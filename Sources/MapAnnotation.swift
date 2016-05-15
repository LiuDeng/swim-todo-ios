//
//  MapAnnotation.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/14/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift
import UIKit


class MapAnnotation: NSObject, MKAnnotation {
    var thing: SwimLatLongModel

    // Note that this is a cache of thing.coordinate rather than a
    // direct call, because we only want to change this when we're ready
    // to animate a batch of changes.
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        if let vehicle = thing as? VehicleModel {
            return vehicle.routeId
        }
        else if let atm = thing as? ATMModel {
            return atm.name
        }
        else {
            return nil
        }
    }

    var subtitle: String? {
        if let vehicle = thing as? VehicleModel {
            if let speed = vehicle.speedMph {
                return "\(speed) mph"
            }
            else {
                return "Stationary"
            }
        }
        else if let atm = thing as? ATMModel {
            return atm.address
        }
        else {
            return nil
        }
    }

    init(thing: SwimLatLongModel) {
        self.thing = thing
        coordinate = thing.coordinate
    }
}


