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
@interface SigmaMultiDRM()
{
    BOOL _debug;
}
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, strong) NSString *merchant;
@property (nonatomic, strong) NSString *appId;
@property (nonatomic, strong) SContentKeySession *contentKey;
@property (nonatomic, strong) SContentKeyDelegate *contentKeyDelegate;

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
        _debug = [[NSBundle mainBundle].infoDictionary objectForKey:@"sigma_debug"] != nil ? [[[NSBundle mainBundle].infoDictionary objectForKey:@"sigma_debug"] boolValue] : false;
    }
    
    return self;
}

-(AVURLAsset *)assetWithUrl:(NSString *)url
{
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:url] options:nil];
    SContentKeyDelegate *contentKeyDelegate = [[SContentKeyDelegate alloc] init];
    SContentKeySession *contentKey = [[SContentKeySession alloc] init];
    [contentKeyDelegate setUserId:_userId];
    [contentKeyDelegate setSessionId:_sessionId];
    [contentKeyDelegate setAppId:_appId];
    [contentKeyDelegate setMerchant:_merchant];
    [contentKeyDelegate setDebugMode:_debug];
    [contentKey addDelegate:contentKeyDelegate];
    [contentKey addAsset:asset];
    self.contentKeyDelegate = contentKeyDelegate;
    self.contentKey = contentKey;
    return asset;
}
-(void)setUserId:(NSString *)userId
{
    _userId = userId;
}
-(void)setSessionId:(NSString *)sessionId
{
    _sessionId = sessionId;
}

-(void)setMerchant:(NSString *)merchant
{
    _merchant = merchant;
}

-(void)setAppId:(NSString *)appId
{
    _appId = appId;
}
-(void)setDebugMode:(BOOL)debug
{
    _debug = debug;
}
@end
