import UIKit
import Recon
import Swim

let LANE_URI: Uri = "todo/list"


public class TodoItem: SwimModel {
    var label: String = ""

    required public init() {
        super.init()
    }

    required public init?(reconValue: ReconValue) {
        super.init(reconValue: reconValue)
        update(reconValue)
    }

    override public func toReconValue() -> ReconValue {
        return Value(label)
    }

    override public func update(reconValue: ReconValue) {
        label = reconValue.text ?? ""
    }
}

class DetailViewController: SwimListTableViewController {
    @IBOutlet weak var detailDescriptionLabel: UILabel!

    var detailItem : NodeScope? {
        get {
            return listManager.nodeScope
        }
        set {
            listManager.nodeScope = newValue
        }
    }

    required init?(coder aDecoder: NSCoder) {
        let listManager = SwimListManager<TodoItem>(laneUri: LANE_URI)
        super.init(listManager: listManager, coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = editButtonItem()

        configureView()
    }

    override func swimDidStartSynching() {
        configureView()
    }

    func configureView() {
        detailDescriptionLabel?.text = detailItem?.nodeUri.path.description ?? ""
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        let object = objects[indexPath.row] as! TodoItem
        cell.textLabel!.text = object.label
        return cell
    }
}
