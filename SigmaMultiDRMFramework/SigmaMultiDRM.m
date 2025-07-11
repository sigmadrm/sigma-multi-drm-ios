//
//  QnetSDK.m
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import "SigmaMultiDRM.h"
#import "SContentKeySession.h"
#import "SContentKeyDelegate.h"
#import "ContentKeyManager.h"
@interface SigmaMultiDRM()

@property (nonatomic, strong) AVURLAsset* urlAsset;
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, strong) NSString *merchant;
@property (nonatomic, strong) NSString *appId;
@property (nonatomic, assign) BOOL debugMode;

@end
static SigmaMultiDRM *gSigmaSDK = nil;
@implementation SigmaMultiDRM
+(SigmaMultiDRM *)getInstance
{
    if (!gSigmaSDK){
        gSigmaSDK = [[SigmaMultiDRM alloc] init];
    }
    return gSigmaSDK;
}
-(instancetype)init
{
    self = [super init];
    if (self){
        _merchant = [[NSBundle mainBundle].infoDictionary objectForKey:@"merchant"];
        _appId = [[NSBundle mainBundle].infoDictionary objectForKey:@"appId"];
        _debugMode = [[NSBundle mainBundle].infoDictionary objectForKey:@"sigma_debug"] != nil ? [[[NSBundle mainBundle].infoDictionary objectForKey:@"sigma_debug"] boolValue] : false;
    }
    
    return self;
}

-(void)setMerchant:(NSString *)merchant
{
    _merchant = merchant;
    [[[ContentKeyManager sharedManager] contentKeyDelegate] setMerchant:merchant];
}

-(void)setAppId:(NSString *)appId
{
    _appId = appId;
    [[[ContentKeyManager sharedManager] contentKeyDelegate] setAppId:appId];
}

-(void)setUserId:(NSString *)userId
{
    _userId = userId;
    [[[ContentKeyManager sharedManager] contentKeyDelegate] setUserId:userId];
}

-(void)setSessionId:(NSString *)sessionId
{
    _sessionId = sessionId;
    [[[ContentKeyManager sharedManager] contentKeyDelegate] setSessionId:sessionId];
}

-(void)setDebugMode:(BOOL)debugMode
{
    _debugMode = debugMode;
    [[[ContentKeyManager sharedManager] contentKeyDelegate] setDebugMode:debugMode];
}

-(AVURLAsset *)assetWithUrl:(NSString *)url
{
    if(self.urlAsset){
        [[[ContentKeyManager sharedManager] contentKeySession] removeContentKeyRecipient:self.urlAsset];
        self.urlAsset = nil;
    }
    self.urlAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:url] options:nil];
    [[[ContentKeyManager sharedManager] contentKeySession] addContentKeyRecipient:self.urlAsset];
    return self.urlAsset;
}
@end
