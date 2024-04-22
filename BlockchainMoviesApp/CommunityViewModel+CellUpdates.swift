//
//  CommunityViewModel+CellUpdates.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/22/24.
//

import UIKit

extension CommunityViewModel {
    
    // We return true if we published an update.
    @MainActor func attemptUpdateCellStateSuccess(communityCellModel: CommunityCellModel,
                                                  communityCellData: CommunityCellData,
                                                  visibleCellIndices: Set<Int>,
                                                  isFromRefresh: Bool,
                                                  key: String,
                                                  image: UIImage,
                                                  debug: String,
                                                  emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateSuccess(communityCellData, key, image) {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Success (\(image.size.width) x \(image.size.height)) [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateDownloading(communityCellModel: CommunityCellModel,
                                                      communityCellData: CommunityCellData,
                                                      visibleCellIndices: Set<Int>,
                                                      isFromRefresh: Bool,
                                                      key: String,
                                                      debug: String,
                                                      emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateDownloading(communityCellData, key) {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Downloading [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateDownloadingActively(communityCellModel: CommunityCellModel,
                                                              communityCellData: CommunityCellData,
                                                              visibleCellIndices: Set<Int>,
                                                              isFromRefresh: Bool,
                                                              key: String,
                                                              debug: String,
                                                              emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateDownloadingActively(communityCellData, key) {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .DownloadingActively [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateError(communityCellModel: CommunityCellModel,
                                                communityCellData: CommunityCellData,
                                                visibleCellIndices: Set<Int>,
                                                isFromRefresh: Bool,
                                                key: String,
                                                debug: String,
                                                emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateError(communityCellData, key) {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Error [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateIdle(communityCellModel: CommunityCellModel,
                                               communityCellData: CommunityCellData,
                                               visibleCellIndices: Set<Int>,
                                               isFromRefresh: Bool,
                                               key: String,
                                               debug: String,
                                               emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateIdle(communityCellData, key) {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .Idle [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateMissingKey(communityCellModel: CommunityCellModel,
                                                     communityCellData: CommunityCellData,
                                                     visibleCellIndices: Set<Int>,
                                                     isFromRefresh: Bool,
                                                     debug: String,
                                                     emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateMisingKey(communityCellData) {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .MissingKey [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
    
    @MainActor func attemptUpdateCellStateMisingModel(communityCellModel: CommunityCellModel,
                                                      visibleCellIndices: Set<Int>,
                                                      isFromRefresh: Bool,
                                                      debug: String,
                                                      emoji: String) -> Bool {
        if isRefreshing {
            if !isFromRefresh {
                return false
            }
        }
        
        if communityCellModel.attemptUpdateCellStateMisingModel() {
            print("[[\(emoji)]] Cell #{\(communityCellModel.index)} State Updated => .MisingModel [\(debug)]")
            let isVisible = visibleCellIndices.contains(communityCellModel.index)
            if isVisible {
                cellNeedsUpdatePublisher.send(communityCellModel)
                return true
            }
        }
        return false
    }
}
