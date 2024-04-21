//
//  CommunityCellSuccessView.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import SwiftUI

class CommunityCellSuccessView: UIView {
    
    lazy var activityIndicatorView: UIActivityIndicatorView = {
        let result = UIActivityIndicatorView(frame: .zero)
        result.translatesAutoresizingMaskIntoConstraints = false
        if Device.isPad {
            result.style = .large
        } else {
            result.style = .medium
        }
        result.color = DarkwingDuckTheme._gray800
        return result
    }()
    
    required init(isShowing: Bool) {
        
        super.init(frame: .zero)
        
        backgroundColor = DarkwingDuckTheme._gray200
        
        addSubview(activityIndicatorView)
        
        addConstraints([
            NSLayoutConstraint(item: activityIndicatorView, attribute: .centerX, relatedBy: .equal,
                               toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: activityIndicatorView, attribute: .centerY, relatedBy: .equal,
                               toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0.0),
        
        ])
        
        if isShowing {
            show()
        } else {
            hide()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        activityIndicatorView.startAnimating()
        isHidden = false
        isUserInteractionEnabled = true
    }
    
    func hide() {
        activityIndicatorView.stopAnimating()
        isHidden = true
        isUserInteractionEnabled = false
    }
}
