import UIKit
import SwimSwift
import SwiftyBeaver

private let listLaneUri: SwimUri = "todo/list"
private let presenceLaneUri: SwimUri = "todo/presence"

private let kCellIdentifier = "Cell"
private let kRowHeight = CGFloat(50)
private let kTableBgColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)

private let kPersonImageCell = String(PersonImageCollectionViewCell.self)

private let log = SwiftyBeaver.self


class TodoListViewController: SwimListViewController, SwimListManagerDelegate, TableViewCellDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    @IBOutlet private weak var presenceView: UICollectionView!
    @IBOutlet private weak var presenceContainer: UIView!
    @IBOutlet private weak var presenceContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!

    private let pinchRecognizer = UIPinchGestureRecognizer()

    private let presenceListHelper: SwimListCollectionViewHelper
    private let presenceListManager: SwimListManagerProtocol

    private var laneScope: LaneScope? {
        get {
            return swimListManager.laneScope
        }
        set {
            swimListManager.laneScope = newValue
        }
    }

    var detailItem : NodeScope? {
        didSet {
            laneScope = detailItem?.scope(lane: listLaneUri)
        }
    }

    required init() {
        self.presenceListManager = TodoListViewController.createPresenceListManager()
        self.presenceListHelper = TodoListViewController.createPresenceListHelper(presenceListManager)
        super.init(listManager: TodoListViewController.createListManager(), nibName: nil, bundle: nil)
        swimListManager.addDelegate(self)
    }

    required init?(coder aDecoder: NSCoder) {
        self.presenceListManager = TodoListViewController.createPresenceListManager()
        self.presenceListHelper = TodoListViewController.createPresenceListHelper(presenceListManager)
        super.init(listManager: TodoListViewController.createListManager(), coder: aDecoder)
        swimListManager.addDelegate(self)
    }

    private static func createListManager() -> SwimListManagerProtocol {
        return SwimListManager<TodoEntry>()
    }

    private static func createPresenceListManager() -> SwimListManagerProtocol {
        let mgr = SwimListManager<UserPresenceModel>()
        mgr.laneProperties.isTransient = true
        return mgr
    }

    private static func createPresenceListHelper(mgr: SwimListManagerProtocol) -> SwimListCollectionViewHelper {
        return SwimListCollectionViewHelper(listManager: mgr)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        swimListTableView = tableView

        presenceView.backgroundColor = UIColor.clearColor()
        presenceView.collectionViewLayout = RTLLayout()
        presenceView.delegate = self
        presenceView.registerNib(UINib(nibName: kPersonImageCell, bundle: nil), forCellWithReuseIdentifier: kPersonImageCell)
        presenceView.scrollsToTop = false

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .Light))
        presenceContainer.insertSubview(blur, belowSubview: presenceView)
        presenceContainer.anchorSubview(blur)

        pinchRecognizer.addTarget(self, action: #selector(handlePinch(_:)))
        tableView.addGestureRecognizer(pinchRecognizer)
        tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: kCellIdentifier)
        tableView.separatorStyle = .None
        tableView.backgroundColor = kTableBgColor
        tableView.rowHeight = kRowHeight
        let presenceFrame = presenceView.superview!.frame
        tableView.contentInset = UIEdgeInsets(top: presenceFrame.size.height, left: 0.0, bottom: 0.0, right: 0.0)

        configureView()

        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(orientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)

        view.removeConstraint(presenceContainerTopConstraint)
        presenceContainerTopConstraint = NSLayoutConstraint(item: presenceContainer, attribute: .Top, relatedBy: .Equal, toItem: topLayoutGuide, attribute: .Bottom, multiplier: 1.0, constant: 0)
        view.addConstraint(presenceContainerTopConstraint)
    }


    func orientationDidChange() {
        configureView()
    }

    private func configureView() {
        title? = detailItem?.nodeUri.path.description ?? ""
    }


    // MARK: - SwimListManagerDelegate

    func swimDidStartSynching() {
        configureView()
    }

    func swimDidChangeObjects() {
        fixColors()
    }

    func swimDidUpdate(index: Int, object: SwimModelProtocolBase) {
        let indexPath = NSIndexPath(forRow: index, inSection: swimObjectSection)
        guard let visiblePaths = tableView.indexPathsForVisibleRows where visiblePaths.contains(indexPath) else {
            return
        }
        let cell = tableView.cellForRowAtIndexPath(indexPath) as! TableViewCell
        precondition(swimObjects.contains { $0 === object })
        cell.toDoItem = (object as! TodoEntry)
    }


    // MARK: - add, delete, edit methods

    func toDoItemAdded() {
        toDoItemAddedAtIndex(0)
    }

    func toDoItemAddedAtIndex(index: Int) {
        let newObjectOrNil = swimListManager.insertNewObjectAtIndex(index) as? TodoEntry
        tableView.reloadData()
        fixColors()
        guard let newObject = newObjectOrNil else {
            return
        }
        // enter edit mode
        let visibleCells = tableView.visibleCells as! [TableViewCell]
        let editCell = visibleCells.find { $0.toDoItem === newObject }
        editCell?.label.becomeFirstResponder()
    }

    func toDoItemDeleted(toDoItem: TodoEntry) {
        guard let index = indexOfObject(toDoItem) else {
            log.warning("Couldn't find deleted item \(toDoItem)!")
            return
        }
        toDoItemDeleted(toDoItem, atIndex: index)
    }

    func toDoItemDeleted(toDoItem: TodoEntry, atIndex index: Int) {
        swimListManager.removeObjectAtIndex(index)

        // loop over the visible cells to animate delete
        let visibleCells = tableView.visibleCells as! [TableViewCell]
        let lastView = visibleCells[visibleCells.count - 1] as TableViewCell
        var delay = 0.0
        var startAnimating = false
        for i in 0..<visibleCells.count {
            let cell = visibleCells[i]
            if startAnimating {
                UIView.animateWithDuration(0.3, delay: delay, options: .CurveEaseInOut,
                    animations: {() in
                        cell.frame = CGRectOffset(cell.frame, 0.0, -cell.frame.size.height)},
                    completion: {(finished: Bool) in if (cell == lastView) {
                        self.tableView.reloadData()
                        }
                    }
                )
                delay += 0.03
            }
            if cell.toDoItem === toDoItem {
                startAnimating = true
                cell.hidden = true
            }
        }

        // use the UITableView to animate the removal of this row
        tableView.beginUpdates()
        let indexPathForRow = NSIndexPath(forRow: index, inSection: 0)
        tableView.deleteRowsAtIndexPaths([indexPathForRow], withRowAnimation: .Fade)
        tableView.endUpdates()
    }
    

    func toDoItemCompleted(toDoItem: TodoEntry) {
        guard let index = indexOfObject(toDoItem) else {
            log.warning("Couldn't find completed item \(toDoItem)!")
            return
        }
        swimListManager.updateObjectAtIndex(index)
    }


    // MARK: UITableViewDataSource / UITableViewDelegate

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kCellIdentifier, forIndexPath: indexPath) as! TableViewCell
        cell.selectionStyle = .None
        cell.textLabel?.backgroundColor = UIColor.clearColor()
        let object = swimObjects[indexPath.row] as! TodoEntry
        cell.delegate = self
        cell.toDoItem = object

        return cell
    }

    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        cell.backgroundColor = colorForIndex(indexPath.row)
    }

    func cellDidBeginEditing(editingCell: TableViewCell) {
        let visibleCells = tableView.visibleCells as! [TableViewCell]
        for cell in visibleCells {
            UIView.animateWithDuration(0.3, animations: {() in
                if cell !== editingCell {
                    cell.alpha = 0.3
                }
            })
        }

        guard let path = tableView.indexPathForCell(editingCell) else {
            preconditionFailure("Cannot find cell when we're editing it!")
        }
        swimListManager.setHighlightAtIndex(path.row, isHighlighted: true)
    }

    func cellDidEndEditing(editingCell: TableViewCell) {
        let visibleCells = tableView.visibleCells as! [TableViewCell]
        for cell: TableViewCell in visibleCells {
            UIView.animateWithDuration(0.3, animations: {() in
                cell.transform = CGAffineTransformIdentity
                if cell !== editingCell {
                    cell.alpha = 1.0
                }
            })
        }

        guard let path = tableView.indexPathForCell(editingCell) else {
            preconditionFailure("Cannot find cell when we're editing it!")
        }

        swimListManager.setHighlightAtIndex(path.row, isHighlighted: false)
        swimListManager.updateObjectAtIndex(path.row)
    }


    // MARK: UICollectionViewDataSource, UICollectionViewDelegate

    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        precondition(collectionView == presenceView)
        precondition(section == 0)

        return presenceListManager.objects.count;
    }


    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        precondition(collectionView == presenceView)
        precondition(indexPath.section == 0)

        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(kPersonImageCell, forIndexPath: indexPath) as! PersonImageCollectionViewCell
        let user = presenceListManager.objects[indexPath.item] as! UserPresenceModel
        cell.personImageView.initials = user.initials ?? "?"
        return cell
    }


    // MARK: UIScrollViewDelegate methods

    // a cell that is rendered as a placeholder to indicate where a new item is added
    private let placeHolderCell = TableViewCell(style: .Default, reuseIdentifier: kCellIdentifier)
    // indicates the state of this behavior
    private var pullDownInProgress = false

    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        // this behavior starts when a user pulls down while at the top of the table
        pullDownInProgress = scrollView.contentOffset.y <= 0.0
        placeHolderCell.backgroundColor = UIColor.redColor()
        if pullDownInProgress {
            // add the placeholder
            tableView.insertSubview(placeHolderCell, atIndex: 0)
        }
    }

    func scrollViewDidScroll(scrollView: UIScrollView)  {
        // non-scrollViewDelegate methods need this property value
        let scrollViewContentOffsetY = tableView.contentOffset.y + tableView.contentInset.top

        if pullDownInProgress && scrollView.contentOffset.y <= 0.0 {
            // maintain the location of the placeholder
            placeHolderCell.frame = CGRect(x: 0, y: -tableView.rowHeight,
                width: tableView.frame.size.width, height: tableView.rowHeight)
            placeHolderCell.label.text = -scrollViewContentOffsetY > tableView.rowHeight ? "Release to add item" : "Pull to add item"
            placeHolderCell.alpha = min(1.0, -scrollViewContentOffsetY / tableView.rowHeight)
        } else {
            pullDownInProgress = false
        }
    }

    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // check whether the user pulled down far enough
        if pullDownInProgress && -scrollView.contentOffset.y > tableView.rowHeight + tableView.contentInset.top {
            toDoItemAdded()
        }
        pullDownInProgress = false
        placeHolderCell.removeFromSuperview()
    }
    

    // MARK: - pinch-to-add methods

    private struct TouchPoints {
        var upper: CGPoint
        var lower: CGPoint
    }
    // the indices of the upper and lower cells that are being pinched
    private var upperCellIndex = -100
    private var lowerCellIndex = -100
    // the location of the touch points when the pinch began
    private var initialTouchPoints: TouchPoints!
    // indicates that the pinch was big enough to cause a new item to be added
    private var pinchExceededRequiredDistance = false

    // indicates that the pinch is in progress
    private var pinchInProgress = false

    func handlePinch(recognizer: UIPinchGestureRecognizer) {
//        if recognizer.state == .Began {
//            pinchStarted(recognizer)
//        }
//        if recognizer.state == .Changed
//            && pinchInProgress
//            && recognizer.numberOfTouches() == 2 {
//                pinchChanged(recognizer)
//        }
//        if recognizer.state == .Ended {
//            pinchEnded(recognizer)
//        }
    }

    func pinchStarted(recognizer: UIPinchGestureRecognizer) {
        // find the touch-points
        initialTouchPoints = getNormalizedTouchPoints(recognizer)

        // locate the cells that these points touch
        upperCellIndex = -100
        lowerCellIndex = -100
        let visibleCells = tableView.visibleCells  as! [TableViewCell]
        for i in 0..<visibleCells.count {
            let cell = visibleCells[i]
            if viewContainsPoint(cell, point: initialTouchPoints.upper) {
                upperCellIndex = i
            }
            if viewContainsPoint(cell, point: initialTouchPoints.lower) {
                lowerCellIndex = i
            }
        }
        // check whether they are neighbors
        if abs(upperCellIndex - lowerCellIndex) == 1 {
            // initiate the pinch
            pinchInProgress = true
            // show placeholder cell
            let precedingCell = visibleCells[upperCellIndex]
            placeHolderCell.frame = CGRectOffset(precedingCell.frame, 0.0, kRowHeight / 2.0)
            placeHolderCell.backgroundColor = precedingCell.backgroundColor
            tableView.insertSubview(placeHolderCell, atIndex: 0)
        }
    }

    func pinchChanged(recognizer: UIPinchGestureRecognizer) {
        // find the touch points
        let currentTouchPoints = getNormalizedTouchPoints(recognizer)

        // determine by how much each touch point has changed, and take the minimum delta
        let upperDelta = currentTouchPoints.upper.y - initialTouchPoints.upper.y
        let lowerDelta = initialTouchPoints.lower.y - currentTouchPoints.lower.y
        let delta = -min(0, min(upperDelta, lowerDelta))

        // offset the cells, negative for the cells above, positive for those below
        let visibleCells = tableView.visibleCells as! [TableViewCell]
        for i in 0..<visibleCells.count {
            let cell = visibleCells[i]
            if i <= upperCellIndex {
                cell.transform = CGAffineTransformMakeTranslation(0, -delta)
            }
            if i >= lowerCellIndex {
                cell.transform = CGAffineTransformMakeTranslation(0, delta)
            }
        }

        // scale the placeholder cell
        let gapSize = delta * 2
        let cappedGapSize = min(gapSize, tableView.rowHeight)
        placeHolderCell.transform = CGAffineTransformMakeScale(1.0, cappedGapSize / tableView.rowHeight)
        placeHolderCell.label.text = gapSize > tableView.rowHeight ? "Release to add item" : "Pull apart to add item"
        placeHolderCell.alpha = min(1.0, gapSize / tableView.rowHeight)

        // has the user pinched far enough?
        pinchExceededRequiredDistance = gapSize > tableView.rowHeight
    }

    func pinchEnded(recognizer: UIPinchGestureRecognizer) {
        pinchInProgress = false

        // remove the placeholder cell
        placeHolderCell.transform = CGAffineTransformIdentity
        placeHolderCell.removeFromSuperview()

        if pinchExceededRequiredDistance {
            pinchExceededRequiredDistance = false

            // Set all the cells back to the transform identity
            let visibleCells = self.tableView.visibleCells as! [TableViewCell]
            for cell in visibleCells {
                cell.transform = CGAffineTransformIdentity
            }

            // add a new item
            let indexOffset = Int(floor(tableView.contentOffset.y / tableView.rowHeight))
            toDoItemAddedAtIndex(lowerCellIndex + indexOffset)
        } else {
            // otherwise, animate back to position
            UIView.animateWithDuration(0.2, delay: 0.0, options: .CurveEaseInOut, animations: {() in
                let visibleCells = self.tableView.visibleCells as! [TableViewCell]
                for cell in visibleCells {
                    cell.transform = CGAffineTransformIdentity
                }
                }, completion: nil)
        }
    }

    // returns the two touch points, ordering them to ensure that
    // upper and lower are correctly identified.
    private func getNormalizedTouchPoints(recognizer: UIGestureRecognizer) -> TouchPoints {
        var pointOne = recognizer.locationOfTouch(0, inView: tableView)
        var pointTwo = recognizer.locationOfTouch(1, inView: tableView)
        // ensure pointOne is the top-most
        if pointOne.y > pointTwo.y {
            let temp = pointOne
            pointOne = pointTwo
            pointTwo = temp
        }
        return TouchPoints(upper: pointOne, lower: pointTwo)
    }

    private func viewContainsPoint(view: UIView, point: CGPoint) -> Bool {
        let frame = view.frame
        return (frame.origin.y < point.y) && (frame.origin.y + (frame.size.height) > point.y)
    }


    // MARK: Helpers

    private func indexOfObject(object: TodoEntry) -> Int? {
        return swimObjects.indexOf { ($0 as! TodoEntry) == object }
    }

    private func fixColors() {
        tableView.visibleCells.forEach { (cell) -> () in
            if let idx = tableView.indexPathForCell(cell) {
                cell.backgroundColor = colorForIndex(idx.row)
            }
        }
    }

    private func colorForIndex(index: Int) -> UIColor {
        let itemCount = swimObjects.count - 1
        let val = (itemCount == 0 ? 0.3 : (CGFloat(index) / CGFloat(itemCount)) * 0.6)
        return UIColor(red: 1.0, green: val, blue: 0.0, alpha: 1.0)
    }
}
