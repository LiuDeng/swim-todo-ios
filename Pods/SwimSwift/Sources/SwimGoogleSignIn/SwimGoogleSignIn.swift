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

private let log = SwimLogging.log


public extension SwimClient {
    public func registerGoogleSignIn(gidSignIn: GIDSignIn) {
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        precondition(configureError == nil, "Error configuring Google services: \(configureError)")

        var delegate: SwimGoogleSignInDelegate
        if gidSignIn.swimGoogleSignInDelegate == nil {
            delegate = SwimGoogleSignInDelegate()
            gidSignIn.swimGoogleSignInDelegate = delegate
            gidSignIn.delegate = delegate
        }
        else {
            precondition(gidSignIn.delegate is SwimGoogleSignInDelegate,
                ("connectAfterGoogleSignIn needs GIDSignIn.delegate for itself. " +
                    "You cannot set GIDSignIn.delegate and use connectAfterGoogleSignIn"))
            preconditionFailure("Using multiple SwimClient instances with connectAfterGoogleSignIn is not implemented")
        }
        delegate.swimClient = self
    }
}


private extension GIDSignIn {
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

    // MARK: GIDSignInDelegate

    @objc func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        guard let swimClient = swimClient else {
            log.warning("Got sign-in response but SwimClient instance has been deallocated.  Doing nothing.")
            return
        }

        if (error == nil) {
            let idToken = user.authentication.idToken
            var credentials = ReconRecord()
            credentials["googleIdToken"] = SwimValue(idToken)
            log.verbose("Signing in as \(user.userID)")
            swimClient.auth(credentials: SwimValue(credentials))
        }
        else {
            log.warning("\(error)")
        }
    }

    @objc func signIn(signIn: GIDSignIn!, didDisconnectWithUser user:GIDGoogleUser!, withError error: NSError!) {
        log.info("\(error)")
    }
}

#endif
