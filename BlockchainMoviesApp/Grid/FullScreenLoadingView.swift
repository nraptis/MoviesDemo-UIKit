//
//  FullScreenLoadingView.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/22/24.
//

import SwiftUI

struct FullScreenLoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    ZStack {
                        
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(DarkwingDuckTheme.naughtyYellow)
                            .scaleEffect(Device.isPad ? 1.6 : 1.2)
                        
                    }
                    .frame(width: Device.isPad ? 78.0 : 64.0,
                           height: Device.isPad ? 78.0 : 64.0)
                    .background(RoundedRectangle(cornerRadius: 16.0).foregroundStyle(DarkwingDuckTheme.gray050))
                }
                .frame(width: Device.isPad ? 320.0 : 220.0,
                       height: Device.isPad ? 320.0 : 220.0)
                .background(RoundedRectangle(cornerRadius: 16.0).foregroundStyle(DarkwingDuckTheme.gray150))
                
                Spacer()
            }
            Spacer()
        }
        .background(DarkwingDuckTheme.gray050)
    }
}

#Preview {
    FullScreenLoadingView()
}
