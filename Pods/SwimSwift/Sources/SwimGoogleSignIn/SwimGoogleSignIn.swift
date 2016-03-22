//
//  SwimGoogleSignIn.swift
//  Swim
//
//  Created by Ewan Mellor on 3/5/16.
//
//

#if SWIMGOOGLESIGNIN

import Google
import ObjectiveC
import Recon


public extension SwimClient {
    public func connectAfterGoogleSignIn(gidSignIn: GIDSignIn, host: String) {
        connectAfterGoogleSignIn(gidSignIn, hostUri: Uri(stringLiteral: host))
    }

    public func connectAfterGoogleSignIn(gidSignIn: GIDSignIn, hostUri: Uri) {
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(configureError)")

        swimGoogleSignInDelegate = SwimGoogleSignInDelegate(self, hostUri)
        gidSignIn.delegate = swimGoogleSignInDelegate
    }

    private var swimGoogleSignInDelegate: SwimGoogleSignInDelegate? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.swimGoogleSignInDelegate) as? SwimGoogleSignInDelegate
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.swimGoogleSignInDelegate, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private struct AssociatedKeys {
        static var swimGoogleSignInDelegate = "swimGoogleSignInDelegate"
    }
}


private class SwimGoogleSignInDelegate: NSObject, GIDSignInDelegate {
    private weak var swimClient: SwimClient?
    private let hostUri: Uri

    init(_ swimClient: SwimClient, _ hostUri: Uri) {
        self.swimClient = swimClient
        self.hostUri = hostUri
        super.init()
    }


    // MARK: GIDSignInDelegate

    @objc func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        if (error == nil) {
            let idToken = user.authentication.idToken
            var credentials = ReconRecord()
            credentials["googleIdToken"] = Value(idToken)
            NSLog("Signing in as \(user.userID)")
            swimClient?.auth(host: hostUri, credentials: Value(credentials))
        }
        else {
            NSLog("\(error)")
        }
    }

    @objc func signIn(signIn: GIDSignIn!, didDisconnectWithUser user:GIDGoogleUser!, withError error: NSError!) {
        NSLog("\(error)")
    }
}

#endif
