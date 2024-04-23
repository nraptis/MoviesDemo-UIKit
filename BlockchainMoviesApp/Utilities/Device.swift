//
//  Device.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/9/24.
//

import UIKit

class Device {
    
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}
