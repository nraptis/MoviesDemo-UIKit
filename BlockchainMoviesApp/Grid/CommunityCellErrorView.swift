//
//  CommunityCellErrorView.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/21/24.
//

import SwiftUI

struct CommunityCellErrorView: View {
    
    var retryHandler: () -> Void
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0.0) {
                
                Spacer(minLength: 0.0)
                
                ZStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: Device.isPad ? 32 : 24))
                        .foregroundStyle(DarkwingDuckTheme.naughtyYellow)
                        
                }
                .frame(width: Device.isPad ? 56.0 : 44.0,
                       height: Device.isPad ? 56.0 : 44.0)
                Button {
                    
                    retryHandler()
                    
                    /*
                    Task { @MainActor in
                        await communityViewModel.handleCellForceRetryDownload(at: gridCellModel.layoutIndex)
                    }
                    */
                    
                } label: {
                    VStack(spacing: 0.0) {
                        
                        ZStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: Device.isPad ? 32 : 24))
                                .foregroundStyle(DarkwingDuckTheme.gray800)
                        }
                        .frame(width: Device.isPad ? 56.0 : 44.0,
                               height: Device.isPad ? 56.0 : 44.0)
                        .background(ZStack {
                            RoundedRectangle(cornerRadius: CommunityCellConstants.buttonRadius).foregroundStyle(DarkwingDuckTheme.gray800)
                                .frame(width: (Device.isPad ? 56.0 : 44.0),
                                       height: (Device.isPad ? 56.0 : 44.0))
                            RoundedRectangle(cornerRadius: CommunityCellConstants.buttonRadius).foregroundStyle(DarkwingDuckTheme.gray300)
                                .frame(width: (Device.isPad ? 56.0 : 44.0) - 4.0,
                                       height: (Device.isPad ? 56.0 : 44.0) - 4.0)
                        })
                    }
                }
                
                ZStack {
                    
                }
                .frame(width: Device.isPad ? 56.0 : 44.0,
                       height: Device.isPad ? 56.0 : 44.0)
                
                Spacer(minLength: 0.0)
            }
            .frame(width: geometry.size.width,
                   height: geometry.size.height)
            //.background(DarkwingDuckTheme.gray200)
        }
    }
}
