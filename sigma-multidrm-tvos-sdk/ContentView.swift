//
//  ContentView.swift
//  sigma-multidrm-tvos-sdk
//
//  Created by Sigma Streaming on 6/6/26.
//

import SwiftUI
import AVKit

struct PlayerView: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

@available(tvOS 14.0, *)
struct ContentView: View {
    @State private var player: AVPlayer?
    
    var body: some View {
        Group {
            if let player = player {
                PlayerView(player: player)
                    .onAppear {
                        player.play()
                    }
            } else {
                VStack {
                    Text("Đang tải cấu hình DRM...")
                }
            }
        }
        .onAppear {
            setupDRMAndPlay()
        }
        .ignoresSafeArea()
    }
    
    func setupDRMAndPlay() {
        // Cấu hình DRM
        let sigmaSdk = SigmaMultiDRM.getInstance()
        sigmaSdk.setUserId("tvos-user")
        sigmaSdk.setMerchant("sigma")
        sigmaSdk.setAppId("sctv")
        sigmaSdk.setSessionId("tvos-session")
        sigmaSdk.setDebugMode(true) // Lấy URL Staging
        
        // Tạo Asset DRM (Sử dụng luồng demo hiện tại)
        let assetUrl = "https://fps.sigmadrm.com/dash/sctv/RedTV.m3u8"
        let asset = sigmaSdk.asset(withUrl: assetUrl)
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
    }
}

#Preview {
    if #available(tvOS 14.0, *) {
        ContentView()
    } else {
        // Fallback on earlier versions
    }
}
