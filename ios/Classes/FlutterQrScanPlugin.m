#import "FlutterQrScanPlugin.h"
#if __has_include(<flutter_qr_scan/flutter_qr_scan-Swift.h>)
#import <flutter_qr_scan/flutter_qr_scan-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_qr_scan-Swift.h"
#endif

@implementation FlutterQrScanPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [FLQRScan registerWithRegistrar:registrar];
}
@end
