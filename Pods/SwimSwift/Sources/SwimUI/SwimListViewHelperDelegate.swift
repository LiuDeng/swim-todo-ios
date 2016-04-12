//
//  SwimListViewHelperDelegate.swift
//  Swim
//
//  Created by Ewan Mellor on 4/12/16.
//
//

public protocol SwimListViewHelperDelegate: class {
    var swimObjects: [SwimModelProtocolBase] { get }
    var swimObjectSection: Int { get }
}
