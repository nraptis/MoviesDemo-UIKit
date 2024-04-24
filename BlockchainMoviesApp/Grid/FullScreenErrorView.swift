//
//  ErrorView.swift
//  BlockchainMoviesApp
//
//  Created by Nicholas Alexander Raptis on 4/22/24.
//

import SwiftUI

//
// This is not used, but it looks pretty good.
// I am keeping it in case we want to use it.
//
struct FullScreenErrorView: View {
    let text: String
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    VStack(spacing: Device.isPad ? 12.0 : 8.0) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: Device.isPad ? 56 : 44.0))
                        HStack {
                            Text(text)
                                .font(.system(size: Device.isPad ? 20.0 : 16.0, weight: .semibold))
                        }
                        .frame(maxWidth: Device.isPad ? 240.0 : 180.0)
                    }
                    .foregroundColor(DarkwingDuckTheme.gray800)
                }
                .frame(width: Device.isPad ? 320.0 : 220.0,
                       height: Device.isPad ? 320.0 : 220.0)
                .background(RoundedRectangle(cornerRadius: 16.0).foregroundStyle(DarkwingDuckTheme.gray150))
                Spacer()
            }
            Spacer()
        }
    }
}
