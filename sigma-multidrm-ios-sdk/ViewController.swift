import UIKit
import AVKit
import SigmaMultiDRMFramework

class ViewController: UIViewController {
    var sdk: SigmaMultiDRM!
    var playerViewController: AVPlayerViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sdk = SigmaMultiDRM()
//        sdk.setMerchant("sctv")
//        sdk.setAppId("RedTV")
//        sdk.setUserId("fairplay_userId")
//        sdk.setSessionId("fairplay_sessionId")
//        sdk.setDebugMode(true)
//        let urlString = "https://sdrm-test.gviet.vn:9080/static/vod_staging/the_box/master.m3u8"
        
        sdk.setMerchant("sigma_packager_lite")
        sdk.setAppId("demo")
        sdk.setUserId("fairplay_userId")
        sdk.setSessionId("fairplay_sessionId")
        sdk.setDebugMode(false)
        let urlString = "https://sdrm-test.gviet.vn:9080/static/vod_production/big_bug_bunny/master.m3u8"
        
        // Tạo URL và chuẩn bị asset
        guard let url = URL(string: urlString) else { return }
        
        let asset = sdk.asset(withUrl: url.absoluteString)
        prepareToPlayAsset(asset)
    }
    
    func prepareToPlayAsset(_ asset: AVURLAsset) {
        // Tạo AVPlayerItem
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 1.0
        
        // Tạo AVPlayer và gán vào AVPlayerViewController
        let player = AVPlayer(playerItem: playerItem)
        
        // Tạo và cấu hình AVPlayerViewController
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        // Gán AVPlayerViewController vào ViewController hiện tại
        playerViewController.view.frame = self.view.bounds  // Đặt kích thước của playerViewController để phủ toàn bộ màn hình
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(playerViewController.view)  // Thêm view của playerViewController vào view chính của ViewController
        
        // Bắt đầu phát video khi AVPlayerViewController sẵn sàng
        self.playerViewController.player?.play()
    }
}
