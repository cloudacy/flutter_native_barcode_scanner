#import "FlutterNativeBarcodeScannerPlugin.h"
#if __has_include(<flutter_native_barcode_scanner/flutter_native_barcode_scanner-Swift.h>)
#import <flutter_native_barcode_scanner/flutter_native_barcode_scanner-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_native_barcode_scanner-Swift.h"
#endif

@implementation FlutterNativeBarcodeScannerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [FLNativeBarcodeScanner registerWithRegistrar:registrar];
}
@end
