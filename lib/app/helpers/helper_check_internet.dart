import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

Future<bool> isInternet() async {
  try {
    final List<ConnectivityResult> resultList =
        await Connectivity().checkConnectivity();
    final ConnectivityResult result = resultList.first;

    if (result == ConnectivityResult.none) {
      debugPrint("No internet connection. Please check your connection.");
      return false;
    } else {
      debugPrint("Internet connection is available.");
      return true;
    }
  } catch (e) {
    debugPrint("Error checking internet connectivity: ${e.toString()}");
    return false;
  }
}
