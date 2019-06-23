#import "QrScanPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <CoreMotion/CoreMotion.h>
#import <libkern/OSAtomic.h>

#import <qr_scan/qr_scan-Swift.h>

@implementation QrScanPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftQrScanPlugin registerWithRegistrar:registrar];
}
@end
