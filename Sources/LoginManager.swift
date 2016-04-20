//
//  LoginManager.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/22/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Google
import SwimSwift


class LoginManager {
    init() {
        // Register Google's GIDSignIn with SwimClient.
        // This will register as GIDSignIn's delegate, and handle all of
        // Google's sign-in events from then on.
//        let gidSignIn = GIDSignIn.sharedInstance()
//        let swimClient = SwimClient.sharedInstance
//        swimClient.registerGoogleSignIn(gidSignIn)
    }

    /**
     - returns: true if the user is signed into the app.  This includes the
                case where the user signed into the app last time, and now
                we need to refresh their token with their auth provider.
     */
    var isUserSignedIn: Bool {
        // Use GIDSignIn to tell us whether the user is signed in.
        // If you have more than one auth provider, you will need to check
        // them all here, or maintain your own user identity details.
//        let gidSignIn = GIDSignIn.sharedInstance()
//        return (gidSignIn.currentUser != nil)
        return true
    }

    /**
     Refresh user's token with their auth provider, and send it to the
     Swim service.
     */
    func signInSilently() {
        // Use GIDSignIn to refresh the token with Google.
        // SwimClient will then send the new token to the Swim service,
        // since we registered as the GIDSignInDelegate above.
        //
        // If you have more than one auth provider, you will need to
        // refresh the correct one here, of course.
//        let gidSignIn = GIDSignIn.sharedInstance()
//        gidSignIn.signInSilently()
    }
}
