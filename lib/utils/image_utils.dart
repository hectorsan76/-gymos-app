import 'package:flutter/material.dart';

ImageProvider? getMemberImage(String? url) {
  if (url == null || url.isEmpty) return null;

  return NetworkImage(
    '$url?t=${DateTime.now().millisecondsSinceEpoch}',
  );
}