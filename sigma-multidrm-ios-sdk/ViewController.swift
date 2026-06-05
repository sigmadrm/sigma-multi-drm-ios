import UIKit
import AVKit
import SigmaMultiDRMFramework

class ViewController: UIViewController, SigmaMultiDRMDelegate {
    
    // MARK: - UI Components
    let scrollView = UIScrollView()
    let contentView = UIView()
    
    let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "SigmaDRM Premium Demo"
        lbl.font = UIFont.boldSystemFont(ofSize: 20)
        lbl.textColor = .white
        return lbl
    }()
    
    // Player Header
    let playerConfigLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Player Configuration"
        lbl.font = UIFont.boldSystemFont(ofSize: 14)
        lbl.textColor = .white
        return lbl
    }()
    let timeLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "00:00 / 00:00"
        lbl.font = UIFont.systemFont(ofSize: 12)
        lbl.textColor = .lightGray
        return lbl
    }()
    let resetBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Reset App", for: .normal)
        btn.setTitleColor(.systemRed, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        btn.backgroundColor = UIColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1)
        btn.layer.cornerRadius = 4
        return btn
    }()
    
    let videoContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.layer.cornerRadius = 8
        v.clipsToBounds = true
        return v
    }()
    
    // Controls
    static func createControlButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 4
        return btn
    }
    
    let playBtn = createControlButton(title: "▶ PLAY", color: UIColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 1))
    let pauseBtn = createControlButton(title: "⏸ PAUSE", color: UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1))
    let seekBackBtn = createControlButton(title: "⏪ SEEK -10S", color: UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1))
    let seekFwdBtn = createControlButton(title: "⏩ SEEK +10S", color: UIColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1))
    let muteBtn = createControlButton(title: "🔇 TẮT ÂM", color: UIColor(red: 0.2, green: 0.4, blue: 0.4, alpha: 1))
    
    let startBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("START", for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.9, alpha: 1)
        btn.layer.cornerRadius = 4
        return btn
    }()
    
    // Inputs
    static func createTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor.gray])
        tf.textColor = .white
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.borderStyle = .none
        tf.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        let bottomLine = UIView()
        bottomLine.backgroundColor = .darkGray
        tf.addSubview(bottomLine)
        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomLine.leadingAnchor.constraint(equalTo: tf.leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: tf.trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: tf.bottomAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return tf
    }
    
    let manifestTF = createTextField(placeholder: "Manifest URI")
    let baseUrlTF = createTextField(placeholder: "Base URL")
    let merchantIdTF = createTextField(placeholder: "Merchant Id")
    let appIdTF = createTextField(placeholder: "App Id")
    let userIdTF = createTextField(placeholder: "User Id")
    let sessionIdTF = createTextField(placeholder: "Session Id")
    
    static func createLabel(text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 10)
        lbl.textColor = .gray
        return lbl
    }
    
    func createInputBlock(title: String, tf: UITextField) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [ViewController.createLabel(text: title), tf])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }
    
    // Logs
    let logsTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Logs"
        lbl.font = UIFont.boldSystemFont(ofSize: 16)
        lbl.textColor = .white
        return lbl
    }()
    let clearLogsBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Clear Logs", for: .normal)
        btn.setTitleColor(.lightGray, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        btn.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1)
        btn.layer.cornerRadius = 4
        return btn
    }()
    let logTextView: UITextView = {
        let tv = UITextView()
        tv.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        tv.textColor = .green
        tv.font = UIFont(name: "Menlo", size: 12) ?? UIFont.systemFont(ofSize: 12)
        tv.isEditable = false
        tv.layer.cornerRadius = 4
        tv.layoutManager.allowsNonContiguousLayout = false
        return tv
    }()
    
    // MARK: - Player Properties
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    
    var statusObservation: NSKeyValueObservation?
    var timeControlObservation: NSKeyValueObservation?
    var timeObserverToken: Any?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playback)
            }
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        setupUI()
        resetFields()
        setupActions()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDRMLog(_:)), name: NSNotification.Name("SigmaDRMLogEvent"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc func appDidEnterBackground() {
        playerViewController?.player = nil
    }
    
    @objc func appWillEnterForeground() {
        playerViewController?.player = player
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removePlayerObservers()
    }
    
    // MARK: - Setup UI
    func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.13, alpha: 1)
        
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Assemble Content
        let playerBox = UIView()
        playerBox.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
        playerBox.layer.cornerRadius = 8
        
        let headerStack = UIStackView(arrangedSubviews: [playerConfigLabel, UIView(), timeLabel, resetBtn])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8
        resetBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        resetBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        let playPauseStack = UIStackView(arrangedSubviews: [playBtn, pauseBtn])
        playPauseStack.axis = .horizontal
        playPauseStack.spacing = 16
        playPauseStack.distribution = .fillEqually
        playBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        pauseBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        let seekStack = UIStackView(arrangedSubviews: [seekBackBtn, seekFwdBtn, muteBtn])
        seekStack.axis = .horizontal
        seekStack.spacing = 16
        seekStack.distribution = .fillEqually
        seekBackBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        seekFwdBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        muteBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        startBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        let inputsStack = UIStackView(arrangedSubviews: [
            createInputBlock(title: "Manifest URI", tf: manifestTF),
            createInputBlock(title: "Base URL", tf: baseUrlTF),
            {
                let hStack = UIStackView(arrangedSubviews: [createInputBlock(title: "Merchant Id", tf: merchantIdTF), createInputBlock(title: "App Id", tf: appIdTF)])
                hStack.axis = .horizontal; hStack.spacing = 16; hStack.distribution = .fillEqually; return hStack
            }(),
            {
                let hStack = UIStackView(arrangedSubviews: [createInputBlock(title: "User Id", tf: userIdTF), createInputBlock(title: "Session Id", tf: sessionIdTF)])
                hStack.axis = .horizontal; hStack.spacing = 16; hStack.distribution = .fillEqually; return hStack
            }()
        ])
        inputsStack.axis = .vertical
        inputsStack.spacing = 16
        
        let logsHeaderStack = UIStackView(arrangedSubviews: [logsTitleLabel, UIView(), clearLogsBtn])
        logsHeaderStack.axis = .horizontal
        logsHeaderStack.alignment = .center
        clearLogsBtn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        clearLogsBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        logTextView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        // Layout into playerBox
        playerBox.addSubview(headerStack)
        playerBox.addSubview(videoContainerView)
        playerBox.addSubview(playPauseStack)
        playerBox.addSubview(seekStack)
        playerBox.addSubview(startBtn)
        
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false
        playPauseStack.translatesAutoresizingMaskIntoConstraints = false
        seekStack.translatesAutoresizingMaskIntoConstraints = false
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: playerBox.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: playerBox.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: playerBox.trailingAnchor, constant: -12),
            
            videoContainerView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            videoContainerView.leadingAnchor.constraint(equalTo: playerBox.leadingAnchor, constant: 12),
            videoContainerView.trailingAnchor.constraint(equalTo: playerBox.trailingAnchor, constant: -12),
            videoContainerView.heightAnchor.constraint(equalTo: videoContainerView.widthAnchor, multiplier: 9.0/16.0),
            
            playPauseStack.topAnchor.constraint(equalTo: videoContainerView.bottomAnchor, constant: 16),
            playPauseStack.centerXAnchor.constraint(equalTo: playerBox.centerXAnchor),
            playPauseStack.widthAnchor.constraint(equalToConstant: 240),
            
            seekStack.topAnchor.constraint(equalTo: playPauseStack.bottomAnchor, constant: 16),
            seekStack.leadingAnchor.constraint(equalTo: playerBox.leadingAnchor, constant: 32),
            seekStack.trailingAnchor.constraint(equalTo: playerBox.trailingAnchor, constant: -32),
            
            startBtn.topAnchor.constraint(equalTo: seekStack.bottomAnchor, constant: 24),
            startBtn.leadingAnchor.constraint(equalTo: playerBox.leadingAnchor, constant: 12),
            startBtn.trailingAnchor.constraint(equalTo: playerBox.trailingAnchor, constant: -12),
            startBtn.bottomAnchor.constraint(equalTo: playerBox.bottomAnchor, constant: -16)
        ])
        
        // Add to contentView
        contentView.addSubview(titleLabel)
        contentView.addSubview(playerBox)
        contentView.addSubview(inputsStack)
        contentView.addSubview(logsHeaderStack)
        contentView.addSubview(logTextView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        playerBox.translatesAutoresizingMaskIntoConstraints = false
        inputsStack.translatesAutoresizingMaskIntoConstraints = false
        logsHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            playerBox.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            playerBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            playerBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            inputsStack.topAnchor.constraint(equalTo: playerBox.bottomAnchor, constant: 24),
            inputsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            inputsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            logsHeaderStack.topAnchor.constraint(equalTo: inputsStack.bottomAnchor, constant: 32),
            logsHeaderStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logsHeaderStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            logTextView.topAnchor.constraint(equalTo: logsHeaderStack.bottomAnchor, constant: 8),
            logTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            logTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        // Hide keyboard on tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Actions
    func setupActions() {
        startBtn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        playBtn.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        pauseBtn.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
        seekBackBtn.addTarget(self, action: #selector(seekBackTapped), for: .touchUpInside)
        seekFwdBtn.addTarget(self, action: #selector(seekFwdTapped), for: .touchUpInside)
        muteBtn.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        resetBtn.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        clearLogsBtn.addTarget(self, action: #selector(clearLogsTapped), for: .touchUpInside)
    }
    
    func resetFields() {
        manifestTF.text = "https://sdrm-test.gviet.vn:9080/drm/static/vod_staging/the_box/master.m3u8"
        baseUrlTF.text = "https://license-staging.sigmadrm.com/license/verify/fairplay"
        merchantIdTF.text = "sctv"
        appIdTF.text = "RedTV"
        userIdTF.text = "U_Pnh_Ios"
        sessionIdTF.text = "S_Pnh_Ios"
    }
    
    @objc func resetTapped() {
        logToUI("--- APP RESET ---")
        releasePlayer()
        resetFields()
        logTextView.text = ""
        timeLabel.text = "00:00 / 00:00"
    }
    
    @objc func startTapped() {
        dismissKeyboard()
        releasePlayer()
        logToUI(">>> ACTION: Start initializing DRM Asset")
        
        let manifest = manifestTF.text ?? ""
        let merchantId = merchantIdTF.text ?? ""
        let appId = appIdTF.text ?? ""
        let userId = userIdTF.text ?? ""
        let sessionId = sessionIdTF.text ?? ""
        
        let sigmaSdk = SigmaMultiDRM.getInstance()
        sigmaSdk.delegate = self
        sigmaSdk.setMerchant(merchantId)
        sigmaSdk.setAppId(appId)
        sigmaSdk.setUserId(userId)
        sigmaSdk.setSessionId(sessionId)
        sigmaSdk.setDebugMode(true) // DebugMode = true for staging
        
        let asset = sigmaSdk.asset(withUrl: manifest)
        
        let currentItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: currentItem)
        
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.showsPlaybackControls = false // Using custom controls
        playerViewController?.allowsPictureInPicturePlayback = true
        
        if let pvc = playerViewController {
            addChild(pvc)
            pvc.view.frame = videoContainerView.bounds
            videoContainerView.addSubview(pvc.view)
            pvc.didMove(toParent: self)
        }
        
        setupPlayerObservers()
        player?.play()
    }
    
    @objc func playTapped() {
        player?.play()
    }
    
    @objc func pauseTapped() {
        player?.pause()
    }
    
    @objc func seekBackTapped() {
        guard let p = player else { return }
        let newTime = CMTimeGetSeconds(p.currentTime()) - 10.0
        let target = CMTimeMakeWithSeconds(max(0, newTime), preferredTimescale: 600)
        logToUI(">>> EVENT: Seek to \(Int(max(0, newTime)))s")
        p.seek(to: target)
    }
    
    @objc func seekFwdTapped() {
        guard let p = player, let duration = p.currentItem?.duration else { return }
        let newTime = CMTimeGetSeconds(p.currentTime()) + 10.0
        let maxTime = CMTimeGetSeconds(duration)
        if maxTime.isNaN { return }
        let target = CMTimeMakeWithSeconds(min(maxTime, newTime), preferredTimescale: 600)
        logToUI(">>> EVENT: Seek to \(Int(min(maxTime, newTime)))s")
        p.seek(to: target)
    }
    
    @objc func muteTapped() {
        guard let p = player else { return }
        p.isMuted = !p.isMuted
        if p.isMuted {
            muteBtn.setTitle("🔊 BẬT ÂM", for: .normal)
            muteBtn.backgroundColor = UIColor(red: 0.4, green: 0.2, blue: 0.2, alpha: 1)
        } else {
            muteBtn.setTitle("🔇 TẮT ÂM", for: .normal)
            muteBtn.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.4, alpha: 1)
        }
        logToUI(">>> EVENT: Mute state changed to \(p.isMuted)")
    }
    
    @objc func clearLogsTapped() {
        logTextView.text = ""
    }
    
    func releasePlayer() {
        removePlayerObservers()
        player?.pause()
        playerViewController?.view.removeFromSuperview()
        playerViewController?.removeFromParent()
        playerViewController = nil
        player = nil
    }
    
    // MARK: - Observers
    func setupPlayerObservers() {
        guard let p = player else { return }
        
        timeControlObservation = p.observe(\.rate, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            if player.rate == 0 {
                self.logToUI(">>> EVENT: Pause")
            } else {
                self.logToUI(">>> EVENT: Play")
            }
        }
        
        statusObservation = p.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .failed, let error = item.error {
                self.logToUI("!!! PLAYER ERROR: \(error.localizedDescription)")
            } else if item.status == .readyToPlay {
                self.logToUI(">>> EVENT: Player Ready to Play")
            }
        }
        
        let interval = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
        timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let duration = self.player?.currentItem?.duration else { return }
            let durSeconds = CMTimeGetSeconds(duration)
            let curSeconds = CMTimeGetSeconds(time)
            if durSeconds.isNaN || curSeconds.isNaN { return }
            self.timeLabel.text = "\(self.formatTime(curSeconds)) / \(self.formatTime(durSeconds))"
        }
    }
    
    func removePlayerObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Logging
    @objc func handleDRMLog(_ notification: Notification) {
        if let message = notification.userInfo?["message"] as? String {
            logToUI(message)
        }
    }
    
    func logToUI(_ message: String) {
        DispatchQueue.main.async {
            print(message)
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let timeStr = timeFormatter.string(from: Date())
            let line = "[\(timeStr)] \(message)\n"
            
            self.logTextView.text = (self.logTextView.text ?? "") + line
            
            // Scroll to bottom safely
            if self.logTextView.text.count > 0 {
                let bottom = NSMakeRange(self.logTextView.text.count - 1, 1)
                self.logTextView.scrollRangeToVisible(bottom)
            }
        }
    }
    
    // MARK: - SigmaMultiDRMDelegate Methods
    func didCompleteLicenseRequest(forAssetUrl assetUrl: String, license licenseData: Data?, response: URLResponse?, error: Error?) {
        if let httpResponse = response as? HTTPURLResponse {
            logToUI("🌐 HTTP Response Status Code: \(httpResponse.statusCode)")
        }
        
        if error != nil {
            logToUI("!!! DRM ERROR: License request failed. \(error?.localizedDescription ?? "")")
            DispatchQueue.main.async {
                self.showErrorAlert(error?.localizedDescription ?? "Request License Error")
            }
        }
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "License Error", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}
