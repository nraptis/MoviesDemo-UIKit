//
//  CommunityGridCellBottomContentView.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/21/24.
//

import UIKit

class CommunityGridCellBottomContentView: UIView {

    lazy var button1: ColoredButton = {
        let result = ColoredButton(upColor: DarkwingDuckTheme._gray900, downColor: DarkwingDuckTheme._gray700)
        result.setTitleColor(DarkwingDuckTheme._gray050, for: .normal)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()
    
    lazy var centerView: UIView = {
        let result = UIView(frame: .zero)
        result.translatesAutoresizingMaskIntoConstraints = false
        return result
    }()

    init(a: Int) {
        
        super.init(frame: .zero)
        
        addSubview(centerView)
        addConstraints([
            NSLayoutConstraint(item: centerView, attribute: .centerX, relatedBy: .equal, toItem: self,
                               attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: centerView, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: centerView, attribute: .width, relatedBy: .equal, toItem: nil,
                               attribute: .notAnAttribute, multiplier: 1.0, constant: 4.0),
            NSLayoutConstraint(item: centerView, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: 0.0)
        ])
        
        addSubview(button1)
        button1.layer.cornerRadius = CommunityCellConstants.innerRadius - 4
        button1.clipsToBounds = true
        addConstraints([
            NSLayoutConstraint(item: button1, attribute: .left, relatedBy: .equal, toItem: self,
                               attribute: .left, multiplier: 1.0, constant: 4.0),
            NSLayoutConstraint(item: button1, attribute: .top, relatedBy: .equal, toItem: self,
                               attribute: .top, multiplier: 1.0, constant: 4.0),
            NSLayoutConstraint(item: button1, attribute: .right, relatedBy: .equal, toItem: self,
                               attribute: .right, multiplier: 1.0, constant: -4.0),
            NSLayoutConstraint(item: button1, attribute: .bottom, relatedBy: .equal, toItem: self,
                               attribute: .bottom, multiplier: 1.0, constant: -4.0)
        ])
        
        button1.addTarget(self, action: #selector(clickButton1), for: .touchUpInside)
    }
    
    @objc func clickButton1() {
        print("Clicked Bottom 1")
    }
    
    @objc func clickButton2() {
        print("Clicked Bottom 1")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
