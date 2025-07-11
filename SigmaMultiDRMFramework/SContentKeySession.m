//
//  SContentKeySession.m
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import "SContentKeySession.h"
#import <AVFoundation/AVFoundation.h>
@interface SContentKeySession()
{
    
}
@property(nonatomic, weak) AVContentKeySession *sessionKey;
@property(nonatomic, strong) dispatch_queue_t keyQueue;
@end
@implementation SContentKeySession
-(instancetype) init
{
    self = [super init];
    if (self){
#if TARGET_OS_SIMULATOR
    NSLog(@"FairPlay Streaming is not supported on simulators.");
#else
    if (@available(iOS 11.0, *)) {
        _sessionKey = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming];
    } else {
        // Fallback on earlier versions
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        _sessionKey = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming storageDirectoryAtURL:documentsURL];
    }
    _keyQueue = dispatch_queue_create("com.sigma.fairplay", nil);
#endif
    }
    return self;
}
-(void)addAsset:(AVURLAsset *)asset
{
    [self.sessionKey addContentKeyRecipient:asset];
}
-(void)addDelegate:(id<AVContentKeySessionDelegate>) delegate
{
    [self.sessionKey setDelegate:delegate queue:_keyQueue];
}
-(void)removeAsset:(AVURLAsset *)asset
{
    [self.sessionKey removeContentKeyRecipient:asset];
}
@end
