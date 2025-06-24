import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:archive/archive.dart' as archive;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;

// ignore: import_of_legacy_library_into_null_safe
import 'proto/svga.pbserver.dart';

const _filterKey = 'SVGAParser';

/// You use SVGAParser to load and decode animation files.
class SVGAParser {
  const SVGAParser();
  static const shared = SVGAParser();
  
  // 图片解码缓存，提高重复图片的解码性能
  static final Map<String, ui.Image> _imageCache = <String, ui.Image>{};

  /// Download animation file from remote server, and decode it.
  Future<MovieEntity> decodeFromURL(String url) async {
    // 每次都返回新的实例，避免共享造成的问题
    // 但保留数据缓存以提高性能
    final response = await get(Uri.parse(url));
    return decodeFromBuffer(response.bodyBytes);
  }
  
  /// Download animation file from bundle assets, and decode it.
  Future<MovieEntity> decodeFromAssets(String path) async {
    // 每次都返回新的实例，避免共享造成的问题
    // 但保留数据缓存以提高性能
    return decodeFromBuffer((await rootBundle.load(path)).buffer.asUint8List());
  }
  

  
  /// 清空图片缓存
  static void clearImageCache() {
    _imageCache.clear();
  }

  /// Download animation file from buffer, and decode it.
  Future<MovieEntity> decodeFromBuffer(List<int> bytes) async {
    TimelineTask? timeline;
    if (!kReleaseMode) {
      timeline = TimelineTask(filterKey: _filterKey)
        ..start('DecodeFromBuffer', arguments: {'length': bytes.length});
    }
    
    try {
      // 在isolate中进行解压缩，避免阻塞UI线程
      final inflatedBytes = await _decompressInIsolate(bytes);
      
      if (timeline != null) {
        timeline.instant('MovieEntity.fromBuffer()',
            arguments: {'inflatedLength': inflatedBytes.length});
      }
      final movie = MovieEntity.fromBuffer(inflatedBytes);
      if (timeline != null) {
        timeline.instant('prepareResources()',
            arguments: {'images': movie.images.keys.join(',')});
      }
      return await _prepareResources(
        _processShapeItems(movie),
        timeline: timeline,
      );
    } finally {
      if (timeline != null) timeline.finish();
    }
  }
  
  /// 在isolate中进行解压缩操作
  Future<List<int>> _decompressInIsolate(List<int> bytes) async {
    if (bytes.length > 1024 * 1024) { // 大于1MB时使用isolate
      return await compute(_decompressBytes, bytes);
    } else {
      return _decompressBytes(bytes);
    }
  }
  
  static List<int> _decompressBytes(List<int> bytes) {
    return const archive.ZLibDecoder().decodeBytes(bytes);
  }
  


  MovieEntity _processShapeItems(MovieEntity movieItem) {
    for (var sprite in movieItem.sprites) {
      List<ShapeEntity>? lastShape;
      for (var frame in sprite.frames) {
        if (frame.shapes.isNotEmpty) {
          if (frame.shapes[0].type == ShapeEntity_ShapeType.KEEP &&
              lastShape != null) {
            frame.shapes = lastShape;
          } else {
            lastShape = frame.shapes;
          }
        }
      }
    }
    return movieItem;
  }

  Future<MovieEntity> _prepareResources(MovieEntity movieItem,
      {TimelineTask? timeline}) async {
    final images = movieItem.images;
    if (images.isEmpty) return movieItem;
    
    // 并发解码图片，提高性能
    final futures = images.entries.map((item) async {
      final decodeImage = await _decodeImageItem(
          item.key, Uint8List.fromList(item.value),
          timeline: timeline);
      if (decodeImage != null) {
        movieItem.bitmapCache[item.key] = decodeImage;
      }
    });
    
    await Future.wait(futures);
    return movieItem;
  }

  Future<ui.Image?> _decodeImageItem(String key, Uint8List bytes,
      {TimelineTask? timeline}) async {
    TimelineTask? task;
    if (!kReleaseMode) {
      task = TimelineTask(filterKey: _filterKey, parent: timeline)
        ..start('DecodeImage', arguments: {'key': key, 'length': bytes.length});
    }
    try {
      final image = await decodeImageFromList(bytes);
      if (task != null) {
        task.finish(
          arguments: {'imageSize': '${image.width}x${image.height}'},
        );
      }
      return image;
    } catch (e, stack) {
      if (task != null) {
        task.finish(arguments: {'error': '$e', 'stack': '$stack'});
      }
      assert(() {
        FlutterError.reportError(FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'svgaplayer',
          context: ErrorDescription('during prepare resource'),
          informationCollector: () sync* {
            yield ErrorSummary('Decoding image failed.');
          },
        ));
        return true;
      }());
      return null;
    }
  }
}
