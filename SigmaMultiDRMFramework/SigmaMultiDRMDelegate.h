//
//  SigmaMultiDRMDelegate.h
//  SigmaMultiDRMFramework
//
//  Created by Assistant on 2024
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for handling license request callbacks
 */
@protocol SigmaMultiDRMDelegate <NSObject>

@optional

/**
 * Called when license request completes (success or failure)
 *
 * @param assetUrl The URL of the asset for which the license was requested
 * @param licenseData The license data received from the server (may be nil if request failed)
 * @param error The error that occurred during the license request (nil if successful)
 */
- (void)didCompleteLicenseRequestForAssetUrl:(NSString *)assetUrl licenseData:(NSData * _Nullable)licenseData response:( NSURLResponse * _Nullable )response error:( NSError * _Nullable )error;

@end

NS_ASSUME_NONNULL_END
