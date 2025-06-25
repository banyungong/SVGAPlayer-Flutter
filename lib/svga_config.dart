import 'dart:ui' as ui;

/// SVGA优化配置类
class SVGAOptimizationConfig {
  /// 是否启用精灵过滤（丢弃超大精灵）
  final bool enableSpriteFiltering;
  
  /// 精灵最大内存限制（字节），超过此限制的精灵将被丢弃
  /// 默认10MB
  final int maxSpriteMemoryBytes;
  
  /// 是否启用图片压缩
  final bool enableImageCompression;
  
  /// 图片最大尺寸限制，超过此尺寸的图片将被压缩
  /// 默认2048x2048
  final int maxImageWidth;
  final int maxImageHeight;
  
  /// 图片压缩质量 (0.0-1.0)
  /// 默认0.8
  final double imageCompressionQuality;
  
  /// 单个图片最大内存限制（字节），超过此限制的图片将被丢弃
  /// 默认50MB
  final int maxImageMemoryBytes;
  
  /// 是否加载音效
  final bool loadAudio;
  
  /// 是否启用调试日志
  final bool enableDebugLog;
  
  const SVGAOptimizationConfig({
    this.enableSpriteFiltering = true,
    this.maxSpriteMemoryBytes = 10 * 1024 * 1024, // 10MB
    this.enableImageCompression = true,
    this.maxImageWidth = 2048,
    this.maxImageHeight = 2048,
    this.imageCompressionQuality = 0.8,
    this.maxImageMemoryBytes = 50 * 1024 * 1024, // 50MB
    this.loadAudio = false, // 默认不加载音效
    this.enableDebugLog = false,
  });
  
  /// 预设配置：高性能模式（最大内存节省）
  static const SVGAOptimizationConfig highPerformance = SVGAOptimizationConfig(
    enableSpriteFiltering: true,
    maxSpriteMemoryBytes: 5 * 1024 * 1024, // 5MB
    enableImageCompression: true,
    maxImageWidth: 1024,
    maxImageHeight: 1024,
    imageCompressionQuality: 0.6,
    maxImageMemoryBytes: 20 * 1024 * 1024, // 20MB
    loadAudio: false,
    enableDebugLog: true,
  );
  
  /// 预设配置：平衡模式
  static const SVGAOptimizationConfig balanced = SVGAOptimizationConfig(
    enableSpriteFiltering: true,
    maxSpriteMemoryBytes: 15 * 1024 * 1024, // 15MB
    enableImageCompression: true,
    maxImageWidth: 1536,
    maxImageHeight: 1536,
    imageCompressionQuality: 0.7,
    maxImageMemoryBytes: 30 * 1024 * 1024, // 30MB
    loadAudio: true,
    enableDebugLog: false,
  );
  
  /// 预设配置：高质量模式（最小压缩）
  static const SVGAOptimizationConfig highQuality = SVGAOptimizationConfig(
    enableSpriteFiltering: false,
    enableImageCompression: false,
    loadAudio: true,
    enableDebugLog: false,
  );
  
  /// 计算图片内存占用
  int calculateImageMemory(int width, int height) {
    return width * height * 4; // RGBA = 4字节
  }
  
  /// 检查图片是否需要压缩
  bool shouldCompressImage(int width, int height) {
    if (!enableImageCompression) return false;
    return width > maxImageWidth || height > maxImageHeight;
  }
  
  /// 检查图片是否超过内存限制
  bool shouldDiscardImage(int width, int height) {
    final memoryBytes = calculateImageMemory(width, height);
    return memoryBytes > maxImageMemoryBytes;
  }
  
  /// 计算压缩后的目标尺寸
  ui.Size calculateCompressedSize(int originalWidth, int originalHeight) {
    if (!shouldCompressImage(originalWidth, originalHeight)) {
      return ui.Size(originalWidth.toDouble(), originalHeight.toDouble());
    }
    
    final aspectRatio = originalWidth / originalHeight;
    int targetWidth, targetHeight;
    
    if (originalWidth > originalHeight) {
      targetWidth = maxImageWidth;
      targetHeight = (targetWidth / aspectRatio).round();
      if (targetHeight > maxImageHeight) {
        targetHeight = maxImageHeight;
        targetWidth = (targetHeight * aspectRatio).round();
      }
    } else {
      targetHeight = maxImageHeight;
      targetWidth = (targetHeight * aspectRatio).round();
      if (targetWidth > maxImageWidth) {
        targetWidth = maxImageWidth;
        targetHeight = (targetWidth / aspectRatio).round();
      }
    }
    
    return ui.Size(targetWidth.toDouble(), targetHeight.toDouble());
  }
  
  /// 格式化字节数
  String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  void log(String message) {
    if (enableDebugLog) {
      print('[SVGA优化] $message');
    }
  }
}

/// 精灵统计信息
class SpriteStats {
  final String imageKey;
  final int width;
  final int height;
  final int memoryBytes;
  final int frameCount;
  
  const SpriteStats({
    required this.imageKey,
    required this.width,
    required this.height,
    required this.memoryBytes,
    required this.frameCount,
  });
  
  @override
  String toString() {
    final config = SVGAOptimizationConfig();
    return 'Sprite(${imageKey}): ${width}x${height}, ${config.formatBytes(memoryBytes)}, ${frameCount} frames';
  }
} 