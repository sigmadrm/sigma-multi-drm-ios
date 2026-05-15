//
//  SContentKeyDelegate.h
//  AVARLDelegateDemo
//
//  Created by NguyenVanSao on 8/9/19.
//  Copyright © 2019 rajiv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SigmaMultiDRMDelegate.h"

NS_ASSUME_NONNULL_BEGIN

// Error Domain
extern NSString *const kSigmaMultiDRMErrorDomain;
// Error Codes
extern NSInteger const kSigmaMultiDRMErrorCertificateNil;
extern NSInteger const kSigmaMultiDRMErrorSPCNil;
extern NSInteger const kSigmaMultiDRMErrorLicenseNil;
extern NSInteger const kSigmaMultiDRMErrorPersistentKeyNil;
extern NSInteger const kSigmaMultiDRMErrorSaveFailed;
extern NSInteger const kSigmaMultiDRMErrorResponseCreationFailed;
extern NSInteger const kSigmaMultiDRMErrorException;

@interface SContentKeyDelegate : NSObject <AVContentKeySessionDelegate>

@property(nonatomic, assign) id<SigmaMultiDRMDelegate> delegate;

@property(nonatomic, retain) NSString *userId;
@property(nonatomic, retain) NSString *sessionId;
@property(nonatomic, retain) NSString *merchant;
@property(nonatomic, retain) NSString *appId;
@property(nonatomic, assign) BOOL debugMode;
@property(nonatomic, retain) NSString *assetUrl;
/// Same queue as `AVContentKeySession` delegate; used to schedule `renewExpiringResponseDataForContentKeyRequest:`.
@property (atomic, nullable) dispatch_queue_t drmKeyQueue;

@property(nonatomic, strong, nullable) NSURLSessionTask *certRequestTask;
@property(nonatomic, strong, nullable) NSURLSessionTask *licenseRequestTask;

- (NSDictionary *)query:(NSString *)url;
- (void)processOnlineKey:(AVContentKeySession *)session request:(AVContentKeyRequest *)keyRequest;
- (NSData *)getCertificateWithError:(NSError **)certError;
- (NSData *)requestKeyFromServer:(NSData *)spcData forAssetId:(NSString *)assetId keyId:(NSString *)variantId leaseSeconds:(NSInteger * _Nullable)outLeaseSeconds;

/// Cancels a pending `renewExpiringResponseDataForContentKeyRequest:` scheduled from JSON `expireTime`.
- (void)cancelScheduledLicenseRenewal;
/// Schedules proactive renewal using `-[AVContentKeySession renewExpiringResponseDataForContentKeyRequest:]`.
- (void)scheduleLicenseRenewalAfterSeconds:(NSInteger)leaseSeconds session:(AVContentKeySession *)session keyRequest:(AVContentKeyRequest *)keyRequest;
@end

NS_ASSUME_NONNULL_END
