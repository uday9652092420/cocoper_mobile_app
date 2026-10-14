import 'package:flutter/foundation.dart';

void consolePrint(dynamic val) {
  if (kDebugMode) {
    print(val);
  }
}
