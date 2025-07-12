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
    
    NSLog(@"[RequestOnlineKey] Start processing persistent key - Asset: %@ | KeyId: %@", assetIDString, keyId);
    
    // Get certificate with error handling
    NSError* certError = nil;
    NSData *certificate = [self getCertificateWithError:&certError];
    if (certError) {
        NSLog(@"[RequestOnlineKey] Certificate error: %@", certError.localizedDescription);
        [keyRequest processContentKeyResponseError:certError];
        return;
    }
    
    if (!certificate || certificate.length == 0) {
        NSLog(@"[RequestOnlineKey] Certificate is nil or empty");
        NSError *certDataError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                      code:kSigmaMultiDRMErrorCertificateNil 
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Certificate data is nil or empty"}];
        [keyRequest processContentKeyResponseError:certDataError];
        return;
    }
    
    NSLog(@"[RequestOnlineKey] Certificate obtained - Size: %lu bytes", (unsigned long)certificate.length);
    
    // Use strong references for manual reference counting
    SContentKeyDelegate *strongSelf = self;
    AVContentKeySession *strongSession = session;
    AVPersistableContentKeyRequest *strongKeyRequest = keyRequest;
    
    [strongKeyRequest makeStreamingContentKeyRequestDataForApp:certificate 
                                            contentIdentifier:[NSData dataWithBytes:[assetIDString UTF8String] length:[assetIDString length]] 
                                                      options:@{AVContentKeyRequestProtocolVersionsKey: @[[NSNumber numberWithInt:1]]} 
                                            completionHandler:^(NSData * _Nullable contentKeyRequestData, NSError * _Nullable error) {
        if (!strongSession) {
            NSLog(@"[RequestOnlineKey] ContentKeySession was released");
            return;
        }
        
        if (!strongKeyRequest) {
            NSLog(@"[RequestOnlineKey] ContentKeyRequest was released");
            return;
        }
        
        if (error) {
            NSLog(@"[RequestOnlineKey] SPC Request Error: %@", error.localizedDescription);
            [strongKeyRequest processContentKeyResponseError:error];
            return;
        }
        
        if (!contentKeyRequestData || contentKeyRequestData.length == 0) {
            NSLog(@"[RequestOnlineKey] SPC data is nil or empty");
            NSError *spcError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                     code:kSigmaMultiDRMErrorSPCNil 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"SPC data is nil or empty"}];
            [strongKeyRequest processContentKeyResponseError:spcError];
            return;
        }
    
        @try {
            // Request license from server
            NSData *licenseData = [strongSelf requestKeyFromServer:contentKeyRequestData forAssetId:assetIDString keyId:keyId];
            if (!licenseData || licenseData.length == 0) {
                NSLog(@"[RequestOnlineKey] License data is nil or empty");
                NSError *licenseError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                             code:kSigmaMultiDRMErrorLicenseNil 
                                                         userInfo:@{NSLocalizedDescriptionKey: @"License data is nil or empty"}];
                [strongKeyRequest processContentKeyResponseError:licenseError];
                return;
            }
            
            // Create persistent key from license data
            NSError *pstError = nil;
            NSData *persistentKey = [strongKeyRequest persistableContentKeyFromKeyVendorResponse:licenseData options:nil error:&pstError];
            if (pstError) {
                NSLog(@"[RequestOnlineKey] Persistent key creation error: %@", pstError.localizedDescription);
                [strongKeyRequest processContentKeyResponseError:pstError];
                return;
            }
            
            if (!persistentKey || persistentKey.length == 0) {
                NSLog(@"[RequestOnlineKey] Persistent key is nil or empty");
                NSError *persistentError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                                code:kSigmaMultiDRMErrorPersistentKeyNil 
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Persistent key is nil or empty"}];
                [strongKeyRequest processContentKeyResponseError:persistentError];
                return;
            }
            // Save persistent key to disk
            NSString *contentKeyName = [strongSelf keyNameWithAssetId:assetIDString];
            BOOL saveSuccess = [strongSelf saveContentKey:persistentKey withName:contentKeyName];
            if (!saveSuccess) {
                NSLog(@"[RequestOnlineKey] Failed to save persistent key to disk");
                NSError *saveError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                          code:kSigmaMultiDRMErrorSaveFailed 
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to save persistent key to disk"}];
                [strongKeyRequest processContentKeyResponseError:saveError];
                return;
            }

            AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:persistentKey];
            if (!response) {
                NSLog(@"[RequestOnlineKey] Failed to create ContentKeyResponse");
                NSError *responseError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                              code:kSigmaMultiDRMErrorResponseCreationFailed 
                                                          userInfo:@{NSLocalizedDescriptionKey: @"Failed to create ContentKeyResponse"}];
                [strongKeyRequest processContentKeyResponseError:responseError];
                return;
            }

            [strongKeyRequest processContentKeyResponse:response];
        } @catch(NSException *exception) {
            NSLog(@"[RequestOnlineKey] Exception while processing: %@ - %@", exception.name, exception.reason);
            NSError *exceptionError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                           code:kSigmaMultiDRMErrorException 
                                                       userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception: %@", exception.reason]}];
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
    NSString *fullPath = [self fullPathWithName:contentKeyName];
    return [contentKey writeToFile:fullPath atomically:NSDataWritingAtomic];
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
