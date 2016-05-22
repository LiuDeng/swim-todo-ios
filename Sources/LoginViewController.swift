//
//  LoginViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/22/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import GoogleSignIn
import UIKit

class LoginViewController: UIViewController, GIDSignInUIDelegate {
    @IBOutlet private weak var signInButton: GIDSignInButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        let gidSignIn = GIDSignIn.sharedInstance()
        gidSignIn.uiDelegate = self

        // Wait for a button tap.
        // Everything will be handled by GIDSignInButton and GIDSignIn.
    }
}
