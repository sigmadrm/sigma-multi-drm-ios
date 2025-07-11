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
    NSData *certificate = [self serverCertificate];
    
    AVPersistableContentKeyRequest *strongKeyRequest = keyRequest;
    SContentKeyDelegate *strongSelf = self;
    [strongKeyRequest makeStreamingContentKeyRequestDataForApp:certificate contentIdentifier:[NSData dataWithBytes:[assetIDString UTF8String] length:[assetIDString length]] options:@{AVContentKeyRequestProtocolVersionsKey: @[[NSNumber numberWithInt:1]]} completionHandler:^(NSData * _Nullable contentKeyRequestData, NSError * _Nullable error) {
        if(!strongSelf || !strongKeyRequest) {
            NSLog(@"Cancel persistent key request: strongSelf or strongKeyRequest is nil");
            return;
        }
        
        if (error) {
            NSLog(@"[SPC Request Error] Failed to generate SPC data: %@", error.localizedDescription);
            [strongKeyRequest processContentKeyResponseError:error];
            return;
        }
        
        @try {
            NSData *licenseData = [strongSelf requestKeyFromServer:contentKeyRequestData forAssetId:assetIDString keyId:keyId];
            if (!licenseData || licenseData.length == 0) {
                NSLog(@"[License Error] Empty or nil license data received");
                NSError *licenseError = [NSError errorWithDomain:@"com.sigma.license" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Empty or nil license data"}];
                [strongKeyRequest processContentKeyResponseError:licenseError];
                return;
            }
            
            NSError *err = nil;
            NSData *persistentKey = [strongKeyRequest persistableContentKeyFromKeyVendorResponse:licenseData options:nil error:&err];
            
            if (err != nil) {
                NSLog(@"[Persistent Error] Failed to create persistent key: %@", err.localizedDescription);
                [strongKeyRequest processContentKeyResponseError:err];
                return;
            }
            
            if (!persistentKey || persistentKey.length == 0) {
                NSLog(@"[Persistent Error] Empty or nil persistent key generated");
                NSError *persistentError = [NSError errorWithDomain:@"com.sigma.persistent" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Empty or nil persistent key"}];
                [strongKeyRequest processContentKeyResponseError:persistentError];
                return;
            }
            
            // Save persistent key to disk
            NSString *contentKeyName = [strongSelf keyNameWithAssetId:assetIDString];
            [strongSelf saveContentKey:persistentKey withName:contentKeyName];
            
            // Create response and process
            AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:persistentKey];
            [strongKeyRequest processContentKeyResponse:response];
            
            NSLog(@"[Persistent Success] Key saved and processed for asset: %@", assetIDString);
            
        } @catch(NSException* exception) {
            NSLog(@"[Persistent Exception] Error processing persistent key: %@ - %@", exception.name, exception.reason);
            NSError *exceptionError = [NSError errorWithDomain:@"com.sigma.persistent" code:-3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception: %@", exception.reason]}];
            [strongKeyRequest processContentKeyResponseError:exceptionError];
        }
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
-(BOOL)saveContentKey:(NSData *)contentKey withName:(NSString *)contentKeyName
{
    if (!contentKey || contentKey.length == 0) {
        NSLog(@"[Save Error] Cannot save empty or nil content key");
        return NO;
    }
    
    if (!contentKeyName || contentKeyName.length == 0) {
        NSLog(@"[Save Error] Cannot save with empty or nil key name");
        return NO;
    }
    
    NSString *fullPath = [self fullPathWithName:contentKeyName];
    BOOL success = [contentKey writeToFile:fullPath atomically:NSDataWritingAtomic];
    
    if (success) {
        NSLog(@"[Save Success] Content key saved to: %@", fullPath);
    } else {
        NSLog(@"[Save Error] Failed to save content key to: %@", fullPath);
    }
    
    return success;
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
