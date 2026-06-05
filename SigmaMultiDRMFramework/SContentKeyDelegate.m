//
//  QContentKeyDelegate.m
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import "SContentKeyDelegate.h"
#import "SigmaMultiDRMDelegate.h"

// Error Domain
NSString *const kSigmaMultiDRMErrorDomain = @"com.sigma.multidrm";
#define POST_DRM_LOG(...) dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName:@"SigmaDRMLogEvent" object:nil userInfo:@{@"message": __VA_ARGS__}]; })

// Error Codes
NSInteger const kSigmaMultiDRMErrorCertificateNil = -1;
NSInteger const kSigmaMultiDRMErrorSPCNil = -2;
NSInteger const kSigmaMultiDRMErrorLicenseNil = -3;
NSInteger const kSigmaMultiDRMErrorPersistentKeyNil = -4;
NSInteger const kSigmaMultiDRMErrorSaveFailed = -5;
NSInteger const kSigmaMultiDRMErrorResponseCreationFailed = -6;
NSInteger const kSigmaMultiDRMErrorException = -7;

/// Seconds before JSON `expireTime` to invoke `renewExpiringResponseDataForContentKeyRequest:`.
static const NSTimeInterval kSigmaFairPlayLicenseRenewLeadSeconds = 5.0;

@interface SContentKeyDelegate()
@property (atomic, copy, nullable) dispatch_block_t pendingLicenseRenewalBlock;
@end

/// FairPlay app certificate is static per `certUrl`; keep for process lifetime (no eviction).
static NSMutableDictionary<NSString *, NSData *> *SigmaCertificateStore(void)
{
    static NSMutableDictionary<NSString *, NSData *> *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [NSMutableDictionary dictionary];
    });
    return store;
}


@implementation SContentKeyDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _certRequestTask = nil;
        _licenseRequestTask = nil;
    }
    return self;
}

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
    [self cancelScheduledLicenseRenewal];
}
- (BOOL)contentKeySession:(AVContentKeySession *)session shouldRetryContentKeyRequest:(AVContentKeyRequest *)keyRequest reason:(AVContentKeyRequestRetryReason)retryReason
{
    BOOL ret = retryReason == AVContentKeyRequestRetryReasonTimedOut ||
        retryReason == AVContentKeyRequestRetryReasonReceivedResponseWithExpiredLease ||
        retryReason == AVContentKeyRequestRetryReasonReceivedObsoleteContentKey;
    return ret;
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
    POST_DRM_LOG(@">>> DRM: Requesting SPC (Challenge)....");
    [self cancelScheduledLicenseRenewal];
    NSString *contentKeyIdentifierString = keyRequest.identifier;
    NSDictionary *queries = [self query:contentKeyIdentifierString];
    [self processOnlineKey:session request:keyRequest];
}

/// Deprecated: This method blocks the thread and does not handle errors.
-(NSData *)getCertificateWithError:(NSError **)certError
{
    NSString *url = [self certUrl];
    if (url.length == 0) {
        if (certError) {
            *certError = [NSError errorWithDomain:@"com.sigma.cert"
                                             code:-2
                                         userInfo:@{NSLocalizedDescriptionKey: @"Certificate URL is empty"}];
        }
        return nil;
    }

    NSData *cached = nil;
    @synchronized (SigmaCertificateStore()) {
        cached = [SigmaCertificateStore() objectForKey:url];
    }
    if (cached.length > 0) {
        NSLog(@"[Cert] Using in-memory FairPlay certificate (%lu bytes)", (unsigned long)cached.length);
        if (certError) {
            *certError = nil;
        }
        return cached;
    }

    __block NSData *result = nil;
    __block NSError *blockError = nil;
    
    POST_DRM_LOG(@">>> DRM: Loading App Certificate....");
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    self.certRequestTask = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
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
            if (data.length > 0) {
                @synchronized (SigmaCertificateStore()) {
                    [SigmaCertificateStore() setObject:data forKey:url];
                }
                NSLog(@"[Cert] Fetched FairPlay certificate (%lu bytes); stored for app lifetime", (unsigned long)data.length);
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [self.certRequestTask resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * 10E9));
    
    if (certError) {
        *certError = blockError;
    }
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
        POST_DRM_LOG([NSString stringWithFormat:@"!!! DRM ERROR: Certificate data is nil or empty"]);
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
            POST_DRM_LOG([NSString stringWithFormat:@"!!! DRM ERROR: SPC Request Error: %@", error.localizedDescription]);
            [strongKeyRequest processContentKeyResponseError:error];
            return;
        }
        
        if (!contentKeyRequestData || contentKeyRequestData.length == 0) {
            NSLog(@"[ProcessOnlineKey] SPC data is nil or empty");
            NSError *spcError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                     code:kSigmaMultiDRMErrorSPCNil 
                                                 userInfo:@{NSLocalizedDescriptionKey: @"SPC data is nil or empty"}];
            POST_DRM_LOG([NSString stringWithFormat:@"!!! DRM ERROR: SPC data is nil or empty"]);
            [strongKeyRequest processContentKeyResponseError:spcError];
            return;
        }
    
        @try {
            // Request license from server
            POST_DRM_LOG(@">>> DRM: Requesting CKC (License)....");
            NSInteger leaseSecondsHint = -1;
            NSData *licenseData = [strongSelf requestKeyFromServer:contentKeyRequestData forAssetId:assetIDString keyId:keyId leaseSeconds:&leaseSecondsHint];
            if (!licenseData || licenseData.length == 0) {
                NSLog(@"[ProcessOnlineKey] License data is nil or empty");
                NSError *licenseError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                             code:kSigmaMultiDRMErrorLicenseNil
                                                         userInfo:@{NSLocalizedDescriptionKey: @"License data is nil or empty"}];
                POST_DRM_LOG([NSString stringWithFormat:@"!!! DRM ERROR: License data is nil or empty"]);
                [strongKeyRequest processContentKeyResponseError:licenseError];
                return;
            }
            
            AVContentKeyResponse *response = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:licenseData];
            if (!response) {
                NSError *responseError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                              code:kSigmaMultiDRMErrorResponseCreationFailed
                                                          userInfo:@{NSLocalizedDescriptionKey: @"Failed to create ContentKeyResponse"}];
                POST_DRM_LOG([NSString stringWithFormat:@"!!! DRM ERROR: Failed to create ContentKeyResponse"]);
                [strongKeyRequest processContentKeyResponseError:responseError];
                return;
            }
            [strongKeyRequest processContentKeyResponse:response];
            POST_DRM_LOG(@">>> DRM: License Loaded Successfully.");
            [strongSelf scheduleLicenseRenewalAfterSeconds:leaseSecondsHint session:strongSession keyRequest:strongKeyRequest];
        } @catch(NSException *exception) {
            NSLog(@"[ProcessOnlineKey] Exception while processing: %@ - %@", exception.name, exception.reason);
            NSError *exceptionError = [NSError errorWithDomain:kSigmaMultiDRMErrorDomain 
                                                           code:kSigmaMultiDRMErrorException 
                                                       userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Exception: %@", exception.reason]}];
            POST_DRM_LOG([NSString stringWithFormat:@"!!! DRM ERROR: Exception while processing: %@", exception.reason]);
            [strongKeyRequest processContentKeyResponseError:exceptionError];
        }
    }];
}
-(NSData *)requestKeyFromServer:(NSData *)spcData forAssetId:(NSString *) assetId keyId:(NSString *)keyId leaseSeconds:(NSInteger *)outLeaseSeconds
{
    if (outLeaseSeconds) {
        *outLeaseSeconds = -1;
    }
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

    int maxAttempts = 4;
    double baseDelay = 3.0; // seconds
    double backoffFactor = 2.0;
    double fuzzFactor = 0.5;
    double timeout = 10.0;
    
    request.timeoutInterval = timeout;

    __block NSData *result = [[NSData alloc] initWithBase64EncodedString:@"" options:NSDataBase64DecodingIgnoreUnknownCharacters];
    __block NSInteger leaseParsed = -1;
    __block NSData *lastData = nil;
    __block NSURLResponse *lastResponse = nil;
    __block NSError *lastError = nil;

    __weak typeof(self) weakSelf = self;
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        self.licenseRequestTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            lastData = data;
            lastResponse = response;
            lastError = error;
            
            @try {
                do {
                    if (error || !data) break;
                    
                    NSDictionary *licenseObj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
                    if(!licenseObj) {
                        break;
                    }

                    id expiryVal = licenseObj[@"expireTime"] ?: licenseObj[@"expire_time"] ?: licenseObj[@"expiredTime"];
                    if ([expiryVal isKindOfClass:[NSNumber class]]) {
                        leaseParsed = [(NSNumber *)expiryVal longValue];
                    } else if ([expiryVal isKindOfClass:[NSString class]]) {
                        leaseParsed = [(NSString *)expiryVal integerValue];
                    }
                    
                    NSString *license = [licenseObj objectForKey:@"license"];
                    if(!license) {
                        NSLog(@"License is empty: %@", licenseObj);
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
        
        [self.licenseRequestTask resume];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * 10E9));
        
        if (result && result.length > 0) {
            break; // Success!
        }
        
        if (attempt < maxAttempts) {
            double delay = baseDelay * pow(backoffFactor, attempt - 1);
            double fuzz = delay * fuzzFactor;
            double randomFuzz = ((double)arc4random() / 0x100000000) * (2 * fuzz) - fuzz;
            delay = delay + randomFuzz;
            
            NSLog(@"[SigmaMultiDRM] Request failed. Retrying attempt %d in %.2f seconds...", attempt + 1, delay);
            [NSThread sleepForTimeInterval:delay];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!weakSelf || !weakSelf.delegate) return;
        id<SigmaMultiDRMDelegate> delegate = weakSelf.delegate;
        if (delegate && [delegate respondsToSelector:@selector(didCompleteLicenseRequestForAssetUrl:licenseData:response:error:)]) {
            [delegate didCompleteLicenseRequestForAssetUrl:weakSelf.assetUrl licenseData:lastData response:lastResponse error:lastError];
        }
    });

    if (outLeaseSeconds) {
        *outLeaseSeconds = leaseParsed;
    }
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
    if (self.debugMode) {//STAGING MODE
        return [NSString stringWithFormat:@"https://cert-staging.sigmadrm.com/app/fairplay/%@/%@", _merchant, _appId];
    }
    else { // PRODUCTION MODE
        return [NSString stringWithFormat:@"https://cert.sigmadrm.com/app/fairplay/%@/%@", _merchant, _appId];
    }
}
-(NSString *)licenseUrl:(NSString *)assetId keyId:(NSString *)keyId
{
    if (self.debugMode) {//STAGING MODE
        return [NSString stringWithFormat:@"https://license-staging.sigmadrm.com/license/verify/fairplay?assetId=%@&keyId=%@", assetId, keyId];
    }
    else { // PRODUCTION MODE
        return [NSString stringWithFormat:@"https://license.sigmadrm.com/license/verify/fairplay?assetId=%@&keyId=%@", assetId, keyId];
    }
}

- (void)cancelScheduledLicenseRenewal
{
    dispatch_block_t block = self.pendingLicenseRenewalBlock;
    if (block) {
        dispatch_block_cancel(block);
        self.pendingLicenseRenewalBlock = nil;
    }
}

- (void)scheduleLicenseRenewalAfterSeconds:(NSInteger)leaseSeconds session:(AVContentKeySession *)session keyRequest:(AVContentKeyRequest *)keyRequest
{
    [self cancelScheduledLicenseRenewal];
    if (leaseSeconds <= 0 || !session || !keyRequest) {
        if (leaseSeconds <= 0) {
            NSLog(@"[SigmaMultiDRM] No license renewal schedule (missing or non-positive expireTime from JSON).");
        }
        return;
    }
    dispatch_queue_t q = self.drmKeyQueue ?: dispatch_get_main_queue();
    NSTimeInterval delay = (NSTimeInterval)leaseSeconds - kSigmaFairPlayLicenseRenewLeadSeconds;
    if (delay < 0.5) {
        delay = MAX(0.2, (NSTimeInterval)leaseSeconds * 0.5);
    }
    __weak typeof(self) weakSelf = self;
    AVContentKeySession *sess = session;
    AVContentKeyRequest *req = keyRequest;
    dispatch_block_t work = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            if (@available(iOS 10.3, *)) {
                [sess renewExpiringResponseDataForContentKeyRequest:req];
                NSLog(@"[SigmaMultiDRM] Called renewExpiringResponseDataForContentKeyRequest (lease hint %lds).", (long)leaseSeconds);
            }
        } @catch (NSException *ex) {
            NSLog(@"[SigmaMultiDRM] renewExpiringResponseDataForContentKeyRequest exception: %@", ex.reason);
        }
        if (strongSelf.pendingLicenseRenewalBlock == work) {
            strongSelf.pendingLicenseRenewalBlock = nil;
        }
    });
    self.pendingLicenseRenewalBlock = work;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), q, work);
    NSLog(@"[SigmaMultiDRM] Scheduled license renewal in %.1fs (expireTime=%lds, lead=%.0fs).", delay, (long)leaseSeconds, (double)kSigmaFairPlayLicenseRenewLeadSeconds);
}

- (void) dealloc {
    [self cancelScheduledLicenseRenewal];
    if (self.certRequestTask && self.certRequestTask.state == NSURLSessionTaskStateRunning) {
        [self.certRequestTask cancel];
        self.certRequestTask = nil;
    }
    
    if (self.licenseRequestTask && self.licenseRequestTask.state == NSURLSessionTaskStateRunning) {
        [self.licenseRequestTask cancel];
        self.licenseRequestTask = nil;
    }
}
@end
