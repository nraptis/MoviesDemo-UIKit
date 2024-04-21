//
//  CommunityCellConstants.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import Foundation

struct CommunityCellConstants {
    static let outerRadius = CGFloat(Device.isPad ? 16.0 : 12.0)
    static let innerRadius = CGFloat(Device.isPad ? 14.0 : 10.0)
    static let frameRadius = CGFloat(Device.isPad ? 12.0 : 8.0)
    static let buttonRadius = CGFloat(Device.isPad ? 12.0 : 8.0)
    static let outlineThickness = CGFloat(Device.isPad ? 2.0 : 1.0)
    static let frameThickness = CGFloat(Device.isPad ? 2.0 : 1.0)
    static let bottomAreaHeight = CGFloat(Device.isPad ? 36.0 : 22.0)
}
