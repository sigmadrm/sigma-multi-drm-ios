//
//  QContentKeyDelegate.m
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import "SContentKeyDelegate.h"
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
    NSLog(@"contentKeySession: %@", err);
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
-(NSData *)serverCetificate
{
    NSString *url = [self certUrl];
    __block NSData *result = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        result = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * 10E9));
    return result;
}
-(void)processOnlineKey:(AVContentKeySession *)session request:(AVContentKeyRequest *)keyRequest
{
    NSString *contentKeyIdentifierString = keyRequest.identifier;
    NSDictionary *queries = [self query:contentKeyIdentifierString];
    NSString *assetIDString = [queries objectForKey:@"assetId"];
    NSString *keyId = [queries objectForKey:@"keyId"];
    NSData *certificate = [self serverCetificate];
    [keyRequest makeStreamingContentKeyRequestDataForApp:certificate contentIdentifier:[NSData dataWithBytes:[assetIDString UTF8String] length:[assetIDString length]] options:@{AVContentKeyRequestProtocolVersionsKey: @[[NSNumber numberWithInt:1]]} completionHandler:^(NSData * _Nullable contentKeyRequestData, NSError * _Nullable error) {
        // Check validate
        NSData *licenseData = [self requestKeyFromServer:contentKeyRequestData forAssetId:assetIDString keyId:keyId];
        if (error){
            NSLog(@"License Data Error!");
            [keyRequest processContentKeyResponseError:error];
        }
        else {
            AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:licenseData];
            [keyRequest processContentKeyResponse:response];
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
    __block NSData *result = nil;
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        do {
            if (error) break;
            if (!data) break;
            NSDictionary *licenseObj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
            NSLog(@"NSData: %@", licenseObj);
            if (!licenseObj) break;
            NSString *license = [licenseObj objectForKey:@"license"];
            result = [[NSData alloc] initWithBase64EncodedString:license options:NSDataBase64DecodingIgnoreUnknownCharacters];
        }
        while (FALSE);
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
