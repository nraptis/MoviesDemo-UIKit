//
//  CommunityGridErrorView.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/22/24.
//

import SwiftUI

//
// This is not used, but it looks pretty good.
// I am keeping it in case we want to use it.
//
// I tried this and didn't see much benefit
// since the lightning bolt exists on the
// bottom bar. The lightning bolt is enough
// of an indicator of error. The popcorn is
// a more light hearted graphic.
//
class CommunityGridErrorView: UIView {

    lazy var errorHostingViewController: UIViewController = {
        let result = UIHostingController(rootView: FullScreenErrorView(text: "An Error Occurred"))
        result.view.translatesAutoresizingMaskIntoConstraints = false
        result.view.backgroundColor = UIColor.clear
        return result
    }()
    
    override init(frame: CGRect) {
        super .init(frame: frame)
        
        if let errorView = errorHostingViewController.view {
            addSubview(errorView)
            addConstraints([
                NSLayoutConstraint(item: errorView, attribute: .left, relatedBy: .equal, toItem: self,
                                   attribute: .left, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: errorView, attribute: .top, relatedBy: .equal, toItem: self,
                                   attribute: .top, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: errorView, attribute: .right, relatedBy: .equal, toItem: self,
                                   attribute: .right, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: errorView, attribute: .bottom, relatedBy: .equal, toItem: self,
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
        if let errorView = errorHostingViewController.view {
            errorView.isHidden = true
            errorView.isUserInteractionEnabled = false
        }
    }
    
    func show() {
        isHidden = false
        isUserInteractionEnabled = true
        if let errorView = errorHostingViewController.view {
            errorView.isHidden = false
            errorView.isUserInteractionEnabled = true
        }
    }
}
