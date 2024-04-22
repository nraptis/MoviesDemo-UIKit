//
//  ColoredButton.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/11/24.
//

import UIKit

class ColoredButton: DrawableButton {
    
    let upColor: UIColor
    let downColor: UIColor
    
    init(upColor: UIColor, downColor: UIColor) {
        self.upColor = upColor
        self.downColor = downColor
        super.init(frame: .zero)
        backgroundColor = upColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc internal override func didToggleControlState() {
        if isPressed {
            backgroundColor = downColor
        } else {
            backgroundColor = upColor
        }
    }
}
