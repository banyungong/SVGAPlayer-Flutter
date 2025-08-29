import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'proto/svga.pbserver.dart';

/// SVGA资源缓存项
class SVGACacheItem {
  final String key;
  final MovieEntity movieEntity;
  final int sizeInBytes;
  DateTime lastAccessTime;

  SVGACacheItem({
    required this.key,
    required this.movieEntity,
    required this.sizeInBytes,
  }) : lastAccessTime = DateTime.now();

  void updateAccessTime() {
    lastAccessTime = DateTime.now();
  }
}

/// 图片缓存项  
class ImageCacheItem {
  final String hash;
  final ui.Image image;
  final int sizeInBytes;
  DateTime lastAccessTime;

  ImageCacheItem({
    required this.hash,
    required this.image,
    required this.sizeInBytes,
  }) : lastAccessTime = DateTime.now();

  void updateAccessTime() {
    lastAccessTime = DateTime.now();
  }
}

/// LRU缓存管理器
class SVGACache {
  static const int _defaultMaxSizeInBytes = 300 * 1024 * 1024; // 300MB
  static const int _defaultMaxCount = 100;

  final int maxSizeInBytes;
  final int maxCount;
  
  // SVGA完整资源缓存 (asset路径 -> 缓存项)
  final Map<String, SVGACacheItem> _cache = {};
  
  // 图片数据缓存 (图片数据哈希 -> 图片对象)
  final Map<String, ImageCacheItem> _imageCache = {};
  
  int _currentSizeInBytes = 0;
  int _currentImageSizeInBytes = 0;

  SVGACache({
    this.maxSizeInBytes = _defaultMaxSizeInBytes,
    this.maxCount = _defaultMaxCount,
  });

  /// 生成缓存键
  String _generateCacheKey(String path) {
    return path;
  }

  /// 生成图片数据的哈希
  String _generateImageHash(Uint8List imageData) {
    final digest = sha256.convert(imageData);
    return digest.toString();
  }

  /// 计算MovieEntity的内存占用大小
  int _calculateMovieEntitySize(MovieEntity entity) {
    int size = 0;
    
    // 基础结构大小估算
    size += 1024; // 基础对象大小
    
    // Sprites数据
    for (var sprite in entity.sprites) {
      size += 256; // sprite基础大小
      for (var frame in sprite.frames) {
        size += 128; // frame基础大小
        for (var shape in frame.shapes) {
          size += 64; // shape基础大小
          
          // 根据shape类型计算参数大小
          if (shape.hasShape()) {
            size += shape.shape.d.length * 2; // 字符串长度 * 2字节(UTF-16)
          }
          if (shape.hasRect()) {
            size += 40; // 5个double值 * 8字节
          }
          if (shape.hasEllipse()) {
            size += 32; // 4个double值 * 8字节
          }
          if (shape.hasStyles()) {
            size += 128; // styles基础大小
          }
        }
      }
    }
    
    // 音频数据 - 基于音频键和时间信息估算
    for (var audio in entity.audios) {
      size += audio.audioKey.length * 2; // 音频键字符串
      size += 20; // 其他audio字段(5个int)
    }
    return size;
  }

  /// 计算图片的内存占用大小
  int _calculateImageSize(ui.Image image) {
    // 图片内存占用 = 宽度 × 高度 × 4字节(RGBA)
    return image.width * image.height * 4;
  }

  /// 获取缓存的SVGA资源
  MovieEntity? get(String path) {
    final key = _generateCacheKey(path);
    final item = _cache[key];
    
    if (item != null) {
      item.updateAccessTime();
      
      // 直接返回原来的MovieEntity
      // 但将autorelease设为false，避免自动dispose
      final entity = item.movieEntity;
      entity.autorelease = false;
      
      return entity;
    }
    
    return null;
  }

  /// 获取缓存的图片
  ui.Image? getImage(Uint8List imageData) {
    final hash = _generateImageHash(imageData);
    final item = _imageCache[hash];
    
    if (item != null) {
      item.updateAccessTime();
      return item.image;
    }
    
    return null;
  }

  /// 缓存SVGA资源
  void put(String path, MovieEntity entity) {
    final key = _generateCacheKey(path);
    
    // 计算大小（包含解码后的图片）
    final entitySize = _calculateMovieEntitySize(entity);
    int imageSize = 0;
    for (var image in entity.bitmapCache.values) {
      imageSize += _calculateImageSize(image);
    }
    final totalSize = entitySize + imageSize;
    
    // 检查是否超过单个项目的大小限制
    if (totalSize > maxSizeInBytes * 0.5) {
      return;
    }
    
    // 执行LRU清理
    _evictIfNeeded(totalSize);
    
    // 设置autorelease为false，避免缓存的资源被意外释放
    entity.autorelease = false;
    
    // 添加到缓存
    final item = SVGACacheItem(
      key: key,
      movieEntity: entity,
      sizeInBytes: totalSize,
    );
    
    _cache[key] = item;
    _currentSizeInBytes += totalSize;
  }

  /// 缓存图片
  void putImage(Uint8List imageData, ui.Image image) {
    final hash = _generateImageHash(imageData);
    final size = _calculateImageSize(image);
    
    // 检查是否已存在
    if (_imageCache.containsKey(hash)) {
      return;
    }
    
    // 检查单个图片大小限制
    if (size > maxSizeInBytes * 0.1) {
      return;
    }
    
    // 执行图片缓存的LRU清理
    _evictImageIfNeeded(size);
    
    final item = ImageCacheItem(
      hash: hash,
      image: image,
      sizeInBytes: size,
    );
    
    _imageCache[hash] = item;
    _currentImageSizeInBytes += size;
  }

  /// LRU清理主缓存
  void _evictIfNeeded(int newItemSize) {
    // 按数量限制清理
    while (_cache.length >= maxCount) {
      _evictLeastRecentlyUsed();
    }
    
    // 按大小限制清理
    while (_currentSizeInBytes + newItemSize > maxSizeInBytes && _cache.isNotEmpty) {
      _evictLeastRecentlyUsed();
    }
  }

  /// LRU清理图片缓存
  void _evictImageIfNeeded(int newItemSize) {
    final maxImageCacheSize = maxSizeInBytes ~/ 4; // 图片缓存占总缓存的1/4
    
    // 按大小限制清理图片缓存
    while (_currentImageSizeInBytes + newItemSize > maxImageCacheSize && _imageCache.isNotEmpty) {
      _evictLeastRecentlyUsedImage();
    }
  }

  /// 清理最近最少使用的SVGA资源
  void _evictLeastRecentlyUsed() {
    if (_cache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (var entry in _cache.entries) {
      if (oldestTime == null || entry.value.lastAccessTime.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessTime;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      final item = _cache.remove(oldestKey)!;
      _currentSizeInBytes -= item.sizeInBytes;
      
      // 🔧 修复：检查MovieEntity的引用计数，只有在没有引用时才释放
      final entity = item.movieEntity;
      if (entity.referenceCount <= 0 && !entity.isDisposed) {
        // 安全释放：先检查bitmapCache中的图片是否在imageCache中
        _cleanupMovieEntityImages(entity);
        entity.dispose();
      }
    }
  }

  /// 清理最近最少使用的图片
  void _evictLeastRecentlyUsedImage() {
    if (_imageCache.isEmpty) return;
    
    String? oldestHash;
    DateTime? oldestTime;
    
    for (var entry in _imageCache.entries) {
      if (oldestTime == null || entry.value.lastAccessTime.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessTime;
        oldestHash = entry.key;
      }
    }
    
    if (oldestHash != null) {
      final item = _imageCache.remove(oldestHash)!;
      _currentImageSizeInBytes -= item.sizeInBytes;
      
      // 🔧 修复：检查图片是否还在其他地方被使用
      if (_canSafelyDisposeImage(item.image)) {
        try {
          item.image.dispose();
        } catch (e) {
          // 图片可能已经被释放，忽略错误
          if (kDebugMode) {
            print('Warning: Error disposing cached image - $e');
          }
        }
      }
    }
  }

  /// 清空所有缓存
  void clear() {
    // 🔧 修复：清理前先安全释放所有图片资源
    for (final item in _imageCache.values) {
      if (_canSafelyDisposeImage(item.image)) {
        try {
          item.image.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Error disposing image during cache clear - $e');
          }
        }
      }
    }
    
    // 清理MovieEntity，但不强制dispose（可能还有引用）
    for (final item in _cache.values) {
      final entity = item.movieEntity;
      _cleanupMovieEntityImages(entity);
      // 只在没有外部引用时才dispose
      if (entity.referenceCount <= 0 && !entity.isDisposed) {
        entity.dispose();
      }
    }
    
    _cache.clear();
    _imageCache.clear();
    _currentSizeInBytes = 0;
    _currentImageSizeInBytes = 0;
  }

  /// 清空过期缓存 (超过指定时间未访问)
  void clearExpired(Duration maxAge) {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    final expiredImageHashes = <String>[];
    
    // 查找过期的SVGA缓存
    for (var entry in _cache.entries) {
      if (now.difference(entry.value.lastAccessTime) > maxAge) {
        expiredKeys.add(entry.key);
      }
    }
    
    // 查找过期的图片缓存
    for (var entry in _imageCache.entries) {
      if (now.difference(entry.value.lastAccessTime) > maxAge) {
        expiredImageHashes.add(entry.key);
      }
    }
    
    // 移除过期的SVGA项目
    for (var key in expiredKeys) {
      final item = _cache.remove(key)!;
      _currentSizeInBytes -= item.sizeInBytes;
      
      // 🔧 修复：安全处理过期的MovieEntity
      final entity = item.movieEntity;
      if (entity.referenceCount <= 0 && !entity.isDisposed) {
        _cleanupMovieEntityImages(entity);
        entity.dispose();
      }
    }
    
    // 移除过期的图片项目
    for (var hash in expiredImageHashes) {
      final item = _imageCache.remove(hash)!;
      _currentImageSizeInBytes -= item.sizeInBytes;
      
      // 🔧 修复：安全dispose过期的图片
      if (_canSafelyDisposeImage(item.image)) {
        try {
          item.image.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('Warning: Error disposing expired image - $e');
          }
        }
      }
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    return {
      'svga_cache': {
        'count': _cache.length,
        'size_bytes': _currentSizeInBytes,
        'size_formatted': _formatBytes(_currentSizeInBytes),
        'max_count': maxCount,
        'max_size_bytes': maxSizeInBytes,
        'max_size_formatted': _formatBytes(maxSizeInBytes),
        'usage_percentage': (_currentSizeInBytes / maxSizeInBytes * 100).toStringAsFixed(1),
      },
      'image_cache': {
        'count': _imageCache.length,
        'size_bytes': _currentImageSizeInBytes,
        'size_formatted': _formatBytes(_currentImageSizeInBytes),
        'max_size_bytes': maxSizeInBytes ~/ 4,
        'max_size_formatted': _formatBytes(maxSizeInBytes ~/ 4),
        'usage_percentage': (_currentImageSizeInBytes / (maxSizeInBytes ~/ 4) * 100).toStringAsFixed(1),
      },
      'total': {
        'size_bytes': _currentSizeInBytes + _currentImageSizeInBytes,
        'size_formatted': _formatBytes(_currentSizeInBytes + _currentImageSizeInBytes),
        'max_size_bytes': maxSizeInBytes,
        'max_size_formatted': _formatBytes(maxSizeInBytes),
        'usage_percentage': ((_currentSizeInBytes + _currentImageSizeInBytes) / maxSizeInBytes * 100).toStringAsFixed(1),
      }
    };
  }

  /// 🔧 新增：清理MovieEntity中的图片引用，避免双重dispose
  void _cleanupMovieEntityImages(MovieEntity entity) {
    // 遍历MovieEntity的bitmapCache，移除在imageCache中的重复引用
    final imagesToRemove = <String>[];
    
    for (final imageEntry in entity.bitmapCache.entries) {
      final image = imageEntry.value;
      
      // 查找这个图片是否也在imageCache中
      for (final cacheEntry in _imageCache.entries) {
        if (identical(cacheEntry.value.image, image)) {
          // 找到了重复引用，从imageCache中移除（但不dispose，让MovieEntity处理）
          imagesToRemove.add(cacheEntry.key);
          _currentImageSizeInBytes -= cacheEntry.value.sizeInBytes;
        }
      }
    }
    
    // 移除重复的图片缓存项
    for (final hash in imagesToRemove) {
      _imageCache.remove(hash);
    }
  }
  
  /// 🔧 新增：检查图片是否可以安全dispose
  bool _canSafelyDisposeImage(ui.Image image) {
    // 检查这个图片是否还在任何MovieEntity的bitmapCache中被使用
    for (final cacheItem in _cache.values) {
      final entity = cacheItem.movieEntity;
      if (!entity.isDisposed) {
        for (final cachedImage in entity.bitmapCache.values) {
          if (identical(cachedImage, image)) {
            // 图片还在使用中，不能dispose
            return false;
          }
        }
        // 也检查动态图片
        for (final dynamicImage in entity.dynamicItem.dynamicImages.values) {
          if (identical(dynamicImage, image)) {
            return false;
          }
        }
      }
    }
    return true;
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
} 