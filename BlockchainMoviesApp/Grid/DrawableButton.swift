//
//  DrawableButton.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/18/24.
//

import UIKit

class DrawableButton: UIButton {

    override var isEnabled: Bool {
        set {
            super.isEnabled = newValue
            setNeedsDisplay()
        }
        get {
            return super.isEnabled
        }
    }
    
    var isPressed:Bool { 
        return isTouchInside && isTracking
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }
    
    func setUp() {
        self.addTarget(self, action: #selector(didToggleControlState), for: .touchDown)
        self.addTarget(self, action: #selector(didToggleControlState), for: .touchDragInside)
        self.addTarget(self, action: #selector(didToggleControlState), for: .touchDragOutside)
        self.addTarget(self, action: #selector(didToggleControlState), for: .touchCancel)
        self.addTarget(self, action: #selector(didToggleControlState), for: .touchUpInside)
        self.addTarget(self, action: #selector(didToggleControlState), for: .touchUpOutside)
    }
    
    @objc func didToggleControlState() {
        
    }
    
}
