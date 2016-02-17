import UIKit
import Recon
import Swim

class DetailViewController: SwimTableViewController {
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
    var downlink = detailItem!.syncList(lane: "todo/list")
    downlink.keepAlive = true
    setDownlink(downlink, forSection: 0)
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillAppear(animated)
    if detailItem == nil {
      return
    }

    closeDownlinks()
  }

  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

    let value = downlinkForSection(indexPath.section)![indexPath.row]
    cell.textLabel!.text = value["item"].text
    return cell
  }

  override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    return true
  }

  override func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
    if var downlink = downlinkForSection(indexPath.section), var record = downlink[indexPath.row].record {
      record["highlight"] = Value.True
      downlink[indexPath.row] = Value(record)
    }
  }

  override func tableView(tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
    if var downlink = downlinkForSection(indexPath.section), var record = downlink[indexPath.row].record {
      record.removeValueForKey("highlight")
      downlink[indexPath.row] = Value(record)
    }
  }

  override func downlink(downlink: ListDownlink, didUpdate value: Value, atIndex index: Int) {
    if let section = sectionForDownlink(downlink) {
      let indexPath = NSIndexPath(forRow: index, inSection: section)
      if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
        if value["highlight"] == Value.True {
          cell.setHighlighted(true, animated: true)
        } else {
          cell.setHighlighted(false, animated: true)
        }
      }
    }
  }

}
