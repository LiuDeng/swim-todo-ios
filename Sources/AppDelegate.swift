import Crashlytics
import Fabric
import Google
import SwiftyBeaver
import SwimSwift
import UIKit


private let SWIM_USE_LOCALHOST = false


private let log = SwiftyBeaver.self
private let SwimCityHost = (SWIM_USE_LOCALHOST ? "localhost:9050" : "city.swim.services")
private let SwimTodoHost = (SWIM_USE_LOCALHOST ? "localhost:5619" : "todo.swim.services")
private let SwimCityHostURI = SwimUri("ws://\(SwimCityHost)")
private let SwimTodoHostURI = SwimUri("ws://\(SwimTodoHost)")


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        startCrashlytics()

        // Configure the SwiftyBeaver logging to use the Xcode console.
        // You can optionally add a log level.  Use .Verbose to see every
        // transaction through Swim.  Use .Info or .Warn to reduce the
        // noise.
        //
        // This is optional, and is only making calls into SwiftyBeaver.
        // If you want to configure SwiftyBeaver directly, then you can.
        SwimLoggingSwiftyBeaver.enableConsoleDestination()
//        SwimLoggingSwiftyBeaver.enableConsoleDestination(.Verbose)

        // Configure Swim to connect to the hosts specified above.
        //
        // If your app connects to just one Swim service, you can use
        // SwimClient.sharedInstance.hostUri = myServerURI.
        // In this case, we are connecting to multiple servers, so we
        // use separate SwimClient instances.
        let cityClient = SwimClient(host: SwimCityHostURI, protocols: [])
        let todoClient = SwimClient(host: SwimTodoHostURI, protocols: [])

        let loginManager = LoginManager()

        let globals = SwimTodoGlobals()
        globals.loginManager = loginManager
        globals.cityClient = cityClient
        globals.todoClient = todoClient
        SwimTodoGlobals.instance = globals

        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(AppDelegate.userSignedIn), name: LoginManager.UserSignedInNotification, object: nil)
        nc.addObserver(self, selector: #selector(AppDelegate.userSignedOut), name: LoginManager.UserSignedOutNotification, object: nil)

        if loginManager.isUserSignedIn {
            loginManager.signInSilently()
            userSignedIn()
        }
        else {
            showLogin()
        }

        return true
    }

    private func startCrashlytics() {
        Fabric.with([Crashlytics.self])
    }

    @objc func userSignedIn() {
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

    @objc func userSignedOut() {
        showLogin()
    }

    private func showLogin() {
        window?.rootViewController = LoginViewController()
    }


    func applicationDidBecomeActive(application: UIApplication) {
        // This is required so that Swim can manage the offline sync.
        SwimClient.applicationDidBecomeActive()
    }


    func applicationWillResignActive(application: UIApplication) {
        // This is required so that Swim can manage the offline sync.
        SwimClient.applicationWillResignActive()
    }


    func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        // This is required so that Swim can manage the background sync.
        SwimClient.applicationPerformFetchWithCompletionHandler(completionHandler)
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
