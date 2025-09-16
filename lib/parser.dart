import 'dart:developer';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:archive/archive.dart' as archive;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;

// ignore: import_of_legacy_library_into_null_safe
import 'proto/svga.pbserver.dart';
import 'svga_cache.dart';
import 'svga_config.dart';

const _filterKey = 'SVGAParser';

/// You use SVGAParser to load and decode animation files.
class SVGAParser {
  const SVGAParser();
  static const shared = SVGAParser();
  
  // LRU缓存实例，默认50MB，最多100个文件
  static final SVGACache _cache = SVGACache();
  
  // 优化配置，默认使用平衡模式
  static SVGAOptimizationConfig _optimizationConfig = SVGAOptimizationConfig.balanced;
  
  /// 设置优化配置
  static void setOptimizationConfig(SVGAOptimizationConfig config) {
    _optimizationConfig = config;
    config.log('SVGA优化配置已更新: ${config.runtimeType}');
  }
  
  /// 获取当前优化配置
  static SVGAOptimizationConfig get optimizationConfig => _optimizationConfig;

  /// Download animation file from remote server, and decode it.
  Future<MovieEntity> decodeFromURL(String url) async {
    // 首先尝试从缓存获取
    final cached = _cache.get(url);
    if (cached != null) {
      // 缓存命中时不需要增加引用计数，因为get()方法已经设置了autorelease=false
      return cached;
    }
    
    // 缓存未命中，下载并解析
    final response = await get(Uri.parse(url));
    return decodeFromBuffer(response.bodyBytes, cacheKey: url);
  }

  /// Download animation file from bundle assets, and decode it.
  Future<MovieEntity> decodeFromAssets(String path) async {
    // 首先尝试从缓存获取
    final cached = _cache.get(path);
    if (cached != null) {
      // 缓存命中时不需要增加引用计数，因为get()方法已经设置了autorelease=false
      return cached;
    }
    
    // 缓存未命中，从资产加载并解析
    return decodeFromBuffer((await rootBundle.load(path)).buffer.asUint8List(), cacheKey: path);
  }

  /// Load animation file from local file system, and decode it.
  Future<MovieEntity> decodeFromFile(String filePath) async {
    // 使用文件的绝对路径作为缓存键，确保唯一性
    final file = File(filePath);
    final absolutePath = file.absolute.path;
    
    // 首先尝试从缓存获取
    final cached = _cache.get(absolutePath);
    if (cached != null) {
      // 缓存命中时不需要增加引用计数，因为get()方法已经设置了autorelease=false
      return cached;
    }
    
    // 检查文件是否存在
    if (!await file.exists()) {
      throw Exception('SVGA file not found: $filePath');
    }
    
    try {
      // 缓存未命中，从本地文件加载并解析
      final bytes = await file.readAsBytes();
      return decodeFromBuffer(bytes, cacheKey: absolutePath);
    } catch (e) {
      throw Exception('Failed to read SVGA file: $filePath, error: $e');
    }
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
  
  /// 清理重复的图片缓存
  static void cleanupDuplicateImages() {
    _cache.cleanupDuplicateImages();
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
      
      // 初始化引用计数（parser创建的实例默认有1个引用）
      result.addReference();
      
      // 如果有缓存键，将结果加入缓存
      if (cacheKey != null) {
        _cache.put(cacheKey, result);
      }
      
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
    // 先处理形状继承
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
    
    // 精灵过滤优化
    if (_optimizationConfig.enableSpriteFiltering) {
      movieItem = _filterSprites(movieItem);
    }
    
    // 音频过滤优化
    if (!_optimizationConfig.loadAudio) {
      movieItem.audios.clear();
      _optimizationConfig.log('已移除所有音频数据');
    }
    
    return movieItem;
  }
  
  /// 过滤超大精灵
  MovieEntity _filterSprites(MovieEntity movieItem) {
    final originalSpriteCount = movieItem.sprites.length;
    final spritesToRemove = <int>[];
    
    for (int i = 0; i < movieItem.sprites.length; i++) {
      final sprite = movieItem.sprites[i];
      
      // 检查精灵的图片资源
      if (sprite.imageKey.isNotEmpty && movieItem.images.containsKey(sprite.imageKey)) {
        final imageData = movieItem.images[sprite.imageKey]!;
        
        // 估算解码后的内存占用
        // 这里使用一个简单的估算：假设图片是方形的，根据文件大小推算
        final estimatedMemory = _estimateSpriteMemory(imageData, sprite);
        
        if (estimatedMemory > _optimizationConfig.maxSpriteMemoryBytes) {
          spritesToRemove.add(i);
          _optimizationConfig.log(
            '精灵 ${sprite.imageKey} 预估内存过大 (${_optimizationConfig.formatBytes(estimatedMemory)})，已丢弃'
          );
        }
      }
    }
    
    // 从后往前删除，避免索引变化
    for (int i = spritesToRemove.length - 1; i >= 0; i--) {
      final index = spritesToRemove[i];
      final sprite = movieItem.sprites.removeAt(index);
      
      // 检查是否还有其他精灵使用相同的图片资源
      final imageKey = sprite.imageKey;
      if (imageKey.isNotEmpty) {
        final stillInUse = movieItem.sprites.any((s) => s.imageKey == imageKey);
        if (!stillInUse) {
          // 只有在没有其他精灵使用时才移除图片资源
          movieItem.images.remove(imageKey);
          _optimizationConfig.log('移除未使用的图片资源: $imageKey');
        } else {
          _optimizationConfig.log('图片资源仍在使用，保留: $imageKey');
        }
      }
    }
    
    if (spritesToRemove.isNotEmpty) {
      _optimizationConfig.log(
        '精灵过滤完成: 原有${originalSpriteCount}个，丢弃${spritesToRemove.length}个，保留${movieItem.sprites.length}个'
      );
    }
    
    return movieItem;
  }
  
  /// 估算精灵内存占用
  int _estimateSpriteMemory(List<int> imageData, SpriteEntity sprite) {
    // 基于文件大小的粗略估算
    // 一般来说，解码后的图片内存是文件大小的数倍到数十倍
    final fileSize = imageData.length;
    
    // 根据文件大小估算解码后的尺寸
    // 这是一个经验公式，可以根据实际情况调整
    int estimatedPixels;
    if (fileSize < 50 * 1024) { // 小于50KB
      estimatedPixels = fileSize * 50; // 假设压缩比1:50
    } else if (fileSize < 200 * 1024) { // 小于200KB
      estimatedPixels = fileSize * 100; // 假设压缩比1:100
    } else { // 大文件
      estimatedPixels = fileSize * 200; // 假设压缩比1:200
    }
    
    // RGBA = 4字节每像素
    return estimatedPixels * 4;
  }

  Future<MovieEntity> _prepareResources(MovieEntity movieItem,
      {TimelineTask? timeline}) async {
    final images = movieItem.images;
    if (images.isEmpty) return movieItem;
    
    // 并发解码图片，提高性能
    final futures = images.entries.map((item) async {
      final decodeImage = await _decodeImageItem(
          item.key, Uint8List.fromList(item.value),
          timeline: timeline,
          createIndependentCopy: false, // 先禁用独立副本功能
      );
      if (decodeImage != null) {
        movieItem.bitmapCache[item.key] = decodeImage;
      }
    });
    
    await Future.wait(futures);
    return movieItem;
  }

  Future<ui.Image?> _decodeImageItem(String key, Uint8List bytes,
      {TimelineTask? timeline, bool createIndependentCopy = false}) async {
    // 首先尝试从图片缓存获取
    final cachedImage = _cache.getImage(bytes);
    if (cachedImage != null && !createIndependentCopy) {
      return cachedImage;
    }
    
    // 如果需要创建独立副本，即使有缓存也要重新解码
    if (createIndependentCopy && cachedImage != null) {
      // 创建现有图片的独立副本
      return await _createImageCopy(cachedImage);
    }
    
    TimelineTask? task;
    if (!kReleaseMode) {
      task = TimelineTask(filterKey: _filterKey, parent: timeline)
        ..start('DecodeImage', arguments: {'key': key, 'length': bytes.length});
    }
    try {
      // 先解码获取原始尺寸
      final originalImage = await decodeImageFromList(bytes);
      
      // 检查是否需要丢弃
      if (_optimizationConfig.shouldDiscardImage(originalImage.width, originalImage.height)) {
        final memoryMB = _optimizationConfig.calculateImageMemory(originalImage.width, originalImage.height);
        _optimizationConfig.log(
          '图片 $key 内存过大 (${originalImage.width}x${originalImage.height}, ${_optimizationConfig.formatBytes(memoryMB)})，已丢弃'
        );
        originalImage.dispose();
        return null;
      }
      
      ui.Image? finalImage = originalImage;
      
      // 检查是否需要压缩
      if (_optimizationConfig.shouldCompressImage(originalImage.width, originalImage.height)) {
        final targetSize = _optimizationConfig.calculateCompressedSize(originalImage.width, originalImage.height);
        
        _optimizationConfig.log(
          '压缩图片 $key: ${originalImage.width}x${originalImage.height} -> ${targetSize.width.toInt()}x${targetSize.height.toInt()}'
        );
        
        // 执行图片压缩
        finalImage = await _compressImage(originalImage, targetSize);
        originalImage.dispose(); // 释放原始图片
      }
      
      if (task != null) {
        task.finish(
          arguments: {
            'imageSize': '${finalImage.width}x${finalImage.height}',
            'compressed': finalImage != originalImage,
          },
        );
      }
      
      // 🔧 修复：直接使用putImage方法，它内部已经有重复检查逻辑
      if (!createIndependentCopy) {
        _cache.putImage(bytes, finalImage);
      }
      
      return finalImage;
    } catch (e, stack) {
      if (task != null) {
        task.finish(arguments: {'error': '$e', 'stack': '$stack'});
      }
      print('SVGAParser._decodeImageItem: 解码图片失败: $e');
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
  
  /// 压缩图片
  Future<ui.Image> _compressImage(ui.Image originalImage, ui.Size targetSize) async {
    try {
      // 验证输入参数
      if (targetSize.width <= 0 || targetSize.height <= 0) {
        _optimizationConfig.log('压缩图片失败: 目标尺寸无效 ${targetSize.width}x${targetSize.height}');
        return originalImage;
      }
      
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      
      // 使用高质量的图片缩放
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.high;
      
      // 将原图绘制到目标尺寸
      canvas.drawImageRect(
        originalImage,
        ui.Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        paint,
      );
      
      final picture = recorder.endRecording();
      final compressedImage = await picture.toImage(
        targetSize.width.toInt(),
        targetSize.height.toInt(),
      );
      
      picture.dispose();
      return compressedImage;
    } catch (e) {
      _optimizationConfig.log('压缩图片失败: $e');
      // 如果压缩失败，返回原图
      return originalImage;
    }
  }
  
  /// 创建图片的独立副本
  /// 
  /// 在多实例场景下，为每个MovieEntity创建独立的ui.Image副本，
  /// 避免多个实例共享同一个ui.Image对象导致的资源释放冲突。
  Future<ui.Image> _createImageCopy(ui.Image originalImage) async {
    try {
      // 创建画布记录器
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      
      // 使用高质量过滤器确保副本质量
      final paint = ui.Paint()
        ..filterQuality = ui.FilterQuality.high;
      
      // 将原图按原始尺寸绘制到新的canvas上
      canvas.drawImageRect(
        originalImage,
        ui.Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
        paint,
      );
      
      // 结束录制并生成新的ui.Image对象
      final picture = recorder.endRecording();
      final copiedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );
      
      // 清理临时资源
      picture.dispose();
      
      if (kDebugMode) {
        print('SVGAParser: 为多实例场景创建了图片副本 ${originalImage.width}x${originalImage.height}');
      }
      
      return copiedImage;
    } catch (e) {
      if (kDebugMode) {
        print('SVGAParser: 创建图片副本失败: $e，返回原图');
      }
      // 如果创建副本失败，返回原图（虽然可能导致资源冲突，但至少不会崩溃）
      return originalImage;
    }
  }
}
