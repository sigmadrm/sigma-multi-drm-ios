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
        SigmaMultiDRM.shared().userId = "tvos-user"
        SigmaMultiDRM.shared().merchantId = "sigma"
        SigmaMultiDRM.shared().appId = "sctv"
        SigmaMultiDRM.shared().sessionId = "tvos-session"
        SigmaMultiDRM.shared().setDebugMode(true) // Lấy URL Staging
        
        // Tạo Asset DRM (Sử dụng luồng demo hiện tại)
        let assetUrl = "https://fps.sigmadrm.com/dash/sctv/RedTV.m3u8"
        if let asset = SigmaMultiDRM.shared().asset(withUrl: assetUrl) {
            let playerItem = AVPlayerItem(asset: asset)
            self.player = AVPlayer(playerItem: playerItem)
        }
    }
}

#Preview {
    ContentView()
}
