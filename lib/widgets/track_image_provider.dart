import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider trackImageProvider(String? thumbnail) {
  if (thumbnail == null || thumbnail.isEmpty) {
    return const AssetImage('assets/placeholder.png');
  }

  final uri = Uri.tryParse(thumbnail);
  if (uri != null && uri.scheme == 'file') {
    return FileImage(File(uri.path));
  }

  return NetworkImage(thumbnail);
}

