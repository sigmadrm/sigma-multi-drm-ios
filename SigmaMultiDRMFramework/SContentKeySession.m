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
@property(nonatomic, nullable) AVContentKeySession *sessionKey;
@property(nonatomic, nullable) dispatch_queue_t keyQueue;
@end
@implementation SContentKeySession
-(instancetype) init
{
    self = [super init];
    if (self){
#if TARGET_OS_SIMULATOR
        NSLog(@"FairPlay Streaming is not supported on simulators.");
        _keyQueue = dispatch_queue_create("com.sigma.fairplay.sim", DISPATCH_QUEUE_SERIAL);
#else
    if (@available(iOS 11.0, *)) {
        _sessionKey = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming];
    } else {
        // Fallback on earlier versions
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        _sessionKey = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming storageDirectoryAtURL:documentsURL];
    }
    _keyQueue = dispatch_queue_create("com.sigma.fairplay", DISPATCH_QUEUE_SERIAL);
#endif
    }
    return self;
}
-(void)addDelegate:(id<AVContentKeySessionDelegate>) delegate
{
    if (!_sessionKey) {
        return;
    }
    [_sessionKey setDelegate:delegate queue:_keyQueue];
}
-(void)addAsset:(AVURLAsset *)asset
{
    if (!_sessionKey) {
        return;
    }
    [_sessionKey addContentKeyRecipient:asset];
}
-(void)removeAsset:(AVURLAsset *)asset
{
    if (!_sessionKey) {
        return;
    }
    [_sessionKey removeContentKeyRecipient:asset];
}

- (nullable dispatch_queue_t)drmKeyQueue
{
    return _keyQueue;
}

- (nullable AVContentKeySession *)avContentKeySession
{
    return _sessionKey;
}

@end
