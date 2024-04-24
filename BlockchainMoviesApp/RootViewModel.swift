//
//  RootViewModel.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/12/24.
//

import Foundation
import Observation

//
// This could be for things that need to go OVER the navigation.
// Or some global things. Good to minimize the UI refreshes from
// this because it's parent level and can cause major lag.
//

@Observable class RootViewModel { 
    
    let musicLooper = MusicLooper()
    
    init() {
        ReachabilityMonitor.shared.startListening()
        musicLooper.startAudioPlayer()
    }
    
    @ObservationIgnored var errorTitle = ""
    @ObservationIgnored var errorMessage = ""
    
    @MainActor var isShowingError = false
    
    @MainActor func showError(_ title: String, _ message: String) {
        errorTitle = title
        errorMessage = message
        isShowingError = true
    }
}
