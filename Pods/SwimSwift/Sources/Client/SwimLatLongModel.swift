//
//  SwimLatLongModel.swift
//  Swim
//
//  Created by Ewan Mellor on 5/14/16.
//
//

import Foundation


/**
 A simple extension to SwimModelBase that adds latitude and longitude
 fields.

 This class handles the case where these fields are on the wire in either
 string or float forms.
 */
public class SwimLatLongModel: SwimModelBase {
    public var latitude: Float?
    public var longitude: Float?

    private var wireIsString: Bool = false


    public override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        if let latStr = json["latitude"] as? String {
            latitude = Float(latStr)
            wireIsString = true
        }
        else if let lat = json["latitude"] as? NSNumber {
            latitude = lat.floatValue
            wireIsString = false
        }
        if let longStr = json["longitude"] as? String {
            longitude = Float(longStr)
            wireIsString = true
        }
        else if let longit = json["longitude"] as? NSNumber {
            longitude = longit.floatValue
            wireIsString = false
        }
    }


    public override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        if latitude != nil {
            json["latitude"] = (wireIsString ? String(latitude!) : latitude!)
        }
        if longitude != nil {
            json["longitude"] = (wireIsString ? String(longitude!) : longitude!)
        }
        return json
    }
}
