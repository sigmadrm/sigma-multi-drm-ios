//
//  QContentKeyDelegate.m
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import "SContentKeyDelegate.h"

// Error Domain
NSString *const kSigmaMultiDRMErrorDomain = @"com.sigma.multidrm";

// Error Codes
NSInteger const kSigmaMultiDRMErrorCertificateNil = -1;
NSInteger const kSigmaMultiDRMErrorSPCNil = -2;
NSInteger const kSigmaMultiDRMErrorLicenseNil = -3;
NSInteger const kSigmaMultiDRMErrorPersistentKeyNil = -4;
NSInteger const kSigmaMultiDRMErrorSaveFailed = -5;
NSInteger const kSigmaMultiDRMErrorResponseCreationFailed = -6;
NSInteger const kSigmaMultiDRMErrorException = -7;

@interface SContentKeyDelegate()

@end


@implementation SContentKeyDelegate
#pragma AVContentKeySession Delegate
- (void)contentKeySession:(AVContentKeySession *)session didProvideContentKeyRequest:(AVContentKeyRequest *)keyRequest
{
    [self handleContentKeyRequest:session request:keyRequest];
}
- (void)contentKeySession:(AVContentKeySession *)session didProvideRenewingContentKeyRequest:(AVContentKeyRequest *)keyRequest
{
    [self handleContentKeyRequest:session request:keyRequest];
}
- (void)contentKeySession:(AVContentKeySession *)session contentKeyRequest:(AVContentKeyRequest *)keyRequest didFailWithError:(NSError *)err
{
    NSLog(@"ContentKeySession with error: %@", err.localizedDescription);
}
- (BOOL)contentKeySession:(AVContentKeySession *)session shouldRetryContentKeyRequest:(AVContentKeyRequest *)keyRequest reason:(AVContentKeyRequestRetryReason)retryReason
{
    return retryReason == AVContentKeyRequestRetryReasonTimedOut ||
        retryReason == AVContentKeyRequestRetryReasonReceivedResponseWithExpiredLease ||
        retryReason == AVContentKeyRequestRetryReasonReceivedObsoleteContentKey;
}
- (void)contentKeySession:(AVContentKeySession *)session contentKeyRequestDidSucceed:(AVContentKeyRequest *)keyRequest
{

}
- (void)contentKeySessionContentProtectionSessionIdentifierDidChange:(AVContentKeySession *)session
{

}
- (void)contentKeySessionDidGenerateExpiredSessionReport:(AVContentKeySession *)session
{

}

/// Implement
-(void)handleContentKeyRequest:(AVContentKeySession *)session request:(AVContentKeyRequest *)keyRequest
{
    NSString *contentKeyIdentifierString = keyRequest.identifier;
    NSDictionary *queries = [self query:contentKeyIdentifierString];
    [self processOnlineKey:session request:keyRequest];
}

/// Deprecated: This method blocks the thread and does not handle errors.
-(NSData *)getCertificateWithError:(NSError **)certError
{
    NSString *url = [self certUrl];
    __block NSData *result = nil;
    __block NSError *blockError = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger statusCode = httpResponse.statusCode;
        if (error) {
            NSLog(@"[Cert Request Error] URL: %@ | Network Error: %@", url, error.localizedDescription);
            blockError = error;
        } else if (!data || statusCode != 200) {
            NSLog(@"[Cert Request Error] URL: %@ | Status Code: %ld | Error: Data is nil or invalid status code", url, (long)statusCode);
            blockError = [NSError errorWithDomain:@"com.sigma.cert"
                                             code:statusCode
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Certificate request failed with status code %ld", (long)statusCode]}];
        } else {
            result = data;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * 10E9));
    
    *certError = blockError;
    return result;
}

-(void)processOnlineKey:(AVContentKeySession *)session request:(AVContentKeyRequest *)keyRequest
{
    NSString *contentKeyIdentifierString = keyRequest.identifier;
    NSDictionary *queries = [self query:contentKeyIdentifierString];
    NSString *assetIDString = [queries objectForKey:@"assetId"];
    NSString *keyId = [queries objectForKey:@"keyId"];
    
    // Get certificate with error handling
    NSError *certError = nil;
    NSData* certificate = [self getCertificateWithError:&certError];
    if (certError) {
        NSLog(@"[ProcessOnlineKey] Certificate error: %@", certError.localizedDescription);
        [keyRequest processContentKeyResponseError:certError];
        return;
    }
    
    if (!certificate || certificate.length == 0) {
        NSLog(@"[ProcessOnlineKey] Certificate is nil or empty");
        NSError *certDataError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                      code:kSigmaMultiDRMErrorCertificateNil 
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Certificate data is nil or empty"}];
        [keyRequest processContentKeyResponseError:certDataError];
        return;
    }
    // Use strong references for manual reference counting
    SContentKeyDelegate *strongSelf = self;
    AVContentKeySession *strongSession = session;
    AVContentKeyRequest *strongKeyRequest = keyRequest;
    [strongKeyRequest makeStreamingContentKeyRequestDataForApp:certificate 
                                            contentIdentifier:[NSData dataWithBytes:[assetIDString UTF8String] length:[assetIDString length]] 
                                                      options:@{AVContentKeyRequestProtocolVersionsKey: @[[NSNumber numberWithInt:1]]} 
                                            completionHandler:^(NSData * _Nullable contentKeyRequestData, NSError * _Nullable error) {
        if (!strongSession) {
            NSLog(@"[ProcessOnlineKey] ContentKeySession was released");
            return;
        }
        
        if (!strongKeyRequest) {
            NSLog(@"[ProcessOnlineKey] ContentKeyRequest was released");
            return;
        }
        
        if (error) {
            NSLog(@"[ProcessOnlineKey] SPC Request Error: %@", error.localizedDescription);
            [strongKeyRequest processContentKeyResponseError:error];
            return;
        }
        
        if (!contentKeyRequestData || contentKeyRequestData.length == 0) {
            NSLog(@"[ProcessOnlineKey] SPC data is nil or empty");
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
                NSLog(@"[ProcessOnlineKey] License data is nil or empty");
                NSError *licenseError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                             code:kSigmaMultiDRMErrorLicenseNil
                                                         userInfo:@{NSLocalizedDescriptionKey: @"License data is nil or empty"}];
                [strongKeyRequest processContentKeyResponseError:licenseError];
                return;
            }
            
            AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:licenseData];
            if (!response) {
                NSError *responseError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                              code:kSigmaMultiDRMErrorResponseCreationFailed
                                                          userInfo:@{NSLocalizedDescriptionKey: @"Failed to create ContentKeyResponse"}];
                [strongKeyRequest processContentKeyResponseError:responseError];
                return;
            }
            [strongKeyRequest processContentKeyResponse:response];
        } @catch(NSException *exception) {
            NSLog(@"[ProcessOnlineKey] Exception while processing: %@ - %@", exception.name, exception.reason);
            NSError *exceptionError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                           code:kSigmaMultiDRMErrorException 
                                                       userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception: %@", exception.reason]}];
            [strongKeyRequest processContentKeyResponseError:exceptionError];
        }
    }];
}
-(NSData *)requestKeyFromServer:(NSData *)spcData forAssetId:(NSString *) assetId keyId:(NSString *)keyId
{
    NSString *url = [self licenseUrl:assetId keyId:keyId];
    NSCharacterSet *queryCharacter = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSMutableCharacterSet *allowUrlCharacter = [NSMutableCharacterSet characterSetWithBitmapRepresentation:[queryCharacter bitmapRepresentation]];
    [allowUrlCharacter removeCharactersInString:@"+/=\\"];
    NSString *spcEncoding = [[spcData base64EncodedStringWithOptions:0] stringByAddingPercentEncodingWithAllowedCharacters:allowUrlCharacter];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    NSString *body = [NSString stringWithFormat:@"spc=%@&assetId=%@&keyId=%@", spcEncoding, assetId, keyId];
    request.HTTPBody = [NSData dataWithBytes:[body UTF8String] length:[body length]];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request addValue:[self customData] forHTTPHeaderField:@"custom-data"];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *result = [[NSData alloc] initWithBase64EncodedString:@"" options:NSDataBase64DecodingIgnoreUnknownCharacters];  // default empty license
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        @try {
            do {
                if (error || !data) break;
                
                NSDictionary *licenseObj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
                if(!licenseObj) break;
                
                NSString *license = [licenseObj objectForKey:@"license"];
                if(!license) {
                    NSLog(@"License request error: %@", licenseObj);
                    break;
                }
                
                result = [[NSData alloc] initWithBase64EncodedString:license options:NSDataBase64DecodingIgnoreUnknownCharacters];
            }
            while (FALSE);
        } @catch (NSException *exception) {
            NSLog(@"Exception while parsing license: %@ - %@", exception.name, exception.reason);
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    [dataTask resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * 10E9));
    return result;
}
-(NSDictionary *)query: (NSString *)url
{
    NSMutableDictionary *queries = [[NSMutableDictionary alloc] init];
    NSURLComponents *urlComponent = [NSURLComponents componentsWithString:url];
    for (int idx = 0; idx < [urlComponent.queryItems count]; idx++){
        NSURLQueryItem *item = [urlComponent.queryItems objectAtIndex:idx];
        [queries setObject:item.value forKey:item.name];
    }
    return queries;
}
-(NSString *)customData
{
    NSMutableDictionary *sigma = [[NSMutableDictionary alloc] init];
    [sigma setObject:_userId forKey:@"userId"];
    [sigma setObject:_sessionId forKey:@"sessionId"];
    [sigma setObject:_merchant forKey:@"merchantId"];
    [sigma setObject:_appId forKey:@"appId"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:sigma options:NSJSONWritingPrettyPrinted error:nil];
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}
-(NSString *)certUrl
{
    if (_debugMode) {//STAGING MODE
        return [NSString stringWithFormat:@"https://cert-staging.sigmadrm.com/app/fairplay/%@/%@", _merchant, _appId];
    }
    else { // PRODUCTION MODE
        return [NSString stringWithFormat:@"https://cert.sigmadrm.com/app/fairplay/%@/%@", _merchant, _appId];
    }
}
-(NSString *)licenseUrl:(NSString *)assetId keyId:(NSString *)keyId
{
    if (_debugMode) {//STAGING MODE
        return [NSString stringWithFormat:@"https://license-staging.sigmadrm.com/license/verify/fairplay?assetId=%@&keyId=%@", assetId, keyId];
    }
    else { // PRODUCTION MODE
        return [NSString stringWithFormat:@"https://license.sigmadrm.com/license/verify/fairplay?assetId=%@&keyId=%@", assetId, keyId];
    }
}
@end
