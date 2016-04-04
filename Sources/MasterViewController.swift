import SwimSwift
import UIKit


class MasterViewController: UITableViewController, UISplitViewControllerDelegate {
    var todo: HostScope! = nil

    var objects = [NodeScope]()


    override func viewDidLoad() {
        super.viewDidLoad()

        let swim = SwimClient.sharedInstance
        let groceryList = swim.scope(node: "/todo/grocery")
        let elementsList = swim.scope(node: "/todo/elements")
        objects = [groceryList, elementsList]

        guard let splitVC = splitViewController else {
            return
        }
        splitVC.delegate = self
        navigationItem.leftBarButtonItem = splitVC.displayModeButtonItem()
    }

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
    }


    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        let object = objects[indexPath.row]
        cell.textLabel!.text = object.nodeUri.path.description
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let indexPath = tableView.indexPathForSelectedRow!
        let object = objects[indexPath.row]

        let splitVC = splitViewController!
        let listVC = TodoListViewController()
        listVC.detailItem = object
        listVC.navigationItem.leftBarButtonItem = splitVC.displayModeButtonItem()
        listVC.navigationItem.leftItemsSupplementBackButton = true

        let listNav = UINavigationController(rootViewController: listVC)
        splitVC.showDetailViewController(listNav, sender: self)
    }


    // MARK: - UISplitViewControllerDelegate

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        let detailNav = secondaryViewController as! UINavigationController
        guard let listVC = detailNav.topViewController as? TodoListViewController else {
            return false
        }
        if listVC.detailItem == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }

    func splitViewController(splitViewController: UISplitViewController, separateSecondaryViewControllerFromPrimaryViewController primaryViewController: UIViewController) -> UIViewController? {
        let masterNav = primaryViewController as! UINavigationController
        let detailVC = masterNav.topViewController!
        masterNav.popViewControllerAnimated(false)
        return detailVC
    }
}
