import SwimSwift
import UIKit


class MasterViewController: UITableViewController {
    var objects = [NodeScope]()


    override func viewDidLoad() {
        super.viewDidLoad()

        let swim = SwimTodoGlobals.instance.todoClient
        let groceryList = swim.scope(node: "/todo/grocery")
        let elementsList = swim.scope(node: "/todo/elements")
        objects = [groceryList, elementsList]
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.navigationBarHidden = false
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
            return 2

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
            switch indexPath.row {
            case 0:
                cell.textLabel!.text = "Map"

            case 1:
                cell.textLabel!.text = "Guru mode"

            default:
                preconditionFailure()
            }

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

        switch indexPath.section {
        case 0:
            let vc = TodoListViewController()
            vc.detailItem = objects[indexPath.row]
            navigationController?.pushViewController(vc, animated: true)

        case 1:
            switch indexPath.row {
            case 0:
                let vc = MapViewController()
                navigationController?.pushViewController(vc, animated: true)

            case 1:
                let vc = GuruModeViewController()
                let todoHostUri = SwimTodoGlobals.instance.todoClient.hostUri
                vc.knownLanes = objects.map { todoHostUri.resolve(SwimUri("\($0.nodeUri)/todo/list")!) }
                navigationController?.pushViewController(vc, animated: true)

            default:
                preconditionFailure()
            }

        default:
            preconditionFailure()
        }
    }
}
