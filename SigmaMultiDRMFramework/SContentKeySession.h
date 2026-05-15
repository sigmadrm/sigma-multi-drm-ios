//
//  SContentKeySession.h
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVContentKeySession.h>

NS_ASSUME_NONNULL_BEGIN

@interface SContentKeySession : NSObject

/// Serial queue passed to `AVContentKeySession setDelegate:queue:` — renewal work must be scheduled here.
@property (atomic, readonly, nullable) dispatch_queue_t drmKeyQueue;
@property (atomic, readonly, nullable) AVContentKeySession *avContentKeySession;

-(void)addAsset:(AVURLAsset *)asset;
-(void)addDelegate:(id<AVContentKeySessionDelegate>) delegate;
-(void)removeAsset:(AVURLAsset *)asset;
@end

NS_ASSUME_NONNULL_END
