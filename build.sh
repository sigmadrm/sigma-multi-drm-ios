# PROJECT=sigma-multidrm-ios-sdk
# SCHEME=SigmaMultiDRMFramework
# OUTPUT=xcframeworks/$PROJECT.xcframework
# ARCHIVE_PATH="archives/$PROJECT-iOS"

# rm -rf $OUTPUT
# rm -rf $ARCHIVE_PATH

# xcodebuild archive \
#     -project $PROJECT.xcodeproj \
#     -scheme $SCHEME \
#     -destination "generic/platform=iOS" \
#     -archivePath $ARCHIVE_PATH \
#     BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
#     SKIP_INSTALL=NO \

    
# xcodebuild -create-xcframework \
#     -archive $ARCHIVE_PATH.xcarchive -framework $SCHEME.framework \
#     -output $OUTPUT

PROJECT=sigma-multidrm-ios-sdk
SCHEME=SigmaMultiDRMFramework
OUTPUT=xcframeworks/$PROJECT.xcframework
ARCHIVE_PATH_IOS="archives/$PROJECT-iOS"
ARCHIVE_PATH_SIMULATOR="archives/$PROJECT-iOS-Simulator"

# Cleanup old archives and outputs
rm -rf $OUTPUT
rm -rf $ARCHIVE_PATH_IOS
rm -rf $ARCHIVE_PATH_SIMULATOR

# Archive for iOS device
xcodebuild archive \
    -project $PROJECT.xcodeproj \
    -scheme $SCHEME \
    -destination "generic/platform=iOS" \
    -archivePath $ARCHIVE_PATH_IOS \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO

# Archive for iOS Simulator
xcodebuild archive \
    -project $PROJECT.xcodeproj \
    -scheme $SCHEME \
    -destination "generic/platform=iOS Simulator" \
    -archivePath $ARCHIVE_PATH_SIMULATOR \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO

# Create XCFramework
xcodebuild -create-xcframework \
    -archive $ARCHIVE_PATH_IOS.xcarchive -framework $SCHEME.framework \
    -archive $ARCHIVE_PATH_SIMULATOR.xcarchive -framework $SCHEME.framework \
    -output $OUTPUT
