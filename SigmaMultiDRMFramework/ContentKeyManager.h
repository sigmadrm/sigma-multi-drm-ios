//
//  ContentKeyManager.h
//
//  Copyright (C) 2017 Apple Inc. All Rights Reserved.
//
//  Abstract:
//  The ContentKeyManager class configures the instance of AVContentKeySession to use for requesting content keys
//  securely for playback or offline use.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SContentKeyDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ContentKeyManager : NSObject
+ (instancetype)sharedManager;
@property(nonatomic, strong, readonly) AVContentKeySession *contentKeySession;
@property(nonatomic, strong, readonly) SContentKeyDelegate *contentKeyDelegate;
@end

NS_ASSUME_NONNULL_END
