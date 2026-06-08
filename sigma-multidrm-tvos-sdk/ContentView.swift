//
//  ContentView.swift
//  sigma-multidrm-tvos-sdk
//
//  Created by Sigma Streaming on 6/6/26.
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

struct PlayerView: UIViewControllerRepresentable {
    var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Custom controls used to replicate iOS
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

class ContentViewModel: NSObject, ObservableObject, SigmaMultiDRMDelegate {
    @Published var manifest: String = "https://sdrm-test.gviet.vn:9080/drm/static/vod_staging/the_box/master.m3u8"
    @Published var merchantId: String = "sctv"
    @Published var appId: String = "RedTV"
    @Published var userId: String = "U_Pnh_tvOS"
    @Published var sessionId: String = "S_Pnh_tvOS"
    
    @Published var player: AVPlayer?
    @Published var logs: String = ""
    @Published var isMuted: Bool = false
    @Published var currentTime: String = "00:00"
    @Published var durationTime: String = "00:00"
    
    private var timeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var playerDidPlayToEndObserverToken: Any?
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDRMLog(_:)), name: NSNotification.Name("SigmaDRMLogEvent"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removePlayerObservers()
    }
    
    @objc func handleDRMLog(_ notification: Notification) {
        if let message = notification.userInfo?["message"] as? String {
            logToUI(message)
        }
    }
    
    func logToUI(_ message: String) {
        DispatchQueue.main.async {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeStr = formatter.string(from: Date())
            let line = "[\(timeStr)] \(message)\n"
            self.logs += line
        }
    }
    
    func startDRMPlayback() {
        releasePlayer()
        logToUI(">>> ACTION: Bắt đầu cấu hình DRM và phát...")
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logToUI("!!! AUDIO SESSION ERROR: \(error.localizedDescription)")
        }
        
        let sigmaSdk = SigmaMultiDRM.getInstance()
        sigmaSdk.delegate = self
        sigmaSdk.setMerchant(merchantId)
        sigmaSdk.setAppId(appId)
        sigmaSdk.setUserId(userId)
        sigmaSdk.setSessionId(sessionId)
        sigmaSdk.setDebugMode(true) // staging mode (match iOS debug Mode)
        
        let asset = sigmaSdk.asset(withUrl: manifest)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        self.player = newPlayer
        
        setupPlayerObservers()
        newPlayer.play()
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func seek(seconds: Double) {
        guard let player = player else { return }
        let newTime = CMTimeGetSeconds(player.currentTime()) + seconds
        let target = CMTimeMakeWithSeconds(max(0, newTime), preferredTimescale: 600)
        logToUI(">>> EVENT: Seek tới \(Int(max(0, newTime)))s")
        player.seek(to: target)
    }
    
    func toggleMute() {
        guard let player = player else { return }
        player.isMuted = !player.isMuted
        isMuted = player.isMuted
        logToUI(">>> EVENT: Đổi trạng thái tắt tiếng thành \(player.isMuted)")
    }
    
    func reset() {
        releasePlayer()
        manifest = "https://sdrm-test.gviet.vn:9080/drm/static/vod_staging/the_box/master.m3u8"
        merchantId = "sctv"
        appId = "RedTV"
        userId = "U_Pnh_tvOS"
        sessionId = "S_Pnh_tvOS"
        logs = ""
        currentTime = "00:00"
        durationTime = "00:00"
        logToUI("--- RESET APP ---")
    }
    
    func clearLogs() {
        logs = ""
    }
    
    private func releasePlayer() {
        removePlayerObservers()
        player?.pause()
        player = nil
        SigmaMultiDRM.getInstance().releaseResources()
    }
    
    private func setupPlayerObservers() {
        guard let p = player else { return }
        
        rateObservation = p.observe(\.rate, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            if player.rate == 0 {
                self.logToUI(">>> EVENT: Tạm dừng phát (Pause)")
            } else {
                self.logToUI(">>> EVENT: Tiếp tục phát (Play)")
            }
        }
        
        statusObservation = p.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .failed, let error = item.error {
                self.logToUI("!!! PLAYER ERROR: \(error.localizedDescription)")
            } else if item.status == .readyToPlay {
                self.logToUI(">>> EVENT: Player Sẵn Sàng Phát (Ready to Play)")
            }
        }
        
        let interval = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
        timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let duration = self.player?.currentItem?.duration else { return }
            let durSeconds = CMTimeGetSeconds(duration)
            let curSeconds = CMTimeGetSeconds(time)
            if durSeconds.isNaN || curSeconds.isNaN { return }
            self.currentTime = self.formatTime(curSeconds)
            self.durationTime = self.formatTime(durSeconds)
        }
        
        playerDidPlayToEndObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.logToUI(">>> EVENT: Video đã phát hết. Tự động giải phóng Player...")
            self?.releasePlayer()
        }
    }
    
    private func removePlayerObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        rateObservation?.invalidate()
        rateObservation = nil
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        if let token = playerDidPlayToEndObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerDidPlayToEndObserverToken = nil
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - SigmaMultiDRMDelegate
    func didCompleteLicenseRequest(forAssetUrl assetUrl: String, license licenseData: Data?, response: URLResponse?, error: Error?) {
        if let httpResponse = response as? HTTPURLResponse {
            logToUI("🌐 HTTP Response Status Code: \(httpResponse.statusCode)")
        }
        
        if let error = error {
            logToUI("!!! DRM ERROR: Yêu cầu license thất bại: \(error.localizedDescription)")
        }
    }
}

struct InputField: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.gray)
            TextField(title, text: $text)
                .font(.system(size: 26))
                .textFieldStyle(DefaultTextFieldStyle())
        }
    }
}

@available(tvOS 14.0, *)
struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        HStack(spacing: 50) {
            // CỘT TRÁI: CẤU HÌNH & BỘ ĐIỀU KHIỂN
            VStack(alignment: .leading, spacing: 25) {
                // Header
                Text("SigmaDRM tvOS Premium Demo")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Nhóm các thông số
                        VStack(alignment: .leading, spacing: 15) {
                            InputField(title: "Manifest URI", text: $viewModel.manifest)
                            InputField(title: "Merchant Id", text: $viewModel.merchantId)
                            InputField(title: "App Id", text: $viewModel.appId)
                            
                            HStack(spacing: 20) {
                                InputField(title: "User Id", text: $viewModel.userId)
                                InputField(title: "Session Id", text: $viewModel.sessionId)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.15))
                        .cornerRadius(12)
                        
                        // Nhóm các nút điều khiển
                        VStack(spacing: 15) {
                            Button(action: {
                                viewModel.startDRMPlayback()
                            }) {
                                Text("▶ START INITIALIZING DRM ASSET")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .background(Color(red: 0.2, green: 0.3, blue: 0.7))
                            .cornerRadius(8)
                            
                            HStack(spacing: 15) {
                                Button(action: {
                                    viewModel.play()
                                }) {
                                    Text("▶ PLAY")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .background(Color(red: 0.15, green: 0.45, blue: 0.3))
                                .cornerRadius(8)
                                
                                Button(action: {
                                    viewModel.pause()
                                }) {
                                    Text("⏸ PAUSE")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .background(Color(red: 0.45, green: 0.35, blue: 0.15))
                                .cornerRadius(8)
                            }
                            
                            HStack(spacing: 15) {
                                Button(action: {
                                    viewModel.seek(seconds: -10)
                                }) {
                                    Text("⏪ SEEK -10S")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .background(Color(red: 0.2, green: 0.35, blue: 0.45))
                                .cornerRadius(8)
                                
                                Button(action: {
                                    viewModel.seek(seconds: 10)
                                }) {
                                    Text("⏩ SEEK +10S")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .background(Color(red: 0.2, green: 0.35, blue: 0.45))
                                .cornerRadius(8)
                            }
                            
                            HStack(spacing: 15) {
                                Button(action: {
                                    viewModel.toggleMute()
                                }) {
                                    Text(viewModel.isMuted ? "🔊 BẬT ÂM" : "🔇 TẮT ÂM")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .background(Color(red: 0.2, green: 0.45, blue: 0.45))
                                .cornerRadius(8)
                                
                                Button(action: {
                                    viewModel.reset()
                                }) {
                                    Text("RESET APP")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                }
                                .background(Color(red: 0.35, green: 0.1, blue: 0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .frame(width: 720)
            
            // CỘT PHẢI: PLAYER & LOG CONSOLE
            VStack(spacing: 25) {
                // Khung trình phát Video
                ZStack {
                    if let player = viewModel.player {
                        PlayerView(player: player)
                            .frame(height: 405) // Aspect ratio 16:9 cho width 720
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray, lineWidth: 2))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                            .frame(height: 405)
                            .overlay(
                                VStack(spacing: 15) {
                                    Image(systemName: "tv.music.note")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                    Text("Chưa tải luồng phát video")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                }
                
                // Hiển thị thời lượng
                HStack {
                    Text("\(viewModel.currentTime) / \(viewModel.durationTime)")
                        .font(.system(size: 22, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 5)
                
                // Console Log
                VStack(alignment: .leading, spacing: 10) {
                     HStack {
                        Text("DRM Client Logs")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            viewModel.clearLogs()
                        }) {
                            Text("Clear Logs")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    ScrollView {
                        Text(viewModel.logs.isEmpty ? "Không có log mới. Bấm START để theo dõi luồng DRM..." : viewModel.logs)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .background(Color(white: 0.05))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(12)
            }
        }
        .padding(50)
        .background(Color(white: 0.08).ignoresSafeArea())
    }
}

#Preview {
    if #available(tvOS 14.0, *) {
        ContentView()
    } else {
        // Fallback on earlier versions
    }
}
