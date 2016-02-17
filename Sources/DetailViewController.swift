import UIKit
import Recon
import Swim

class DetailViewController: SwimUITableViewController {
  @IBOutlet weak var detailDescriptionLabel: UILabel!

  var detailItem: NodeScope? {
    didSet {
      // Update the view.
      self.configureView()
    }
  }

  func configureView() {
    // Update the user interface for the detail item.
    if let detail = self.detailItem {
      if let label = self.detailDescriptionLabel {
        label.text = detail.nodeUri.path.description
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.rightBarButtonItem = self.editButtonItem()
    self.configureView()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    if detailItem == nil {
      return
    }
    downlink = detailItem!.syncList(lane: "todo/list")
    downlink!.keepAlive = true
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillAppear(animated)
    if detailItem == nil {
      return
    }

    detailItem!.close()
    detailItem = nil
  }

  override func downlinkDidUpdate(value: Value, atIndex index: Int) {
    let indexPath = NSIndexPath(forRow: index, inSection: downlinkSection)
    if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
      if value["highlight"] == Value.True {
        cell.setHighlighted(true, animated: true)
      } else {
        cell.setHighlighted(false, animated: true)
      }
    }
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

    let value = downlink![indexPath.row]
    cell.textLabel!.text = value["item"].text
    return cell
  }

  override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    return true
  }

  override func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
    if var record = downlink?[indexPath.row].record {
      record["highlight"] = Value.True
      downlink?[indexPath.row] = Value(record)
    }
  }

  override func tableView(tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
    if var record = downlink?[indexPath.row].record {
      record.removeValueForKey("highlight")
      downlink?[indexPath.row] = Value(record)
    }
  }

}
