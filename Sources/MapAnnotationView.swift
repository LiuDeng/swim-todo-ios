//
//  MapAnnotationView.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/11/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

// Based on https://github.com/choefele/CCHMapClusterController/blob/master/CCHMapClusterController%20Example%20iOS/CCHMapClusterController%20Example%20iOS/ClusterAnnotationView.m
// by Claus Höfele, which in turn is based on
// https://github.com/thoughtbot/TBAnnotationClustering/blob/master/TBAnnotationClustering/TBClusterAnnotationView.m
// by Theodore Calmes.

import Foundation
import MapKit


class MapAnnotationView: MKAnnotationView {
    var count = 0 {
        didSet {
            precondition(count > 1)
            countLabel.text = String(count)
            vehicle = nil
            setNeedsLayout()
        }
    }

    var vehicle: VehicleModel? {
        didSet {
            setNeedsLayout()
        }
    }

    private let countLabel = UILabel(frame: CGRectZero)


    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        canShowCallout = true

        backgroundColor = UIColor.clearColor()
        configureLabel()
        configureCallout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func configureLabel() {
        countLabel.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        countLabel.textAlignment = .Center
        countLabel.backgroundColor = UIColor.clearColor()
        countLabel.textColor = UIColor.whiteColor()
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 2
        countLabel.numberOfLines = 1
        countLabel.font = UIFont.boldSystemFontOfSize(12)
        countLabel.baselineAdjustment = .AlignCenters

        addSubview(countLabel)
    }


    private func configureCallout() {
        leftCalloutAccessoryView = UIImageView(image: UIImage(named: "bus"))
    }


    override func layoutSubviews() {
        image = imageForCount()
        centerOffset = CGPointZero
        countLabel.frame = self.bounds
        countLabel.hidden = (vehicle != nil)
    }


    private func imageForCount() -> UIImage {
        if vehicle != nil {
            return UIImage(named: "bus")!
        }
        let suffix = suffixForCount()
        return UIImage(named: "CircleRed\(suffix)")!
    }


    private func suffixForCount() -> Int {
        if count > 1000 {
            return 39
        }
        else if count > 500 {
            return 38
        }
        else if count > 200 {
            return 36
        }
        else if count > 100 {
            return 34
        }
        else if count > 50 {
            return 31
        }
        else if count > 20 {
            return 28
        }
        else if count > 10 {
            return 25
        }
        else if count > 5 {
            return 24
        }
        else {
            return 21
        }
    }
}
