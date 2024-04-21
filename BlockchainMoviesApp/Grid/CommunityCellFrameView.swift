//
//  CommunityCellFrameView.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import UIKit

class CommunityCellFrameView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        let cutOutRect = CGRect(x: bounds.origin.x + CommunityCellConstants.frameThickness,
                                y: bounds.origin.y + CommunityCellConstants.frameThickness,
                                width: bounds.size.width - (CommunityCellConstants.frameThickness + CommunityCellConstants.frameThickness),
                                height: bounds.size.height - (CommunityCellConstants.bottomAreaHeight))
        let rectPath = UIBezierPath(rect: bounds)
        let cutOutPath = UIBezierPath(roundedRect: cutOutRect, cornerRadius: CommunityCellConstants.frameRadius)
        context.saveGState()
        context.addPath(rectPath.cgPath)
        context.addPath(cutOutPath.cgPath)
        context.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }
}
