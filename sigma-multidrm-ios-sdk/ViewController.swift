import UIKit
import AVKit
import SigmaMultiDRMFramework

class ViewController: UIViewController {
    // MARK: - UI Outlets
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var initialBtn: UIButton!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var nextBtn: UIButton!

    // MARK: - Player Properties
    var player: AVPlayer!
    var playerViewController: AVPlayerViewController!

    // MARK: - Media Data
    struct MediaItem {
        let manifestUrl: String
        let merchantId: String
        let appId: String
        let userId: String
        let sessionId: String
    }

    var mediaItems: [MediaItem] = []
    var currentIndex: Int = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        playBtn.isEnabled = false
        nextBtn.isEnabled = false

        mediaItems = [
            MediaItem(
                manifestUrl: "https://sdrm-test.gviet.vn:9080/static/vod_production/big_bug_bunny/master.m3u8",
                merchantId: "sigma_packager_lite",
                appId: "demo",
                userId: "fairplay_userId",
                sessionId: "fairplay_sessionId"
            ),
            MediaItem(
                manifestUrl: "https://sdrm-test.gviet.vn:9080/static/vod_production/godzilla_kong/master.m3u8",
                merchantId: "sigma_packager_lite",
                appId: "demo",
                userId: "fairplay_userId",
                sessionId: "fairplay_sessionId"
            )
        ]
        currentIndex = 0
    }

    // MARK: - Actions
    @IBAction func initialize(_ sender: UIButton) {
        initializePlayer()
        initialBtn.isEnabled = false
        playBtn.isEnabled = true
        nextBtn.isEnabled = true
    }

    @IBAction func play(_ sender: UIButton) {
        playCurrentIndex()
    }

    @IBAction func next(_ sender: UIButton) {
        currentIndex += 1
        if currentIndex == mediaItems.count {
            currentIndex = 0
        }
        playCurrentIndex()
    }

    // MARK: - Player Setup
    func initializePlayer() {
        player = AVPlayer()
        initializeWithAVPlayerViewController()
    }

    func initializeWithAVPlayerViewController() {
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true

        addChild(playerViewController)
        playerViewController.view.frame = videoContainerView.bounds
        videoContainerView.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
    }

    // MARK: - Play Logic
    func playCurrentIndex() {
        let item = mediaItems[currentIndex]
        print("-----------------------------------");
        print("Manifest URL: \(item.manifestUrl)")
        print("Merchant ID: \(item.merchantId)")
        print("App ID: \(item.appId)")
        print("User ID: \(item.userId)")
        print("Session ID: \(item.sessionId)")

        let sigmaSdk = SigmaMultiDRM.getInstance()
        sigmaSdk.setMerchant(item.merchantId)
        sigmaSdk.setAppId(item.appId)
        sigmaSdk.setUserId(item.userId)
        sigmaSdk.setSessionId(item.sessionId)
        sigmaSdk.setDebugMode(false)

        let asset = sigmaSdk.asset(withUrl: item.manifestUrl)
        let currentItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: currentItem)
        player.play()
    }
}
