import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helper to get an [ImageProvider] supporting network URLs, Base64 Data URIs, and local file paths.
ImageProvider? getAppImageProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final trimmed = url.trim();

  if (trimmed.startsWith('data:image/')) {
    try {
      final base64String = trimmed.split(',').last;
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  if (trimmed.startsWith('file://') || (!kIsWeb && !trimmed.startsWith('http://') && !trimmed.startsWith('https://') && File(trimmed).existsSync())) {
    try {
      final path = trimmed.startsWith('file://') ? trimmed.replaceFirst('file://', '') : trimmed;
      return FileImage(File(path));
    } catch (_) {
      return null;
    }
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }

  return NetworkImage(trimmed);
}

/// Helper widget to render images supporting Network URLs, Base64 Data URIs, and Local Files with proper error handling.
Widget buildAppImage(
  String? url, {
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
  Widget? placeholder,
  double? width,
  double? height,
  Key? key,
}) {
  if (url == null || url.trim().isEmpty) {
    return errorWidget ?? const SizedBox.shrink();
  }

  final trimmed = url.trim();

  // 1. Base64 Data URI
  if (trimmed.startsWith('data:image/')) {
    try {
      final base64String = trimmed.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        key: key,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (ctx, err, stack) => errorWidget ?? const SizedBox.shrink(),
      );
    } catch (_) {
      return errorWidget ?? const SizedBox.shrink();
    }
  }

  // 2. Local File
  if (trimmed.startsWith('file://') || (!kIsWeb && !trimmed.startsWith('http://') && !trimmed.startsWith('https://') && File(trimmed).existsSync())) {
    try {
      final path = trimmed.startsWith('file://') ? trimmed.replaceFirst('file://', '') : trimmed;
      return Image.file(
        File(path),
        key: key,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (ctx, err, stack) => errorWidget ?? const SizedBox.shrink(),
      );
    } catch (_) {
      return errorWidget ?? const SizedBox.shrink();
    }
  }

  // 3. Network URL
  return Image.network(
    trimmed,
    key: key,
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (ctx, err, stack) => errorWidget ?? const SizedBox.shrink(),
  );
}
