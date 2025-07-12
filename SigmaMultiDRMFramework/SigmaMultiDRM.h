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

NS_ASSUME_NONNULL_BEGIN

@interface SigmaMultiDRM : NSObject
+(SigmaMultiDRM *)getInstance;
-(AVURLAsset *)assetWithUrl:(NSString *)url;
-(void)setUserId:(NSString *)userId;
-(void)setSessionId:(NSString *)sessionId;
-(void)setMerchant:(NSString *)merchant;
-(void)setAppId:(NSString *)appId;
-(void)setDebugMode:(BOOL)debug;
@end

NS_ASSUME_NONNULL_END
