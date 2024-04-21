//
//  CellSuccessView.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import UIKit

class CellSuccessView: UIView {

    lazy var imageView: UIImageView = {
        let result = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 32.0, height: 32.0))
        result.translatesAutoresizingMaskIntoConstraints = false
        result.contentMode = .scaleAspectFill
        return result
    }()
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
