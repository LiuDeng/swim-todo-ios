import Google
import SwiftyBeaver
import SwimSwift
import UIKit

let log = SwiftyBeaver.self


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Configure the SwiftyBeaver logging to use the Xcode console.
        // You can optionally add a log level.  Use .Verbose to see every
        // transaction through Swim.  Use .Info or .Warn to reduce the
        // noise.
        //
        // This is optional, and is only making calls into SwiftyBeaver.
        // If you want to configure SwiftyBeaver directly, then you can.
        SwimLoggingSwiftyBeaver.enableConsoleDestination()
//        SwimLoggingSwiftyBeaver.enableConsoleDestination(.Verbose)

        let swim = SwimClient.sharedInstance
        swim.hostUri = SwimUri("ws://todo.swim.services")

        let loginManager = LoginManager()

        let globals = SwimTodoGlobals()
        globals.loginManager = loginManager
        SwimTodoGlobals.instance = globals

        configureSplitVC()

//        if loginManager.isUserSignedIn {
//            loginManager.signInSilently()
            userSignedIn()
//        }
//        else {
//            showLogin()
//        }

        return true
    }

    private func configureSplitVC() {
        let splitVC = window!.rootViewController as! UISplitViewController
        let nav = splitVC.viewControllers.last as! UINavigationController
        nav.topViewController!.navigationItem.leftBarButtonItem = splitVC.displayModeButtonItem()
        splitVC.delegate = self
    }

    private func userSignedIn() {
        if window!.rootViewController is UISplitViewController {
            log.verbose("User signed in already")
        }
        else {
            log.verbose("User signed in, transitioning to main view")

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let mainVC = storyboard.instantiateInitialViewController()!
            window!.fadeToVC(mainVC)
        }
    }

    private func showLogin() {
        window?.rootViewController = LoginViewController()
    }


    /**
     For iOS 9 and above.
     */
    @available(iOS 9.0, *)
    func application(app: UIApplication, openURL url: NSURL, options: [String : AnyObject]) -> Bool {
        let sourceApplication = options[UIApplicationOpenURLOptionsSourceApplicationKey] as! String
        let annotation = options[UIApplicationOpenURLOptionsAnnotationKey]

        // URL handler for Google Sign-in.
        if GIDSignIn.sharedInstance().handleURL(url, sourceApplication: sourceApplication, annotation: annotation) {
            return true
        }

        // Any other URL handlers that your app needs.

        return false
    }

    /**
     For iOS 8 and below.
     */
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {

        // URL handler for Google Sign-in.
        if GIDSignIn.sharedInstance().handleURL(url, sourceApplication: sourceApplication, annotation: annotation) {
            return true
        }

        // Any other URL handlers that your app needs.

        return false
    }


    // MARK: - Split view

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
}


extension UIWindow {
    func fadeToVC(vc: UIViewController) {
        UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseInOut, animations: {
            self.alpha = 0.0
        }, completion: { _ in
            self.rootViewController = vc
            UIView.animateWithDuration(0.3, delay: 0.15, options: .CurveEaseInOut, animations: {
                self.alpha = 1.0
            }, completion: nil)
        })
    }
}
