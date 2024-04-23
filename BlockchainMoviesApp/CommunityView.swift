//
//  CommunityView.swift
//  BlockchainMoviesApp
//
//  Created by Nameless Bastard on 4/21/24.
//

import SwiftUI

struct CommunityView: View {
    
    //
    // These mirror our view model, we are
    // not using Observation framework.
    //
    @State var isShowingNetworkError = false
    @State var isAnyItemPresent = false
    @State var isFetching = false
    @State var isFetchingDetails = false
    @State var isFirstFetchComplete = false
    @State var isFetchingUserInitiated = false
    
    
    
    
    
    
    var communityViewModel: CommunityViewModel
    var body: some View {
        
        return GeometryReader { containerGeometry in
            
            let isLandscape = containerGeometry.size.width > containerGeometry.size.height
            
            let logoBarHeight: Int
            let bottomBarHeight: Int
            if Device.isPad {
                if isLandscape {
                    logoBarHeight = 54
                    bottomBarHeight = 44
                } else {
                    logoBarHeight = 62
                    bottomBarHeight = 54
                }
            } else {
                if isLandscape {
                    logoBarHeight = 44
                    bottomBarHeight = 32
                } else {
                    logoBarHeight = 52
                    bottomBarHeight = 44
                }
            }
            
            return VStack(spacing: 0.0) {
                
                getLogoBarContainer(logoBarHeight: CGFloat(logoBarHeight))
                
                ZStack {
                    GeometryReader { geometry in
                        return guts(containerGeometry: geometry)
                    }
                }
                getFooterBar(bottomBarHeight: CGFloat(bottomBarHeight))
            }
        }
        .background(DarkwingDuckTheme.gray050)
        .onReceive(communityViewModel.$isNetworkErrorPresent) { value in
            isShowingNetworkError = value
        }
        .onReceive(communityViewModel.$isAnyItemPresent) { value in
            isAnyItemPresent = value
        }
        .onReceive(communityViewModel.$isFetching) { value in
            isFetching = value
        }
        .onReceive(communityViewModel.$isFetchingDetails) { value in
            isFetchingDetails = value
        }
        .onReceive(communityViewModel.$isFirstFetchComplete) { value in
            isFirstFetchComplete = value
        }
        .onReceive(communityViewModel.$isFetchingUserInitiated) { value in
            isFetchingUserInitiated = value
        }
        
        
    }
    
    @MainActor func guts(containerGeometry: GeometryProxy) -> some View {
        
        let containerFrame = containerGeometry.frame(in: .global)
        let geometryWidth = containerFrame.width
        let geometryHeight = containerFrame.height
        
        //
        // This is a little bit tricky. We have bundled the
        // error and no items view in with the scroll view.
        // The loading view is really only there for the
        // initial load. Once we get an item or an error,
        // all the loading will be done with the pull-refresh.
        
        var isLoadingViewShowing = false
        if isAnyItemPresent {
            
        } else {
            if isFetching {
                isLoadingViewShowing = true
            }
        }
        
        if isFetchingDetails {
            isLoadingViewShowing = true
        }
        
        if isFirstFetchComplete == false {
            isLoadingViewShowing = true
        }
        
        if isFetchingUserInitiated {
            isLoadingViewShowing = true
        }
        
        return ZStack {
            CommunityGridViewControllerRepresentable(communityViewModel: communityViewModel,
                                                     width: geometryWidth,
                                                     height: geometryHeight)
            if isLoadingViewShowing {
                FullScreenLoadingView()
            }
        }
        .frame(width: geometryWidth, height: geometryHeight)
    }
    
    @MainActor func getLogoBarContainer(logoBarHeight: CGFloat) -> some View {
        HStack(spacing: 0.0) {
            GeometryReader { geometry in
                getLogoBar(width: geometry.size.width,
                           height: geometry.size.height)
            }
        }
        .frame(height: CGFloat(logoBarHeight))
    }
    
    @MainActor func getFooterBar(bottomBarHeight: CGFloat) -> some View {
        ZStack {
            HStack {
                Spacer()
                VStack {
                    Spacer()
                }
                Spacer()
            }
            Button {
                Task {
                    await communityViewModel.forceFetchPopularMovies()
                }
            } label: {
                ZStack {
                    Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                        .renderingMode(.template)
                        .font(.system(size: CGFloat(min(bottomBarHeight - 14, 22))))
                        .foregroundStyle(DarkwingDuckTheme.naughtyYellow)
                }
                .frame(width: bottomBarHeight + (bottomBarHeight * 0.5),
                       height: bottomBarHeight)
            }
            .opacity(isShowingNetworkError ? 1.0 : 0.0)
            .scaleEffect(isShowingNetworkError ? 1.0 : 0.85)
            .animation(.easeInOut, value: isShowingNetworkError)

            
        }
        .frame(height: CGFloat(bottomBarHeight))
        .background(DarkwingDuckTheme.gray100)
    }
    
    @MainActor func getLogoBar(width: CGFloat, height: CGFloat) -> some View {
        
        let logoMainBodyWidth = 1024
        let logoMainBodyHeight = 158
        
        let fitZoneWidth = (width - 64)
        let fitZoneHeight = (height - 16)
        let mainBodySize = CGSize(width: CGFloat(logoMainBodyWidth),
                                  height: CGFloat(logoMainBodyHeight))
        let fit = CGSize(width: CGFloat(fitZoneWidth), height: CGFloat(fitZoneHeight)).getAspectFit(mainBodySize)
        let scale = fit.scale
        
        return ZStack {
            Button(action: {
                Task {
                    await communityViewModel.debugInvalidateState()
                }
            }, label: {
                Image(uiImage: DarkwingDuckTheme.logo)
                    .scaleEffect(scale)
            })
        }
        .frame(width: width, height: height)
        .background(DarkwingDuckTheme.gray100)
    }
}
