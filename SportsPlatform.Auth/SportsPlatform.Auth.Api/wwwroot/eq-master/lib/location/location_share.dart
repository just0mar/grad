import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'location_point.dart';

class LocationShare {
  static Future<void> share(LocationPoint point) async {
    await Share.share(point.shareText, subject: point.label ?? 'Location');
  }

  static Future<void> copy(LocationPoint point) {
    return Clipboard.setData(ClipboardData(text: point.shareText));
  }
}
