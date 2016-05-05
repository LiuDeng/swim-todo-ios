//
//  SwimGoogleSignIn.swift
//  Swim
//
//  Created by Ewan Mellor on 3/5/16.
//
//

#if SWIMGOOGLESIGNIN

import Bolts
import Google
import ObjectiveC
import Recon
import SwimSwift

private let log = SwimLogging.log


public extension SwimClient {
    public func registerGoogleSignIn(gidSignIn: GIDSignIn) {
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        precondition(configureError == nil, "Error configuring Google services: \(configureError)")

        if gidSignIn.delegate is SwimGoogleSignInDelegate {
            preconditionFailure("Either duplicate call to registerGoogleSignIn, or using multiple SwimClient instances with connectAfterGoogleSignIn.  The former is pointless and the latter is not implemented.")
        }

        let callerDelegate = gidSignIn.delegate
        let ourDelegate = SwimGoogleSignInDelegate()
        gidSignIn.delegate = ourDelegate
        gidSignIn.swimGoogleSignInDelegate = ourDelegate
        ourDelegate.downstreamDelegate = callerDelegate
        ourDelegate.swimClient = self
    }
}


private extension GIDSignIn {
    /**
     This is a duplicate of self.delegate, except this is strongly
     retaining, since this instance needs to own the
     SwimGoogleSignInDelegate.
     */
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
    private weak var downstreamDelegate: GIDSignInDelegate?
    private weak var swimClient: SwimClient?

    // MARK: GIDSignInDelegate

    @objc func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
        guard let swimClient = swimClient else {
            log.warning("Got sign-in response but SwimClient instance has been deallocated.  Doing nothing.")
            return
        }

        if (error == nil) {
            let idToken = user.authentication.idToken
            let credentials = ReconRecord()
            credentials["googleIdToken"] = SwimValue(idToken)
            log.verbose("Signing in as \(user.userID)")
            swimClient.auth(credentials: SwimValue(credentials)).continueWithBlock { [weak self] task in
                self?.completeAuth(signIn, user, task)
                return task
            }
        }
        else {
            log.warning("\(error)")
        }
    }


    private func completeAuth(signIn: GIDSignIn!, _ user: GIDGoogleUser!, _ task: BFTask) {
        if let exn = task.exception {
            log.error("Exception signing in: \(exn)")
            let err = SwimError.Unknown as NSError
            downstreamDelegate?.signIn(signIn, didSignInForUser: user, withError: err)
            return
        }

        let err = task.error
        downstreamDelegate?.signIn(signIn, didSignInForUser: user, withError: err)
    }


    @objc func signIn(signIn: GIDSignIn!, didDisconnectWithUser user:GIDGoogleUser!, withError error: NSError!) {
        log.info("\(error)")
        downstreamDelegate?.signIn?(signIn, didDisconnectWithUser: user, withError: error)
    }
}


#endif
