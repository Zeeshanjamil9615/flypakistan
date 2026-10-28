import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tour_model.dart';

/// Sends a tour (or car) enquiry to the Fly Pakistan WhatsApp number.
///
/// Android: the photo is downloaded and handed to WhatsApp through the
/// native share intent in MainActivity, so the chat opens with the photo
/// attached and the enquiry as its caption.
/// Elsewhere (or if that fails) a wa.me chat is opened with the enquiry text
/// plus the photo link — wa.me links cannot carry attachments.
class TourWhatsApp {
  /// 0345 9668442 in international format.
  static const String phone = '923459668442';

  static const MethodChannel _channel = MethodChannel('flypakistan/whatsapp');

  /// Same wording as the website's "Book via WhatsApp" button.
  static String message(TourModel tour) =>
      "Hello! I'm interested in the ${tour.name} tour. "
      'Can you please provide more details?';

  static Future<bool> send(TourModel tour) => sendEnquiry(
        text: message(tour),
        imageUrl: tour.image,
        fileName: 'tour_${tour.id}',
      );

  /// Opens the chat with [text] and the photo at [imageUrl] attached.
  /// [fileName] names the cached copy of the photo (without extension).
  /// Returns false only when WhatsApp could not be opened at all.
  static Future<bool> sendEnquiry({
    required String text,
    required String imageUrl,
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      final File? image = await _downloadImage(imageUrl, fileName);
      if (image != null) {
        try {
          final bool? shared = await _channel.invokeMethod<bool>('shareImage', {
            'phone': phone,
            'text': text,
            'path': image.path,
            'mimeType': _mimeType(image.path),
          });
          if (shared == true) return true;
        } catch (e) {
          print('TourWhatsApp share error: $e');
        }
      }
    }

    return _openChat(text, imageUrl);
  }

  static Future<bool> _openChat(String text, String imageUrl) async {
    final String body =
        imageUrl.startsWith('http') ? '$text\n\n$imageUrl' : text;
    final Uri uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(body)}',
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      return false;
    }
  }

  /// Downloads the photo into the cache folder MainActivity's FileProvider
  /// exposes (`cache/tour_shares/`). Reuses an earlier download.
  static Future<File?> _downloadImage(String url, String fileName) async {
    if (!url.startsWith('http')) return null;
    try {
      final Directory cache = await getTemporaryDirectory();
      final Directory dir = Directory('${cache.path}/tour_shares');
      await dir.create(recursive: true);

      final File file = File('${dir.path}/$fileName${_extension(url)}');
      if (await file.exists() && await file.length() > 0) return file;

      // Download to a temp name first so a broken download is never reused.
      final String partPath = '${file.path}.part';
      await Dio().download(
        url,
        partPath,
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return await File(partPath).rename(file.path);
    } catch (e) {
      print('TourWhatsApp image download error: $e');
      return null;
    }
  }

  static String _extension(String url) {
    final String path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  static String _mimeType(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
