//
//  CommunityCellModel.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import Foundation

class CommunityCellModel {
    
    // The state of the cell, the UI
    // should always reflect this state.
    var cellModelState = CellModelState.illegal
    
    // This index is the # of the cell, for example cells[0]
    // has an index of 0, and cells[100] has an index of 100.
    var index: Int = -1
}
