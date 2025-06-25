import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;

// ignore: import_of_legacy_library_into_null_safe
import 'proto/svga.pbserver.dart';
import 'svga_cache.dart';

const _filterKey = 'SVGAParser';

/// You use SVGAParser to load and decode animation files.
class SVGAParser {
  const SVGAParser();
  static const shared = SVGAParser();
  
  // LRU缓存实例，默认50MB，最多100个文件
  static final SVGACache _cache = SVGACache();

  /// Download animation file from remote server, and decode it.
  Future<MovieEntity> decodeFromURL(String url) async {
    // 首先尝试从缓存获取
    final cached = _cache.get(url);
    if (cached != null) {
      return cached;
    }
    
    // 缓存未命中，下载并解析
    final response = await get(Uri.parse(url));
    return decodeFromBuffer(response.bodyBytes, cacheKey: url);
  }
  
  /// Download animation file from bundle assets, and decode it.
  Future<MovieEntity> decodeFromAssets(String path) async {
    print('SVGAParser.decodeFromAssets: 请求加载 $path');
    
    // 首先尝试从缓存获取
    final cached = _cache.get(path);
    if (cached != null) {
      print('SVGAParser.decodeFromAssets: 缓存命中，返回已存在的MovieEntity (hashCode: ${cached.hashCode})');
      return cached;
    }
    
    print('SVGAParser.decodeFromAssets: 缓存未命中，开始解析新的MovieEntity');
    // 缓存未命中，从资产加载并解析
    return decodeFromBuffer((await rootBundle.load(path)).buffer.asUint8List(), cacheKey: path);
  }
  
  /// 获取缓存统计信息
  static Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }
  
  /// 清空所有缓存
  static void clearCache() {
    _cache.clear();
  }
  
  /// 清空过期缓存
  static void clearExpiredCache(Duration maxAge) {
    _cache.clearExpired(maxAge);
  }

  /// Download animation file from buffer, and decode it.
  Future<MovieEntity> decodeFromBuffer(List<int> bytes, {String? cacheKey}) async {
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
      final processedMovie = _processShapeItems(movie);
      final result = await _prepareResources(
        processedMovie,
        timeline: timeline,
      );
      
      // 如果有缓存键，将结果加入缓存
      if (cacheKey != null) {
        log('SVGAParser.decodeFromBuffer: 将新解析的MovieEntity加入缓存 (hashCode: ${result.hashCode})');
        _cache.put(cacheKey, result);
      }
      
      log('SVGAParser.decodeFromBuffer: 返回MovieEntity (hashCode: ${result.hashCode})');
      return result;
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
    // 首先尝试从图片缓存获取
    final cachedImage = _cache.getImage(bytes);
    if (cachedImage != null) {
      return cachedImage;
    }
    
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
      
      // 将解码的图片加入缓存
      _cache.putImage(bytes, image);
      
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
