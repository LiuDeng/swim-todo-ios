//
//  SwimTodoGlobals.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/22/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import SwimSwift


class SwimTodoGlobals {
    static var instance: SwimTodoGlobals!

    var loginManager: LoginManager!

    var cityClient: SwimClient!
    var todoClient: SwimClient!
}
