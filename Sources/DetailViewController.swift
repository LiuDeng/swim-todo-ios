import UIKit
import Recon
import Swim

class DetailViewController: UITableViewController {
  @IBOutlet weak var detailDescriptionLabel: UILabel!

  struct TodoItem {
    let label: String
  }

  var objects = [TodoItem]()

  var roomLink: DownlinkRef? = nil


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
    roomLink = detailItem!.sync(lane: "todo/list")
    roomLink!.keepAlive = true
    roomLink!.event = { message in
      print(message)
      let heading = message.body.first
      switch heading.key?.text {
      case "insert"?:
        break
      case "update"?:
        if let index = heading.value["index"].number {
          if let label = message.body["item"].text {
            if Int(index) >= self.objects.count {
              let indexPath = NSIndexPath(forRow: self.objects.count, inSection: 0)
              self.objects.append(TodoItem(label: label))
              self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            } else {
              self.objects[Int(index)] = TodoItem(label: label)
            }
          }
          let highlight = message.body["highlight"] == Value.True
          print("highlight row \(Int(index)): \(highlight)")
          if let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: Int(index), inSection: 0)) {
            if highlight {
              cell.setHighlighted(true, animated: true)
            } else {
              cell.setHighlighted(false, animated: true)
            }
          }
        }
      case "move"?:
        if let from = heading.value["from"].number, let to = heading.value["to"].number {
          let fromIndex = Int(from)
          let toIndex = Int(to)
          print("label at index \(toIndex): \(self.objects[toIndex].label)")
          print("new item text: \(message.body["item"].text)")
          if self.objects[toIndex].label != message.body["item"].text {
            let object = self.objects.removeAtIndex(fromIndex)
            self.objects.insert(object, atIndex: toIndex)
            self.tableView.beginUpdates()
            self.tableView.moveRowAtIndexPath(NSIndexPath(forRow: fromIndex, inSection: 0),
              toIndexPath: NSIndexPath(forRow: toIndex, inSection: 0))
            self.tableView.endUpdates()
          } else {
            print("ignoring move \(heading.value)")
          }
        }
      case "remove"?:
        if let index = heading.value["index"].number {
          self.objects.removeAtIndex(Int(index))
          self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: Int(index), inSection: 0)], withRowAnimation: .Fade)
        }
      default:
        if let label = message.body["item"].text {
          let index = self.objects.count;
          let item = TodoItem(label: label)
          self.objects.insert(item, atIndex: index)
          let indexPath = NSIndexPath(forRow: index, inSection: 0)
          self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        }
      }
    }
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillAppear(animated)
    if detailItem == nil {
      return
    }

    detailItem!.close()
    detailItem = nil
  }


  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return objects.count
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

    let object = objects[indexPath.row]
    cell.textLabel!.text = object.label
    return cell
  }

  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }

  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      let index = indexPath.row
      detailItem!.command(lane: "todo/list", body: Value(Attr("remove", Value(Slot("index", Value(index))))))
    } else if editingStyle == .Insert {
      // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
  }

  override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
    let fromIndex = fromIndexPath.row
    let toIndex = toIndexPath.row
    print("moving label from index \(fromIndex): \(objects[fromIndex])")
    let object = objects.removeAtIndex(fromIndex)
    objects.insert(object, atIndex: toIndex)
    print("moved label to index \(toIndex): \(objects[toIndex])")
    detailItem!.command(lane: "todo/list", body: Value(Attr("move", Value(Slot("from", Value(fromIndex)), Slot("to", Value(toIndex))))))
  }


  override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    return true
  }

  override func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
    let index = indexPath.row
    let object = objects[index]
    detailItem!.command(lane: "todo/list", body: Value(Attr("update", Value(Slot("index", Value(index)))), Slot("item", Value(object.label)), Slot("highlight", Value.True)))
  }

  override func tableView(tableView: UITableView, didUnhighlightRowAtIndexPath indexPath: NSIndexPath) {
    let index = indexPath.row
    let object = objects[index]
    detailItem!.command(lane: "todo/list", body: Value(Attr("update", Value(Slot("index", Value(index)))), Slot("item", Value(object.label))))
  }

}

