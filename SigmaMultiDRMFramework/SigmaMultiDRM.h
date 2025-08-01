//
//  QnetSDK.h
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>
#import <AVFoundation/AVAsset.h>
#import "SigmaMultiDRMDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface SigmaMultiDRM : NSObject

/**
 * Get the singleton instance of SigmaMultiDRM
 *
 * @return The shared SigmaMultiDRM instance
 */
+ (SigmaMultiDRM *)getInstance;

/**
 * The delegate object that will receive license request callbacks
 */
@property(nonatomic, assign) id<SigmaMultiDRMDelegate> delegate;

/**
 * Create an AVURLAsset with DRM protection for the given URL
 *
 * @param url The URL of the content to be protected
 * @return An AVURLAsset configured with DRM protection
 */
- (AVURLAsset *)assetWithUrl:(NSString *)url;

/**
 * Set the user identifier for license requests
 *
 * @param userId The unique identifier for the user
 */
- (void)setUserId:(NSString *)userId;

/**
 * Set the session identifier for license requests
 *
 * @param sessionId The unique identifier for the current session
 */
- (void)setSessionId:(NSString *)sessionId;

/**
 * Set the merchant identifier for license requests
 *
 * @param merchant The unique identifier for the merchant
 */
- (void)setMerchant:(NSString *)merchant;

/**
 * Set the application identifier for license requests
 *
 * @param appId The unique identifier for the application
 */
- (void)setAppId:(NSString *)appId;

/**
 * Enable or disable debug mode
 *
 * @param debug YES to enable debug mode (staging environment), NO for production
 */
- (void)setDebugMode:(BOOL)debug;

@end

NS_ASSUME_NONNULL_END
