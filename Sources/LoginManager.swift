//
//  LoginManager.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/22/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import Foundation
import Google
import JLToast
import SwimSwift
import SwiftyBeaver


private let log = SwiftyBeaver.self


class LoginManager {
    static let UserSignedInNotification = "UserSignedInNotification"
    static let UserSignedOutNotification = "UserSignedOutNotification"

    private let gidDelegate = GIDDelegate()

    init() {
        // Register gidDelegate and SwimClient with Google's GIDSignIn.
        // SwimClient will handle all of Google's sign-in events initially,
        // and pass them on to gidDelegate as appropriate.
        let gidSignIn = GIDSignIn.sharedInstance()
        gidSignIn.delegate = gidDelegate
        let swimClient = SwimClient.sharedInstance
        swimClient.registerGoogleSignIn(gidSignIn)
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
        let gidSignIn = GIDSignIn.sharedInstance()
        return (gidSignIn.currentUser != nil)
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
        let gidSignIn = GIDSignIn.sharedInstance()
        gidSignIn.signInSilently()
    }
}


@objc private class GIDDelegate: NSObject, GIDSignInDelegate {

    // MARK: - GIDSignInDelegate

    @objc func signIn(_: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        let nc = NSNotificationCenter.defaultCenter()
        if let err = error {
            log.warning("Failed to sign in: \(err)")
            nc.postNotificationName(LoginManager.UserSignedOutNotification, object: nil)
            let toast = JLToast.makeText("Failed to sign in")
            toast.show()
        }
        else {
            log.verbose("Signed in as \(user.userID)")
            nc.postNotificationName(LoginManager.UserSignedInNotification, object: nil)
        }
    }

    @objc func signIn(_: GIDSignIn!, didDisconnectWithUser user: GIDGoogleUser!, withError error: NSError!) {
        log.warning("User \(user.userID) deauthorized: \(error ?? "")")
        let nc = NSNotificationCenter.defaultCenter()
        nc.postNotificationName(LoginManager.UserSignedOutNotification, object: nil)
    }
}
