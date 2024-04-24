//
//  CommunityCellModel.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/21/24.
//

import UIKit

// This is the model which drives the UI. For each of these cell
// models, there will be a cell on the screen (only visible ones).

class CommunityCellModel {
    
    // The state of the cell, the UI
    // should always reflect this state.
    var cellModelState = CellModelState.missingModel
    
    // This index is the # of the cell, for example cells[0]
    // has an index of 0, and cells[100] has an index of 100.
    var index: Int = -1
    
    var isBlockedFromHeartBeat = false
    
    func attemptUpdateCellStateSuccess(_ communityCellData: CommunityCellData, 
                                     _ key: String,
                                     _ image: UIImage) -> Bool {
        switch cellModelState {
        case .success:
            // No update is needed
            return false
        default:
            cellModelState = .success(communityCellData, key, image)
            return true
        }
    }
    
    func attemptUpdateCellStateDownloading(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .downloading:
            // No update is needed
            return false
        default:
            cellModelState = .downloading(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateCellStateDownloadingActively(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .downloadingActively:
            // No update is needed
            return false
        default:
            cellModelState = .downloadingActively(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateCellStateError(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .error:
            // No update is needed
            return false
        default:
            cellModelState = .error(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateCellStateIdle(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .idle:
            // No update is needed
            return false
        default:
            cellModelState = .idle(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateCellStateMisingKey(_ communityCellData: CommunityCellData) -> Bool {
        switch cellModelState {
        case .missingKey:
            // No update is needed
            return false
        default:
            cellModelState = .missingKey(communityCellData)
            return true
        }
    }
    
    func attemptUpdateCellStateMisingModel() -> Bool {
        switch cellModelState {
        case .missingModel:
            // No update is needed
            return false
        default:
            cellModelState = .missingModel
            return true
        }
    }
}

extension CommunityCellModel: Equatable {
    static func == (lhs: CommunityCellModel, rhs: CommunityCellModel) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension CommunityCellModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
