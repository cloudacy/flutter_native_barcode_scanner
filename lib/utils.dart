import 'package:flutter/services.dart';

const MethodChannel qrScanMethodChannel = MethodChannel('io.cloudacy.qr_scan');

enum QrScanLensDirection { front, back, external }
enum QrScanCodeFormat { codabar, code39, code93, code128, ean8, ean13, itf, upca, upce, aztec, datamatrix, pdf417, qr }
enum QrScanResolution { low, medium, high }

const qrScanCodeFormats = {
  QrScanCodeFormat.codabar: 'codabar', // Android only
  QrScanCodeFormat.code39: 'code39',
  QrScanCodeFormat.code93: 'code93',
  QrScanCodeFormat.code128: 'code128',
  QrScanCodeFormat.ean8: 'ean8',
  QrScanCodeFormat.ean13: 'ean13',
  QrScanCodeFormat.itf: 'itf', // itf-14 on iOS, should be changed to Interleaved2of5?
  QrScanCodeFormat.upca: 'upca', // Android only
  QrScanCodeFormat.upce: 'upce',
  QrScanCodeFormat.aztec: 'aztec',
  QrScanCodeFormat.datamatrix: 'datamatrix',
  QrScanCodeFormat.pdf417: 'pdf417',
  QrScanCodeFormat.qr: 'qr',
};

const qrScanResolutions = {
  QrScanResolution.low: 'low',
  QrScanResolution.medium: 'medium',
  QrScanResolution.high: 'high'
};

const qrScanLensdirectionInv = {
  'front': QrScanLensDirection.front,
  'back': QrScanLensDirection.back,
  'external': QrScanLensDirection.external
};

/// This is thrown when the plugin reports an error.
class QrScanException implements Exception {
  String code;
  String message;

  QrScanException(this.code, this.message);

  @override
  String toString() => '$runtimeType($code, $message)';
}
