import 'dart:ui';

import 'utils.dart';

class QrScanCamera {
  final String id;
  final QrScanLensDirection lensDirection;

  QrScanCamera({this.id, this.lensDirection});

  @override
  bool operator ==(Object o) {
    return o is QrScanCamera && o.id == id && o.lensDirection == lensDirection;
  }

  @override
  int get hashCode {
    return hashValues(id, lensDirection);
  }

  @override
  String toString() {
    return '$runtimeType($id, $lensDirection)';
  }
}
