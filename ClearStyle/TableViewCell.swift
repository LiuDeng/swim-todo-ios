//
//  TableViewCell.swift
//  ClearStyle
//
//  Created by Audrey M Tam on 29/07/2014.
//  Copyright (c) 2014 Ray Wenderlich. All rights reserved.
//

import QuartzCore
import UIKit


protocol TableViewCellDelegate {
    func toDoItemDeleted(todoItem: TodoEntry)
    func toDoItemCompleted(todoItem: TodoEntry)
    func cellDidBeginEditing(editingCell: TableViewCell)
    func cellDidEndEditing(editingCell: TableViewCell)
}


class TableViewCell: UITableViewCell, UITextFieldDelegate {
    
    var toDoItem: TodoEntry? {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            label.text = toDoItem!.name
            label.strikeThrough = toDoItem!.completed
            itemCompleteLayer.hidden = !label.strikeThrough
            CATransaction.commit()
        }
    }

    var delegate: TableViewCellDelegate?

    let label: StrikeThroughText

    private var lblWriteInProgress: UILabel!

    private var tickLabel: UILabel
    private var crossLabel: UILabel

    private let gradientLayer = CAGradientLayer()
    private var itemCompleteLayer = CALayer()

    private var originalCenter = CGPoint()
    private var deleteOnDragRelease = false
    private var completeOnDragRelease = false


    required init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override init(style: UITableViewCellStyle,
        reuseIdentifier: String?) {
        // create a label that renders the to-do item text
        label = StrikeThroughText(frame: CGRect.null)
        label.textColor = UIColor.whiteColor()
        label.font = UIFont.boldSystemFontOfSize(16)
        label.backgroundColor = UIColor.clearColor()
        
        // utility method for creating the contextual cues
        func createCueLabel() -> UILabel {
            let label = UILabel(frame: CGRect.null)
            label.textColor = UIColor.whiteColor()
            label.font = UIFont.boldSystemFontOfSize(32.0)
            label.backgroundColor = UIColor.clearColor()
            return label
        }
        
        // tick and cross labels for context cues
        tickLabel = createCueLabel()
        tickLabel.text = "\u{2713}"
        tickLabel.textAlignment = .Right
        crossLabel = createCueLabel()
        crossLabel.text = "\u{2717}"
        crossLabel.textAlignment = .Left

        lblWriteInProgress = UILabel()
        lblWriteInProgress.text = "..."
        lblWriteInProgress.font = UIFont.boldSystemFontOfSize(16)
        lblWriteInProgress.textColor = UIColor.whiteColor()
        lblWriteInProgress.backgroundColor = UIColor.clearColor()
        lblWriteInProgress.layer.opacity = 0.0

        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        label.delegate = self
        label.contentVerticalAlignment = .Center
        
        addSubview(label)
        addSubview(lblWriteInProgress)
        addSubview(tickLabel)
        addSubview(crossLabel)
        // remove the default blue highlight for selected cells
        selectionStyle = .None
        
        // gradient layer for cell
        gradientLayer.frame = bounds
        let color1 = UIColor(white: 1.0, alpha: 0.2).CGColor as CGColorRef
        let color2 = UIColor(white: 1.0, alpha: 0.1).CGColor as CGColorRef
        let color3 = UIColor.clearColor().CGColor as CGColorRef
        let color4 = UIColor(white: 0.0, alpha: 0.1).CGColor as CGColorRef
        gradientLayer.colors = [color1, color2, color3, color4]
        gradientLayer.locations = [0.0, 0.01, 0.95, 1.0]
        layer.insertSublayer(gradientLayer, atIndex: 0)
        
        // add a layer that renders a green background when an item is complete
        itemCompleteLayer = CALayer(layer: layer)
        itemCompleteLayer.backgroundColor = UIColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0).CGColor
        itemCompleteLayer.hidden = true
        layer.insertSublayer(itemCompleteLayer, atIndex: 0)
        
        // add a pan recognizer
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(TableViewCell.handlePan(_:)))
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }


    override func prepareForReuse() {
        super.prepareForReuse()

        lblWriteInProgress.layer.opacity = 0.0
        lblWriteInProgress.layer.removeAllAnimations()
    }


    private let kLabelLeftMargin: CGFloat = 15.0
    private let kLblWriteInProgressRightMargin: CGFloat = 25.0
    private let kUICuesMargin: CGFloat = 10.0
    private let kUICuesWidth: CGFloat = 50.0

    override func layoutSubviews() {
        super.layoutSubviews()
        // ensure the gradient layer occupies the full bounds
        gradientLayer.frame = bounds
        itemCompleteLayer.frame = bounds
        label.frame = CGRect(x: kLabelLeftMargin, y: 0,
            width: bounds.size.width - kLabelLeftMargin, height: bounds.size.height)
        lblWriteInProgress.frame = CGRect(x: bounds.size.width - kLblWriteInProgressRightMargin, y: 0,
            width: kLblWriteInProgressRightMargin, height: bounds.size.height)
        tickLabel.frame = CGRect(x: -kUICuesWidth - kUICuesMargin, y: 0,
            width: kUICuesWidth, height: bounds.size.height)
        crossLabel.frame = CGRect(x: bounds.size.width + kUICuesMargin, y: 0,
            width: kUICuesWidth, height: bounds.size.height)
    }


    func didCompleteServerWrites() {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.duration = 0.5
        lblWriteInProgress.layer.opacity = 0.0
        lblWriteInProgress.layer.addAnimation(fade, forKey: "fade")
    }


    //MARK: - horizontal pan gesture methods

    func handlePan(recognizer: UIPanGestureRecognizer) {
        // 1
        if recognizer.state == .Began {
            // when the gesture begins, record the current center location
            originalCenter = center
        }
        // 2
        if recognizer.state == .Changed {
            let translation = recognizer.translationInView(self)
            center = CGPointMake(originalCenter.x + translation.x, originalCenter.y)
            // has the user dragged the item far enough to initiate a delete/complete?
            deleteOnDragRelease = frame.origin.x < -frame.size.width / 2.0
            completeOnDragRelease = frame.origin.x > frame.size.width / 2.0
            // fade the contextual clues
            let cueAlpha = fabs(frame.origin.x) / (frame.size.width / 2.0)
            tickLabel.alpha = cueAlpha
            crossLabel.alpha = cueAlpha
            // indicate when the user has pulled the item far enough to invoke the given action
            tickLabel.textColor = completeOnDragRelease ? UIColor.greenColor() : UIColor.whiteColor()
            crossLabel.textColor = deleteOnDragRelease ? UIColor.redColor() : UIColor.whiteColor()
        }
        // 3
        if recognizer.state == .Ended {
            let originalFrame = CGRect(x: 0, y: frame.origin.y,
                width: bounds.size.width, height: bounds.size.height)
            if deleteOnDragRelease {
                if let item = toDoItem {
                    // notify the delegate that this item should be deleted
                    delegate?.toDoItemDeleted(item)
                }
            } else if completeOnDragRelease {
                if let item = toDoItem {
                    let done = !item.completed
                    item.completed = done
                    lblWriteInProgress.layer.opacity = 1.0
                    lblWriteInProgress.layer.removeAllAnimations()
                    delegate?.toDoItemCompleted(item)
                    label.strikeThrough = done
                    itemCompleteLayer.hidden = !done
                }
                UIView.animateWithDuration(0.2, animations: {self.frame = originalFrame})
            } else {
                UIView.animateWithDuration(0.2, animations: {self.frame = originalFrame})
            }
        }
    }
    
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = panGestureRecognizer.translationInView(superview!)
            if fabs(translation.x) > fabs(translation.y) {
                return true
            }
            return false
        }
        return false
    }
    
    // MARK: - UITextFieldDelegate methods
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        // close the keyboard on Enter
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        // disable editing of completed to-do items
        if toDoItem != nil {
            return !toDoItem!.completed
        }
        return false
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        toDoItem?.name = (textField.text ?? "")
        lblWriteInProgress.layer.opacity = 1.0
        lblWriteInProgress.layer.removeAllAnimations()
        delegate?.cellDidEndEditing(self)
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        delegate?.cellDidBeginEditing(self)
    }

}
