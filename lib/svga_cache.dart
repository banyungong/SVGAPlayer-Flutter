
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


/// LRU缓存管理器
class SVGACache {
  static const int _defaultMaxSizeInBytes = 100 * 1024 * 1024; // 50MB
  static const int _defaultMaxCount = 30;

  final int maxSizeInBytes;
  final int maxCount;
  
  // SVGA完整资源缓存 (asset路径 -> 缓存项)
  final Map<String, SVGACacheItem> _cache = {};
  
  int _currentSizeInBytes = 0;

  SVGACache({
    this.maxSizeInBytes = _defaultMaxSizeInBytes,
    this.maxCount = _defaultMaxCount,
  });

  /// 生成缓存键
  String _generateCacheKey(String path) {
    return path;
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
      print("SVGA:缓存复用");
      return entity;
    }
    
    return null;
  }


  /// 缓存SVGA资源
  void put(String path, MovieEntity entity) {
    final key = _generateCacheKey(path);
    
    // 计算大小
    final totalSize = _calculateMovieEntitySize(entity);
    
    // 检查是否超过单个项目的大小限制
    if (totalSize > maxSizeInBytes * 0.5) {
      print("SVGA:检查是否超过单个项目的大小限制");
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
    print("SVGA: ${_cache.length} ${_currentSizeInBytes}");

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
    }
  }


  /// 清空所有缓存
  void clear() {
    _cache.clear();
    _currentSizeInBytes = 0;
  }

  /// 清空过期缓存 (超过指定时间未访问)
  void clearExpired(Duration maxAge) {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    // 查找过期的SVGA缓存
    for (var entry in _cache.entries) {
      if (now.difference(entry.value.lastAccessTime) > maxAge) {
        expiredKeys.add(entry.key);
      }
    }
    
    // 移除过期项目
    for (var key in expiredKeys) {
      final item = _cache.remove(key)!;
      _currentSizeInBytes -= item.sizeInBytes;
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
    };
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
} 