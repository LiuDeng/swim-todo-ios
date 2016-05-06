//
//  UserPresenceModel.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 4/12/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import SwimSwift


class UserPresenceModel : SwimModelBase {
    var email: String? = nil
    var name: String? = nil

    var initials: String? {
        guard let name = name else {
            return initialsFromEmail
        }
        let parts = name.componentsSeparatedByString(" ")
        if parts.count == 0 {
            return nil
        }
        else if parts.count == 1 {
            return parts[0].firstChar
        }
        else {
            return "\(parts[parts.count - 2].firstChar)\(parts.last!.firstChar)"
        }
    }

    private var initialsFromEmail: String? {
        guard let email = email where email != "" else {
            return nil
        }
        return email.firstChar
    }

    override func swim_updateWithJSON(json: [String: AnyObject]) {
        super.swim_updateWithJSON(json)

        email = json["email"] as? String
        name = json["name"] as? String
    }

    override func swim_toJSON() -> [String: AnyObject] {
        var json = super.swim_toJSON()
        if email != nil {
            json["email"] = email
        }
        if name != nil {
            json["name"] = name
        }
        return json
    }
}


private extension String {
    var firstChar: String {
        return substringToIndex(startIndex.successor())
    }
}
