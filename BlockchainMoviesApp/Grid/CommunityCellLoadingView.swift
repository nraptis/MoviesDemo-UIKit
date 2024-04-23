//
//  CommunityCellLoadingView.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/21/24.
//

import UIKit

class CommunityCellLoadingView: UIView {
    
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
