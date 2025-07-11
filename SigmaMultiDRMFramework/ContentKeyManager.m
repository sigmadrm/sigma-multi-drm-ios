//
//  ContentKeyManager.m
//
//  Copyright (C) 2017 Apple Inc. All Rights Reserved.
//
//  Abstract:
//  The ContentKeyManager class configures the instance of AVContentKeySession to use for requesting content keys
//  securely for playback or offline use.
//

#import "ContentKeyManager.h"
#import "SContentKeyDelegate.h"

@interface ContentKeyManager ()
@property (nonatomic, strong) dispatch_queue_t contentKeyDelegateQueue;
@end

@implementation ContentKeyManager

+ (instancetype)sharedManager {
    static ContentKeyManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ContentKeyManager alloc] initPrivate];
    });
    return sharedInstance;
}

// Private init
- (instancetype)initPrivate {
    self = [super init];
    if (self) {
#if TARGET_OS_SIMULATOR
            NSLog(@"FairPlay Streaming is not supported on simulators.");
#else
            _contentKeyDelegateQueue = dispatch_queue_create("SmContentKeyDelegateQueue", NULL);
            _contentKeyDelegate = [[SContentKeyDelegate alloc] init];
            if (@available(iOS 11.0, *)) {
                _contentKeySession = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming];
            } else {
                // Fallback on earlier versions
                NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
                NSURL *documentsURL = [paths lastObject];
                _contentKeySession = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming storageDirectoryAtURL:documentsURL];
            }
            [_contentKeySession setDelegate:_contentKeyDelegate queue:_contentKeyDelegateQueue];
#endif
    }
    return self;
}

// Prevent use of default init
- (instancetype)init {
    [NSException raise:@"Singleton" format:@"Use +[ContentKeyManager sharedManager]!"];
    return nil;
}

@end 
