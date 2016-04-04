//
//  RTLLayout.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 3/31/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import UIKit


class RTLLayout: UICollectionViewFlowLayout {

    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attrs = super.layoutAttributesForElementsInRect(rect) else {
            return nil
        }
        return attrs.map {
            return ($0.representedElementKind == nil ? layoutAttributesForItemAtIndexPath($0.indexPath)! : $0.copy() as! UICollectionViewLayoutAttributes)
        }
    }


    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        guard let cv = collectionView, attrs = super.layoutAttributesForItemAtIndexPath(indexPath) else {
            return nil
        }

        let cvWidth = cv.frame.size.width
        let cellWidth = attrs.frame.width
        let newattrs = attrs.copy() as! UICollectionViewLayoutAttributes
        newattrs.frame.origin.x = cvWidth - cellWidth * CGFloat(indexPath.item + 1)
        return newattrs
    }
}
