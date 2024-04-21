//
//  CommunityCellModel.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import UIKit

class CommunityCellModel {
    
    // The state of the cell, the UI
    // should always reflect this state.
    var cellModelState = CellModelState.missingModel
    
    // This index is the # of the cell, for example cells[0]
    // has an index of 0, and cells[100] has an index of 100.
    var index: Int = -1
    
    func attemptUpdateStateToSuccess(_ communityCellData: CommunityCellData, _ key: String, _ image: UIImage) -> Bool {
        switch cellModelState {
        case .success:
            // No update is needed
            return false
        default:
            cellModelState = .success(communityCellData, key, image)
            return true
        }
    }
    
    func attemptUpdateStateToDownloading(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .downloading:
            // No update is needed
            return false
        default:
            cellModelState = .downloading(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateStateToDownloadingActively(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .downloadingActively:
            // No update is needed
            return false
        default:
            cellModelState = .downloadingActively(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateStateToError(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .error:
            // No update is needed
            return false
        default:
            cellModelState = .error(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateStateToIdle(_ communityCellData: CommunityCellData, _ key: String) -> Bool {
        switch cellModelState {
        case .idle:
            // No update is needed
            return false
        default:
            cellModelState = .idle(communityCellData, key)
            return true
        }
    }
    
    func attemptUpdateStateToMisingKey(_ communityCellData: CommunityCellData) -> Bool {
        switch cellModelState {
        case .missingKey:
            // No update is needed
            return false
        default:
            cellModelState = .missingKey(communityCellData)
            return true
        }
    }
    
    func attemptUpdateStateToMisingModel() -> Bool {
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
