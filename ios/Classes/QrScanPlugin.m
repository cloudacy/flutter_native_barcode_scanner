#import "QrScanPlugin.h"
#import <qr_scan/qr_scan-Swift.h>

@implementation QrScanPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftQrScanPlugin registerWithRegistrar:registrar];
}
@end
