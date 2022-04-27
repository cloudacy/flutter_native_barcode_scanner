## 0.4.0

- refactor!: remove iOS orientation handling ([9205a41](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/9205a4146b08aa651ddfebce91a60a1d8316d2a8))

### 0.4.1

- fix(iOS): fix video orientation ([40a70a0](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/40a70a0420cfc0a5d44a47b3c5d089d1e7a7cddc))

### 0.4.2

- fix(iOS): set capture quality to high ([c17ca76](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/c17ca76cb67f7b8cb05aff474fab428f03e61656))
- feat(iOS): add support for code39mod43 and itf14 ([5d0c90a](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/5d0c90a62b940e4fc7cb5f0538dd552c9312b125))

### 0.4.3

- refactor: mark BarcodeScannerTexture fields final These values shouldn't be mutated ([b3ce65d](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/b3ce65dc9287c340d81de79767944db5b947dbd4))
- feat: allow to crop previews ([f9b4bd3](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/f9b4bd3134c77bd7cd848aef2b8b216c7c639e0a))

### 0.4.4

- chore(android): use stable camerax dependency ([14651bf](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/14651bf83e02a021941769cf96de01ebc1cc74ff))
- fix(android): add missing cameraExecutor shutdown ([450c877](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/450c877a72b209775b2f1d9860aaa8dc83cc322c))

#### 0.4.5

- chore: update dependencies ([46ca10f](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/46ca10f4eda5a47418301198132763eb70ef2d53))

#### 0.4.6

- chore: update dependencies ([7d65d25](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/7d65d258a64084a4c4d1c8cd80fc7d3944fe68d4))
- perf(ios): reduce input size to 1280x720 for faster processing ([606addd](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/606addd812c8394cc6fb5829da255853df542156))
- feat(ios): add barcode format filter ([8645113](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/86451133d5ea238abfb1d9c9cb00effbe09f45f3))
- fix(android): remove camera feature requirement ([1db476a](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/1db476a2a3ac8fcebc4fe3ce49f832890dddabe7))

## 0.3.0

- refactor!: rename getCode to getBarcode ([c6fc199](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/c6fc199fd024c51a80bc69bc7346e23624c86221))
- refactor!: rename package to flutter_native_barcode_scanner ([97559ef](https://github.com/cloudacy/flutter_native_barcode_scanner/commit/97559eff8cb828d9bc63fc13be86a4f919799d21))

## 0.2.0

- feat!: introduce FlutterQrScan.getCode ([b9e08f7](https://github.com/cloudacy/flutter_qr_scan/commit/b9e08f7dc9fea78b74cff142659af89ad0be4f00))
- See commit logs for more changes.

### 0.2.1

- chore(android): update dependencies ([5321b20](https://github.com/cloudacy/flutter_qr_scan/commit/5321b20dd391a61b9634d050b7d0cbe08cd3b854))
- See commit logs for more changes.

## 0.1.0

- Enable null safety ([a395b55](https://github.com/cloudacy/flutter_qr_scan/commit/a395b55ce53ac10aa15dacac00abaa3578d8d4dd))
- [iOS] Fix previewWidth and previewHeight reporting. ([2101e10](https://github.com/cloudacy/flutter_qr_scan/commit/2101e1089d4d4b28d5cdf5aa4a65e0f156cf2885))
- [iOS] Fix device rotation ([dbd3677](https://github.com/cloudacy/flutter_qr_scan/commit/dbd367779515e7af86294b46ebefaaeca46d726d))
- See commit logs for more changes.

### 0.1.1

- Introduce FlutterQrScanPreview widget. ([467614f](https://github.com/cloudacy/flutter_qr_scan/commit/467614f15d2466d488688af9a12a67cec18ac5c7))
- [android] Fix previewWidth and previewHeight arguments. ([fd94cec](https://github.com/cloudacy/flutter_qr_scan/commit/fd94cec6744337586f3620f640bb28148e8e1ca8))
- See commit logs for more changes.

## 0.0.0

Implement basic features to scan QR-codes.
