//
//  CollectionType+Misc.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 2/16/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation

extension CollectionType {
    func find(@noescape predicate: (Self.Generator.Element) throws -> Bool) rethrows -> Self.Generator.Element? {
        return try indexOf(predicate).map({self[$0]})
    }
}
