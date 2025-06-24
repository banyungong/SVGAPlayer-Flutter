import 'dart:developer';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'proto/svga.pbserver.dart';

/// SVGA性能管理器
/// 负责内存管理、性能监控和优化建议
class SVGAPerformanceManager {
  static final SVGAPerformanceManager _instance = SVGAPerformanceManager._internal();
  factory SVGAPerformanceManager() => _instance;
  SVGAPerformanceManager._internal();

  // 性能统计
  final Map<String, int> _frameRenderCounts = <String, int>{};
  final Map<String, int> _memoryUsage = <String, int>{};
  Timer? _memoryCleanupTimer;
  
  static const int _maxCacheEntries = 50;
  static const int _cleanupIntervalSeconds = 30;

  /// 初始化性能管理器
  void initialize() {
    _memoryCleanupTimer ??= Timer.periodic(
      const Duration(seconds: _cleanupIntervalSeconds),
      (_) => _performMemoryCleanup(),
    );
  }

  /// 销毁性能管理器
  void dispose() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = null;
    _frameRenderCounts.clear();
    _memoryUsage.clear();
  }

  /// 记录帧渲染
  void recordFrameRender(String movieId, int frameIndex) {
    final key = '$movieId:$frameIndex';
    _frameRenderCounts[key] = (_frameRenderCounts[key] ?? 0) + 1;
  }

  /// 记录内存使用
  void recordMemoryUsage(String movieId, int bytes) {
    _memoryUsage[movieId] = bytes;
  }

  /// 获取内存使用情况
  Map<String, int> get memoryUsage => Map.unmodifiable(_memoryUsage);

  /// 获取总内存使用量
  int get totalMemoryUsage => _memoryUsage.values.fold(0, (a, b) => a + b);

  /// 执行内存清理
  void _performMemoryCleanup() {
    if (!kReleaseMode) {
      Timeline.startSync('SVGAMemoryCleanup');
    }

    try {
      // 清理过时的帧渲染统计
      if (_frameRenderCounts.length > _maxCacheEntries * 2) {
        final sortedEntries = _frameRenderCounts.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        
        final toRemove = sortedEntries.take(_frameRenderCounts.length - _maxCacheEntries);
        for (final entry in toRemove) {
          _frameRenderCounts.remove(entry.key);
        }
      }

      if (!kReleaseMode) {
        debugPrint('SVGA Memory Cleanup: ${_frameRenderCounts.length} frame stats, ${totalMemoryUsage ~/ 1024}KB total');
      }
    } finally {
      if (!kReleaseMode) {
        Timeline.finishSync();
      }
    }
  }

  /// 获取性能建议
  List<String> getPerformanceAdvice() {
    final advice = <String>[];
    
    // 检查内存使用
    if (totalMemoryUsage > 50 * 1024 * 1024) { // 50MB
      advice.add('内存使用过高，建议释放不需要的SVGA实例');
    }
    
    // 检查缓存项数量
    if (_frameRenderCounts.length > _maxCacheEntries) {
      advice.add('缓存项过多，考虑清理旧的动画缓存');
    }
    
    return advice;
  }

  /// 强制内存清理
  void forceMemoryCleanup() {
    _performMemoryCleanup();
  }
}

/// 内存优化的MovieEntity扩展
extension MovieEntityMemoryOptimization on MovieEntity {
  /// 估算内存使用量
  int estimateMemoryUsage() {
    int totalSize = 0;
    
    // 计算bitmap缓存大小
    for (final image in bitmapCache.values) {
      totalSize += image.width * image.height * 4; // RGBA
    }
    
    // 计算路径缓存大小（估算）
    totalSize += pathCache.length * 1000; // 每个路径约1KB
    
    // 计算基础数据大小
    totalSize += sprites.length * 1000; // 每个sprite约1KB
    
    return totalSize;
  }
  
  /// 清理不必要的缓存
  void optimizeMemory() {
    // 限制路径缓存大小
    if (pathCache.length > 100) {
      final keysToRemove = pathCache.keys.take(pathCache.length - 50).toList();
      for (final key in keysToRemove) {
        pathCache.remove(key);
      }
    }
  }
}

/// 性能监控装饰器
mixin SVGAPerformanceMonitor {
  final _performanceManager = SVGAPerformanceManager();
  
  void initializePerformanceMonitoring() {
    _performanceManager.initialize();
  }
  
  void disposePerformanceMonitoring() {
    _performanceManager.dispose();
  }
  
  void recordFrameRender(String movieId, int frameIndex) {
    _performanceManager.recordFrameRender(movieId, frameIndex);
  }
  
  void recordMemoryUsage(String movieId, int bytes) {
    _performanceManager.recordMemoryUsage(movieId, bytes);
  }
  
  List<String> getPerformanceAdvice() {
    return _performanceManager.getPerformanceAdvice();
  }
} 