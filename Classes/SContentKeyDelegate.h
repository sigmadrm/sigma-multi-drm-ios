//
//  SContentKeyDelegate.h
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

//@protocol QnetDelegate <NSObject>
//@optional
//-(void)getCetificateError:(NSError *)err;
//-(void)getLicenseError:(NSError *)err;
//@end

@interface SContentKeyDelegate : NSObject<AVContentKeySessionDelegate>
{
}
@property (nonatomic, retain) NSString *userId;
@property (nonatomic, retain) NSString *sessionId;
@property (nonatomic, retain) NSString *merchant;
@property (nonatomic, retain) NSString *appId;
@property (nonatomic, assign) BOOL debugMode;

-(NSDictionary *)query: (NSString *)url;
-(void)processOnlineKey:(AVContentKeySession *)session request:(AVContentKeyRequest *)keyRequest;
-(NSData *)serverCetificate;
-(NSData *)requestKeyFromServer:(NSData *)spcData forAssetId:(NSString *) assetId variantId:(NSString *)variantId;
@end

NS_ASSUME_NONNULL_END
