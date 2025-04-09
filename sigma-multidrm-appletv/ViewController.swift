import UIKit
import AVKit
import SigmaMultiDRMFramework

class ViewController: UIViewController {
    
    var sdk: SigmaMultiDRM!
    var playerViewController: AVPlayerViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSigmaDRM()
        setupPlayer()
    }
    
    private func setupSigmaDRM() {
        sdk = SigmaMultiDRM()
        sdk.setMerchant("sctv")
        sdk.setAppId("RedTV")
        sdk.setUserId("fairplay_userId")
        sdk.setSessionId("fairplay_sessionId")
        sdk.setDebugMode(true)
    }
    
    private func setupPlayer() {
        let urlString = "https://sdrm-test.gviet.vn:9080/static/vod_staging/the_box/master.m3u8";
        guard let url = URL(string: urlString) else {
            print("⚠️ Lỗi: URL không hợp lệ")
            return
        }
        
        if let asset = sdk.asset(withUrl: url.absoluteString) as AVURLAsset? {
            prepareToPlayAsset(asset)
        } else {
            print("⚠️ Lỗi: Không thể tạo asset từ URL.")
        }
    }
    
    private func prepareToPlayAsset(_ asset: AVURLAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 1.0
        
        let player = AVPlayer(playerItem: playerItem)
        
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
            // Thêm AVPlayerViewController vào ViewController chính
        addChild(playerViewController)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(playerViewController.view)
        
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        playerViewController.didMove(toParent: self)
        
            // Phát video
        player.play()
    }
}
