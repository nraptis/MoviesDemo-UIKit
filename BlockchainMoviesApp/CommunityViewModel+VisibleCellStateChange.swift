//
//  CommunityViewModel+VisibleCellStateChange.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/23/24.
//

import UIKit

extension CommunityViewModel {
    
    //
    // This will be 100% synchronous, essentially a simple check.
    // For example, if the image is in the image dictionary, we will
    // update the states appropriately. We should *NOT* add anything
    // to the downloader, let the heart beat process take care of it.
    //
    // There will be some duplicate work between
    // "refreshAllCellStatesForVisibleCellsChanged" and
    // "refreshAllCellStatesAndReconcile". However, this
    // funtion should *NOT* be called by the latter. It is
    // only a quick check, we would have to rule things out
    // yet again in the other function...
    //
    @MainActor func refreshAllCellStatesForVisibleCellsChanged() {
        
        // We are going to immediately update all the cells, we are only
        // checking the visible cells. So, this is a bit of a nombo breaker
        // in that, we just use an empty set of visible cells.
        //_visibleCommunityCellModelIndices.removeAll(keepingCapacity: true)
        _refreshVisibleCommunityCellModelIndices()
        
        for communityCellModel in visibleCommunityCellModels {
            let index = communityCellModel.index
            if let communityCellData = getCommunityCellData(at: index) {
                if let key = communityCellData.key {
                    if let image = _imageDict[key] {
                        _ = attemptUpdateCellStateSuccess(communityCellModel: communityCellModel,
                                                          communityCellData: communityCellData,
                                                          visibleCellIndices: _visibleCommunityCellModelIndices,
                                                          isFromRefresh: false,
                                                          isFromHeartBeat: false,
                                                          key: key,
                                                          image: image,
                                                          debug: "VisibleCellsChanged, Have Image",
                                                          emoji: "🧰")
                    } else if _imageFailedSet.contains(index) {
                        _ = attemptUpdateCellStateError(communityCellModel: communityCellModel,
                                                        communityCellData: communityCellData,
                                                        visibleCellIndices: _visibleCommunityCellModelIndices,
                                                        isFromRefresh: false,
                                                        isFromHeartBeat: false,
                                                        key: key,
                                                        debug: "VisibleCellsChanged, FailSet",
                                                        emoji: "🧰")
                    } else {
                        
                        // If we are downloading, let's stay there, otherwise go downloading...
                        switch communityCellModel.cellModelState {
                        case .downloading, .downloadingActively:
                            // We are already in a downloading state
                            break
                        default:
                            // an illegal/unknown configuration.
                            _ = attemptUpdateCellStateDownloading(communityCellModel: communityCellModel,
                                                                  communityCellData: communityCellData,
                                                                  visibleCellIndices: _visibleCommunityCellModelIndices,
                                                                  isFromRefresh: false,
                                                                  isFromHeartBeat: false,
                                                                  key: key,
                                                                  debug: "VisibleCellsChanged, Mock Downloading",
                                                                  emoji: "🧰")
                        }
                    }
                } else {
                    // Go to the missing key state... (we still have server data)
                    _ = attemptUpdateCellStateMissingKey(communityCellModel: communityCellModel,
                                                         communityCellData: communityCellData,
                                                         visibleCellIndices: _visibleCommunityCellModelIndices,
                                                         isFromRefresh: false,
                                                         isFromHeartBeat: false,
                                                         debug: "Key Not Found",
                                                         emoji: "🧰")
                }
            } else {
                // Go to the missing model state...
                _ = attemptUpdateCellStateMisingModel(communityCellModel: communityCellModel,
                                                      visibleCellIndices: _visibleCommunityCellModelIndices,
                                                      isFromRefresh: false,
                                                      isFromHeartBeat: false,
                                                      debug: "Model Not Found",
                                                      emoji: "🧰")
            }
        }
    }
}
