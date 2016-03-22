import UIKit
import Recon

public class SwimTableViewController: UITableViewController, ListDownlinkDelegate {
  private var downlinks: [Int: ListDownlink] = [Int: ListDownlink]()

  public func downlinkForSection(section: Int) -> ListDownlink? {
    return downlinks[section]
  }

  public func sectionForDownlink(downlink: ListDownlink) -> Int? {
    for case (let section, let link) in downlinks {
      if downlink.nodeUri == link.nodeUri && downlink.laneUri == link.laneUri {
        return section
      }
    }
    return nil
  }

  public func setDownlink(downlink: ListDownlink?, forSection section: Int) -> ListDownlink? {
    if var link = downlink {
      let oldLink = downlinks.updateValue(link, forKey: section)
      link.delegate = self
      return oldLink
    } else {
      return downlinks.removeValueForKey(section)
    }
  }

  public func closeDownlinks() {
    for downlink in downlinks.values {
      downlink.close()
    }
    downlinks.removeAll()
  }

  public func downlink(downlink: ListDownlink, didUpdate value: Value, atIndex index: Int) {
    let indexPath = NSIndexPath(forRow: index, inSection: 0)
    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
  }

  public func downlink(downlink: ListDownlink, didInsert value: Value, atIndex index: Int) {
    let indexPath = NSIndexPath(forRow: index, inSection: 0)
    tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
  }

  public func downlink(downlink: ListDownlink, didMove value: Value, fromIndex from: Int, toIndex to: Int) {
    if let section = sectionForDownlink(downlink) {
      let fromIndexPath = NSIndexPath(forRow: from, inSection: section)
      let toIndexPath = NSIndexPath(forRow: to, inSection: section)
      tableView.beginUpdates()
      tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
      tableView.endUpdates()
    }
  }

  public func downlink(downlink: ListDownlink, didRemove value: Value, atIndex index: Int) {
    if let section = sectionForDownlink(downlink) {
      let indexPath = NSIndexPath(forRow: index, inSection: section)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }
  }

  override public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if let downlink = downlinkForSection(section) {
      return downlink.count
    } else {
      return super.tableView(tableView, numberOfRowsInSection: section)
    }
  }

  override public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    if downlinkForSection(indexPath.section) != nil {
      return true
    } else {
      return super.tableView(tableView, canEditRowAtIndexPath: indexPath)
    }
  }

  override public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete, let downlink = downlinkForSection(indexPath.section) {
      downlink.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    } else {
      super.tableView(tableView, commitEditingStyle: editingStyle, forRowAtIndexPath: indexPath)
    }
  }

  override public func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath {
    let section = sourceIndexPath.section
    if let downlink = downlinkForSection(section) {
      if section > proposedDestinationIndexPath.section {
        return NSIndexPath(forRow: 0, inSection: section)
      } else if section < proposedDestinationIndexPath.section {
        return NSIndexPath(forRow: downlink.count - 1, inSection: section)
      } else {
        return proposedDestinationIndexPath
      }
    } else {
      return super.tableView(tableView, targetIndexPathForMoveFromRowAtIndexPath: sourceIndexPath, toProposedIndexPath: proposedDestinationIndexPath)
    }
  }

  override public func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
    let section = fromIndexPath.section
    if let downlink = downlinkForSection(section) {
      downlink.moveFromIndex(fromIndexPath.row, toIndex: toIndexPath.row)
    } else {
      super.tableView(tableView, moveRowAtIndexPath: fromIndexPath, toIndexPath: toIndexPath)
    }
  }
}
