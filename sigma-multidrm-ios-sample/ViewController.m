//
//  ViewController.m
//  sigma-multidrm-ios-sample
//
//  Created by DinhPhuc on 10/07/2025.
//

#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <AVKit/AVKit.h>
#import <CoreMedia/CoreMedia.h>

#import "ViewController.h"
#import <SigmaMultiDRMFramework/SigmaMultiDRMFramework.h>

@interface ViewController ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, weak) IBOutlet UIView *videoContainerView;
@property (nonatomic, strong) AVPlayerViewController *playerViewController;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@property (weak, nonatomic) IBOutlet UIButton *initialBtn;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *nextBtn;

@property (nonatomic, strong) NSArray<NSDictionary *> *mediaItems;
@property (nonatomic, assign) NSInteger currentIndex;

- (void) playCurrentIndex;
- (void) initializePlayer;
- (void) initializeWithAVPlayerViewController;
- (void) initializeWithAVPlayerLayer;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.playBtn.enabled = NO;
    self.nextBtn.enabled = NO;
    
    self.mediaItems = @[
        @{
            @"manifestUrl": @"____",
            @"drmInfo": @{
                @"appId": @"______",
                @"merchantId": @"_____",
                @"userId": @"______",
                @"sessionId": @"_____"
            }
        }
    ];
    
    self.mediaItems = @[
        @{
            @"manifestUrl": @"https://sdrm-test.gviet.vn:9080/static/vod_production/big_bug_bunny/master.m3u8",
            @"drmInfo": @{
                @"merchantId": @"sigma_packager_lite",
                @"appId": @"demo",
                @"userId": @"fairplay_userId",
                @"sessionId": @"fairplay_sessionId"
            }
        },
        @{
            @"manifestUrl": @"https://sdrm-test.gviet.vn:9080/static/vod_production/godzilla_kong/master.m3u8",
            @"drmInfo": @{
                @"merchantId": @"sigma_packager_lite",
                @"appId": @"free_trial",
                @"userId": @"fairplay_userId",
                @"sessionId": @"fairplay_sessionId"
            }
        }
    ];

    self.currentIndex = 0;
}

- (IBAction)initialize:(id)sender {
    [self initializePlayer];
    
    self.initialBtn.enabled = NO;
    self.playBtn.enabled = YES;
    self.nextBtn.enabled = YES;
}

- (void) initializePlayer {
    self.player = [[AVPlayer alloc] init];
    
//    [self initializeWithAVPlayerLayer];
    [self initializeWithAVPlayerViewController];
}

- (void)initializeWithAVPlayerViewController {
    self.playerViewController = [[AVPlayerViewController alloc] init];
    self.playerViewController.player = self.player;
    self.playerViewController.showsPlaybackControls = YES;

    [self addChildViewController:self.playerViewController];
    self.playerViewController.view.frame = self.videoContainerView.bounds;
    [self.videoContainerView addSubview:self.playerViewController.view];
}

- (void)initializeWithAVPlayerLayer {
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = self.videoContainerView.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    [self.videoContainerView.layer addSublayer:self.playerLayer];
}

- (IBAction)play:(id)sender {
    [self playCurrentIndex];
}

- (IBAction)next:(id)sender {
    self.currentIndex++;
    if (self.currentIndex == self.mediaItems.count) {
        self.currentIndex = 0;
    }
    
    [self playCurrentIndex];
}

- (void) playCurrentIndex {
    NSDictionary *item = self.mediaItems[self.currentIndex];
    NSString *manifestUrl = item[@"manifestUrl"];
    NSDictionary *drmInfo = item[@"drmInfo"];

    NSString *merchantId = drmInfo[@"merchantId"];
    NSString *appId = drmInfo[@"appId"];
    NSString *userId = drmInfo[@"userId"];
    NSString *sessionId = drmInfo[@"sessionId"];

    NSLog(@"Manifest URL: %@", manifestUrl);
    NSLog(@"Merchant ID: %@", merchantId);
    NSLog(@"App ID: %@", appId);
    NSLog(@"User ID: %@", userId);
    NSLog(@"Session ID: %@", sessionId);
    
    [[SigmaMultiDRM getInstance] setMerchant:merchantId];
    [[SigmaMultiDRM getInstance] setAppId:appId];
    [[SigmaMultiDRM getInstance] setUserId:userId];
    [[SigmaMultiDRM getInstance] setSessionId:sessionId];
    [[SigmaMultiDRM getInstance] setDebugMode:false];
    
    AVURLAsset* asset = [[SigmaMultiDRM getInstance] assetWithUrl:manifestUrl];
    AVPlayerItem *currentItem = [AVPlayerItem playerItemWithAsset:asset];
    
    [self.player replaceCurrentItemWithPlayerItem:currentItem];
    [self.player play];
}

- (void)dealloc {
    
}

@end

