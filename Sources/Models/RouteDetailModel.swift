//
//  RouteDetailModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/28/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Recon
import SwiftyBeaver
import SwimSwift


private let log = SwiftyBeaver.self


class RouteDetailModel: SwimModelBase {
    var stops = [RouteStopModel]()
    var latMin: Float?
    var latMax: Float?
    var lonMin: Float?
    var lonMax: Float?


    override func swim_updateWithSwimValue(swimValue: SwimValue) {
        var val = swimValue
        guard let route = val.popFirst() where route.key == "route",
              let routeDetails = route.value.record else {
            log.warning("Discarding invalid route detail \(val)")
            return
        }
        latMin = routeDetails["latMin"].floatFromText
        latMax = routeDetails["latMax"].floatFromText
        lonMin = routeDetails["lonMin"].floatFromText
        lonMax = routeDetails["lonMax"].floatFromText

        while let stop = val.popFirst() {
            guard stop.key == "stop" else {
                log.warning("Skipping invalid route stop \(stop)")
                continue
            }

            guard let stopModel = RouteStopModel(swimValue: stop.value) else {
                log.warning("Skipping unparseable route stop \(stop)")
                continue
            }

            stops.append(stopModel)
        }
    }


    override func swim_toSwimValue() -> SwimValue {
        preconditionFailure("Unimplemented")
    }
}


extension SwimValue {
    var floatFromText: Float? {
        return (text == nil ? nil : Float(text!))
    }
}
