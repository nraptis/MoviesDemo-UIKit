//
//  CommunityViewModel+CellUpdates.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/22/24.
//

import UIKit

extension CommunityViewModel {
    
    // We pipeline all state updates through these functions.
    // It's simply too many things to consider inline for each case.
    
    // We return true if we published an update.
    @MainActor func attemptUpdateCellStateSuccess(communityCellModel: CommunityCellModel,
                                                  communityCellData: CommunityCellData,
                                                  visibleCellIndices: Set<Int>?,
                                                  isFromRefresh: Bool,
                                                  isFromHeartBeat: Bool,
                                                  key: String,
                                                  image: UIImage,
                                                  debug: String,
                                                  emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateSuccess(communityCellData, key, image) {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Success (\(image.size.width) x \(image.size.height)) [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    
    @MainActor func attemptUpdateCellStateDownloading(communityCellModel: CommunityCellModel,
                                                      communityCellData: CommunityCellData,
                                                      visibleCellIndices: Set<Int>?,
                                                      isFromRefresh: Bool,
                                                      isFromHeartBeat: Bool,
                                                      key: String,
                                                      debug: String,
                                                      emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateDownloading(communityCellData, key) {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Downloading [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateDownloadingActively(communityCellModel: CommunityCellModel,
                                                              communityCellData: CommunityCellData,
                                                              visibleCellIndices: Set<Int>?,
                                                              isFromRefresh: Bool,
                                                              isFromHeartBeat: Bool,
                                                              key: String,
                                                              debug: String,
                                                              emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateDownloadingActively(communityCellData, key) {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .DownloadingActively [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateError(communityCellModel: CommunityCellModel,
                                                communityCellData: CommunityCellData,
                                                visibleCellIndices: Set<Int>?,
                                                isFromRefresh: Bool,
                                                isFromHeartBeat: Bool,
                                                key: String,
                                                debug: String,
                                                emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateError(communityCellData, key) {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Error [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateIdle(communityCellModel: CommunityCellModel,
                                               communityCellData: CommunityCellData,
                                               visibleCellIndices: Set<Int>?,
                                               isFromRefresh: Bool,
                                               isFromHeartBeat: Bool,
                                               key: String,
                                               debug: String,
                                               emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateIdle(communityCellData, key) {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Idle [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateMissingKey(communityCellModel: CommunityCellModel,
                                                     communityCellData: CommunityCellData,
                                                     visibleCellIndices: Set<Int>?,
                                                     isFromRefresh: Bool,
                                                     isFromHeartBeat: Bool,
                                                     debug: String,
                                                     emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateMisingKey(communityCellData) {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .MissingKey [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateMisingModel(communityCellModel: CommunityCellModel,
                                                      visibleCellIndices: Set<Int>?,
                                                      isFromRefresh: Bool,
                                                      isFromHeartBeat: Bool,
                                                      debug: String,
                                                      emoji: String) -> Bool {
        
        if isFromHeartBeat && communityCellModel.isBlockedFromHeartBeat {
            return false
        }
        
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateMisingModel() {
            if Self.DEBUG_STATE_CHANGES {
                print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .MisingModel [\(debug)]")
            }
            var isVisible = true
            if let visibleCellIndices = visibleCellIndices {
                isVisible = visibleCellIndices.contains(communityCellModel.index)
            }
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
}
