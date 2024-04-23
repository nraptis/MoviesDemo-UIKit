//
//  CommunityGridNoContentView.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/22/24.
//

import UIKit
import SwiftUI

class CommunityGridNoContentView: UIView {

    lazy var noItemsHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: FullScreenNoItemsView())
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = UIColor.clear
        return result
    }()
    
    override init(frame: CGRect) {
        super .init(frame: frame)
        
        if let noItemsView = noItemsHostingViewController.view {
            addSubview(noItemsView)
            addConstraints([
                NSLayoutConstraint(item: noItemsView, attribute: .left, relatedBy: .equal, toItem: self,
                                   attribute: .left, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: noItemsView, attribute: .top, relatedBy: .equal, toItem: self,
                                   attribute: .top, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: noItemsView, attribute: .right, relatedBy: .equal, toItem: self,
                                   attribute: .right, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: noItemsView, attribute: .bottom, relatedBy: .equal, toItem: self,
                                   attribute: .bottom, multiplier: 1.0, constant: 0.0)
            ])
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func hide() {
        isHidden = true
        isUserInteractionEnabled = false
        if let noItemsView = noItemsHostingViewController.view {
            noItemsView.isHidden = true
            noItemsView.isUserInteractionEnabled = false
        }
    }
    
    func show() {
        isHidden = false
        isUserInteractionEnabled = true
        if let noItemsView = noItemsHostingViewController.view {
            noItemsView.isHidden = false
            noItemsView.isUserInteractionEnabled = true
        }
    }
}
