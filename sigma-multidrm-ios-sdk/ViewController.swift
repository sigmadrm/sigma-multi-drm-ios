import UIKit
import AVKit
import SigmaMultiDRMFramework

class ViewController: UIViewController, SigmaMultiDRMDelegate {
    // MARK: - UI Outlets
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var mediaTitleLabel: UILabel!
    @IBOutlet weak var initialBtn: UIButton!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var nextBtn: UIButton!

    // MARK: - Player Properties
    var player: AVPlayer!
    var playerViewController: AVPlayerViewController!

    // MARK: - Media Data
    enum SmEnvironment {
        case production
        case staging
    }

    struct MediaItem {
        let title: String
        let manifestUrl: String
        let merchantId: String
        let appId: String
        let userId: String
        let sessionId: String
        let env: SmEnvironment
    }

    var mediaItems: [MediaItem] = []
    var currentIndex: Int = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        playBtn.isEnabled = false
        nextBtn.isEnabled = false

        mediaItems = [
            // staging
            MediaItem(
                title: "The Box (staging)",
                manifestUrl: "https://sdrm-test.gviet.vn:9080/drm/static/vod_staging/the_box/master.m3u8",
                merchantId: "sctv",
                appId: "RedTV",
                userId: "renew_license_userId",
                sessionId: "renew_license_sessionId",
                env: .staging
            ),
            MediaItem(
                title: "Big Buck Bunny (Staging)",
                manifestUrl: "https://sdrm-test.gviet.vn:9080/drm/static/vod_staging/big_bug_bunny/master.m3u8",
                merchantId: "sctv",
                appId: "RedTV",
                userId: "renew_license_userId",
                sessionId: "renew_license_sessionId",
                env: .staging
            ),
            // production
            MediaItem(
                title: "Big Buck Bunny (production)",
                manifestUrl: "https://sdrm-test.gviet.vn:9080/drm/static/vod_production/big_bug_bunny/master.m3u8",
                merchantId: "sigma_packager_lite",
                appId: "demo",
                userId: "fairplay_userId",
                sessionId: "fairplay_sessionId",
                env: .production
            ),
            MediaItem(
                title: "Godzilla x Kong (production)",
                manifestUrl: "https://sdrm-test.gviet.vn:9080/drm/static/vod_production/godzilla_kong/master.m3u8",
                merchantId: "sigma_packager_lite",
                appId: "demo",
                userId: "fairplay_userId",
                sessionId: "fairplay_sessionId",
                env: .production
            ),
        ]
        currentIndex = 0
        mediaTitleLabel.text = mediaItems.first?.title ?? "—"
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
        SigmaMultiDRM.getInstance().delegate = self;
        
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
        print("Title: \(item.title)")
        print("Manifest URL: \(item.manifestUrl)")
        print("Merchant ID: \(item.merchantId)")
        print("App ID: \(item.appId)")
        print("User ID: \(item.userId)")
        print("Session ID: \(item.sessionId)")
        print("Env: \(item.env == .staging ? "staging" : "production")")

        mediaTitleLabel.text = item.title

        let sigmaSdk = SigmaMultiDRM.getInstance()
        sigmaSdk.setMerchant(item.merchantId)
        sigmaSdk.setAppId(item.appId)
        sigmaSdk.setUserId(item.userId)
        sigmaSdk.setSessionId(item.sessionId)
        sigmaSdk.setDebugMode(item.env == .staging)

        let asset = sigmaSdk.asset(withUrl: item.manifestUrl)
        let currentItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: currentItem)
        player.play()
    }
    
    
  
    // MARK: - SigmaMultiDRMDelegate Methods
    
    /**
     * Called when license request completes (success or failure)
     */
    func didCompleteLicenseRequest(forAssetUrl assetUrl: String, license licenseData: Data?, response: URLResponse?, error: Error?) {
        // Log HTTP response information
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 HTTP Response:")
            print("   Status Code: \(httpResponse.statusCode)")
        }
        
        if error != nil {
            print("❌ License request failed")
            print("   Asset URL: \(assetUrl)")
            print("   Error: \(String(describing: error?.localizedDescription))")
            
            // Handle license request failure
            DispatchQueue.main.async {
                // Show error to user
                self.showErrorAlert(error?.localizedDescription ?? "Request License Error")
                self.playBtn.isEnabled = false
            }
        }
        
        if let licenseData = licenseData {
            print("✅ License received successfully")
            print("   Asset URL: \(assetUrl)")
            print("   License data size: \(licenseData.count) bytes")
            
            // Convert license data to JSON string
            let licenseJsonString = self.convertDataToJsonString(licenseData)
            print("   License JSON: \(licenseJsonString)")
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Convert Data to JSON string for logging
     */
    private func convertDataToJsonString(_ data: Data) -> String {
        do {
            // Try to parse as JSON first
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
                return String(data: jsonData, encoding: .utf8) ?? "Unable to convert to string"
            }
        } catch {
            // If not valid JSON, try as plain string
            if let stringData = String(data: data, encoding: .utf8) {
                return stringData
            }
        }
        
        // If all else fails, return base64 representation
        return "Base64: \(data.base64EncodedString())"
    }
    
    
    // MARK: - Error Handling
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "License Error", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
