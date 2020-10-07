//
//  QContentKeyDelegate+Persistent.m
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/13/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import "SContentKeyDelegate+Persistent.h"

@implementation SContentKeyDelegate(Persistent)
- (void)contentKeySession:(AVContentKeySession *)session didProvidePersistableContentKeyRequest:(AVPersistableContentKeyRequest *)keyRequest
{
    [self handlePersistableContentKeyRequest:session request:keyRequest];
}
- (void)contentKeySession:(AVContentKeySession *)session didUpdatePersistableContentKey:(NSData *)persistableContentKey forContentKeyIdentifier:(id)keyIdentifier
{
    NSDictionary *queries = [self query:keyIdentifier];
    NSString *assetIDString = [queries objectForKey:@"assetId"];
    if (assetIDString == nil){
        // Throw error
    }
    else {
        // Save key
        NSString *contentKeyName = [self keyNameWithAssetId:assetIDString];
        [self deletePersistenKey:contentKeyName];
        [self saveContentKey:persistableContentKey withName:contentKeyName];
    }
}

-(void)handlePersistableContentKeyRequest:(AVContentKeySession *)session request:(AVPersistableContentKeyRequest *)keyRequest
{
    NSString *contentKeyIdentifierString = keyRequest.identifier;
    NSDictionary *queries = [self query:contentKeyIdentifierString];
    NSString *assetIDString = [queries objectForKey:@"assetId"];
    do {
        if (![self isExistContentKey:assetIDString]) {
            break;
        }
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:[self fullPathWithAssetId:assetIDString]];
        if (data == nil){
            break;
        }
        AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:data];
        [keyRequest processContentKeyResponse:response];
        return;
    }
    while (FALSE);
    // Request Key Online
    [self requestOnlineKey:session request:keyRequest];
}
-(void)requestOnlineKey:(AVContentKeySession *)session request:(AVPersistableContentKeyRequest *)keyRequest
{
    NSString *contentKeyIdentifierString = keyRequest.identifier;
    NSDictionary *queries = [self query:contentKeyIdentifierString];
    NSString *assetIDString = [queries objectForKey:@"assetId"];
    NSString *keyId = [queries objectForKey:@"keyId"];
    NSData *certificate = [self serverCetificate];
    [keyRequest makeStreamingContentKeyRequestDataForApp:certificate contentIdentifier:[NSData dataWithBytes:[assetIDString UTF8String] length:[assetIDString length]] options:@{AVContentKeyRequestProtocolVersionsKey: @[[NSNumber numberWithInt:1]]} completionHandler:^(NSData * _Nullable contentKeyRequestData, NSError * _Nullable error) {
        // Check validate
        NSData *licenseData = [self requestKeyFromServer:contentKeyRequestData forAssetId:assetIDString keyId:keyId];
        NSError *err = nil;
        NSData *persistentKey = [keyRequest persistableContentKeyFromKeyVendorResponse:licenseData options:nil error:&err];
        if (err == nil)
        {
            NSLog(@"Persisten Error: %@", err);
        }
        // Save key
        [self saveContentKey:persistentKey withName:assetIDString];
        AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:persistentKey];
        [keyRequest processContentKeyResponse:response];
    }];
}

-(NSError *)deletePersistenKey:(NSString *)contentKeyName
{
    NSString *fullPath = [self fullPathWithName:contentKeyName];
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&error];
    }
    return error;
}
-(BOOL)isExistContentKey:(NSString *)assetId
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self fullPathWithName:[self keyNameWithAssetId:assetId]]];
}
-(void)saveContentKey:(NSData *)contentKey withName:(NSString *)contentKeyName
{
    NSString *fullPath = [self fullPathWithName:contentKeyName];
    [contentKey writeToFile:fullPath atomically:NSDataWritingAtomic];
}
-(NSString *)fullPathWithAssetId:(NSString *)assetId
{
    return [self fullPathWithName:[self keyNameWithAssetId:assetId]];
}
-(NSString *)fullPathWithName:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *folder = [paths objectAtIndex:0];
    return [folder stringByAppendingPathComponent:name];
}
-(NSString *)keyNameWithAssetId:(NSString *)assetId
{
    return [NSString stringWithFormat:@"qnet_%@", assetId];
}
@end
