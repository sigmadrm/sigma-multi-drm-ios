PROJECT=sigma-multidrm-ios-sdk
SCHEME=SigmaMultiDRMFramework
OUTPUT=xcframeworks/$PROJECT.xcframework
ARCHIVE_PATH="archives/$PROJECT-iOS"

rm -rf $OUTPUT
rm -rf $ARCHIVE_PATH

xcodebuild archive \
    -project $PROJECT.xcodeproj \
    -scheme $SCHEME \
    -destination "generic/platform=iOS" \
    -archivePath $ARCHIVE_PATH \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \


xcodebuild -create-xcframework \
    -archive $ARCHIVE_PATH.xcarchive -framework $SCHEME.framework \
    -output $OUTPUT