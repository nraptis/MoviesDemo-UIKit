//
//  CellModelState.swift
//  BlockchainMoviesApp
//
//  Created by "Nick" Django Raptis on 4/19/24.
//

import UIKit

enum CellModelState {
    
    case downloading(CommunityCellData, String) // We have a data model and key.
    
    case downloadingActively(CommunityCellData, String) // We have a data model and key.
    
    case success(CommunityCellData, String, UIImage) // We have a data model and key.
    
    case error(CommunityCellData, String) // We have a data model and key.
    
    case idle(CommunityCellData, String) // We have a data model and key.
    
    case missingKey(CommunityCellData) // This is going to be a cell with no image URL.
    
    case missingModel
    
}
