import SwimSwift
import UIKit


class MasterViewController: UITableViewController, UISplitViewControllerDelegate {
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
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return objects.count

        case 1:
            return 1

        default:
            preconditionFailure()
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        switch indexPath.section {
        case 0:
            let object = objects[indexPath.row]
            cell.textLabel!.text = object.nodeUri.path.description

        case 1:
            cell.textLabel!.text = "Guru mode"

        default:
            preconditionFailure()
        }
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let indexPath = tableView.indexPathForSelectedRow!
        let splitVC = splitViewController!

        switch indexPath.section {
        case 0:
            let object = objects[indexPath.row]

            let listVC = TodoListViewController()
            listVC.detailItem = object
            listVC.navigationItem.leftBarButtonItem = splitVC.displayModeButtonItem()
            listVC.navigationItem.leftItemsSupplementBackButton = true

            let listNav = UINavigationController(rootViewController: listVC)
            splitVC.showDetailViewController(listNav, sender: self)

        case 1:
            let vc = GuruModeViewController()
            vc.navigationItem.leftBarButtonItem = splitVC.displayModeButtonItem()
            vc.navigationItem.leftItemsSupplementBackButton = true

            let nav = UINavigationController(rootViewController: vc)
            splitVC.showDetailViewController(nav, sender: self)

        default:
            preconditionFailure()
        }
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
