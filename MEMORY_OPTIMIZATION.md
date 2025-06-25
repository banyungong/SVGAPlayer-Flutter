# SVGA Flutter 内存优化功能

## 概述

针对test1.svga文件390KB但占用297MB内存的问题，我们实现了一套完整的内存优化策略，包括精灵过滤、图片压缩和音效控制等功能。

## 核心问题分析

### 问题现象
- **test1.svga文件**: 390KB文件大小
- **实际内存占用**: 297MB+
- **内存放大**: 约780倍

### 问题原因
1. **图片解码**: PNG/JPG等压缩格式解码后变成RGBA位图
2. **大尺寸图片**: 某些精灵可能包含高分辨率图片
3. **无用资源**: 音效数据在某些场景下不需要
4. **资源重复**: 多次使用同一个SVGA时重复分配内存

## 优化方案

### 1. 精灵过滤 (Sprite Filtering)

**功能**: 丢弃超过指定内存阈值的精灵

**实现原理**:
```dart
// 基于文件大小估算解码后内存占用
int estimateMemory(List<int> imageData) {
  final fileSize = imageData.length;
  int estimatedPixels;
  
  if (fileSize < 50KB) {
    estimatedPixels = fileSize * 50;  // 压缩比1:50
  } else if (fileSize < 200KB) {
    estimatedPixels = fileSize * 100; // 压缩比1:100
  } else {
    estimatedPixels = fileSize * 200; // 压缩比1:200
  }
  
  return estimatedPixels * 4; // RGBA = 4字节/像素
}
```

**配置参数**:
- `enableSpriteFiltering`: 是否启用精灵过滤
- `maxSpriteMemoryBytes`: 精灵最大内存限制（默认10MB）

### 2. 图片压缩 (Image Compression)

**功能**: 压缩超过指定尺寸的图片

**实现原理**:
```dart
Future<ui.Image> compressImage(ui.Image original, ui.Size target) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
  
  canvas.drawImageRect(
    original,
    Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
    Rect.fromLTWH(0, 0, target.width, target.height),
    paint,
  );
  
  final picture = recorder.endRecording();
  return await picture.toImage(target.width.toInt(), target.height.toInt());
}
```

**配置参数**:
- `enableImageCompression`: 是否启用图片压缩
- `maxImageWidth/Height`: 图片最大尺寸（默认2048x2048）
- `imageCompressionQuality`: 压缩质量0.0-1.0（默认0.8）
- `maxImageMemoryBytes`: 单个图片最大内存限制（默认50MB）

### 3. 音效控制 (Audio Control)

**功能**: 选择性加载音效数据

**实现原理**:
```dart
// 在解析过程中移除音频数据
if (!config.loadAudio) {
  movieItem.audios.clear();
}
```

**配置参数**:
- `loadAudio`: 是否加载音效（默认false）

## 预设配置

### 1. 高性能模式 (High Performance)
```dart
SVGAOptimizationConfig.highPerformance = SVGAOptimizationConfig(
  enableSpriteFiltering: true,
  maxSpriteMemoryBytes: 5 * 1024 * 1024,    // 5MB
  enableImageCompression: true,
  maxImageWidth: 1024,
  maxImageHeight: 1024,
  imageCompressionQuality: 0.6,
  maxImageMemoryBytes: 20 * 1024 * 1024,    // 20MB
  loadAudio: false,
  enableDebugLog: true,
);
```

### 2. 平衡模式 (Balanced)
```dart
SVGAOptimizationConfig.balanced = SVGAOptimizationConfig(
  enableSpriteFiltering: true,
  maxSpriteMemoryBytes: 15 * 1024 * 1024,   // 15MB
  enableImageCompression: true,
  maxImageWidth: 1536,
  maxImageHeight: 1536,
  imageCompressionQuality: 0.7,
  maxImageMemoryBytes: 30 * 1024 * 1024,    // 30MB
  loadAudio: true,
);
```

### 3. 高质量模式 (High Quality)
```dart
SVGAOptimizationConfig.highQuality = SVGAOptimizationConfig(
  enableSpriteFiltering: false,
  enableImageCompression: false,
  loadAudio: true,
);
```

## 使用方法

### 1. 基本用法

```dart
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

// 设置优化配置
SVGAParser.setOptimizationConfig(SVGAOptimizationConfig.highPerformance);

// 正常加载SVGA
final videoItem = await SVGAParser.shared.decodeFromAssets('assets/test1.svga');
```

### 2. 自定义配置

```dart
// 创建自定义配置
final customConfig = SVGAOptimizationConfig(
  enableSpriteFiltering: true,
  maxSpriteMemoryBytes: 2 * 1024 * 1024,    // 2MB
  enableImageCompression: true,
  maxImageWidth: 512,
  maxImageHeight: 512,
  imageCompressionQuality: 0.5,
  maxImageMemoryBytes: 10 * 1024 * 1024,    // 10MB
  loadAudio: false,
  enableDebugLog: true,
);

// 应用配置
SVGAParser.setOptimizationConfig(customConfig);
```

### 3. 运行时配置切换

```dart
// 根据不同场景切换配置
if (isLowMemoryDevice) {
  SVGAParser.setOptimizationConfig(SVGAOptimizationConfig.highPerformance);
} else if (needHighQuality) {
  SVGAParser.setOptimizationConfig(SVGAOptimizationConfig.highQuality);
} else {
  SVGAParser.setOptimizationConfig(SVGAOptimizationConfig.balanced);
}
```

## 优化效果预期

### Test1.svga优化效果

**原始情况**:
- 文件大小: 390KB
- 内存占用: ~297MB
- 内存放大: ~780倍

**高性能模式优化后**:
- 精灵过滤: 可能丢弃大型精灵，减少80%+内存
- 图片压缩: 1024x1024限制，可减少75%内存
- 音效移除: 如有音效数据，可减少额外内存
- **预期内存**: ~15-30MB (减少90%+)

**平衡模式优化后**:
- 适度压缩: 1536x1536限制，减少50-70%内存
- **预期内存**: ~50-100MB (减少70%+)

## 监控和调试

### 1. 调试日志

启用调试日志可以看到详细的优化过程:

```dart
final config = SVGAOptimizationConfig(
  enableDebugLog: true,
  // ... 其他配置
);

// 日志输出示例:
// [SVGA优化] 精灵 sprite_001 预估内存过大 (45.2MB)，已丢弃
// [SVGA优化] 压缩图片 sprite_002: 4096x4096 -> 1024x1024
// [SVGA优化] 已移除所有音频数据
// [SVGA优化] 精灵过滤完成: 原有15个，丢弃3个，保留12个
```

### 2. 内存统计

```dart
// 获取缓存统计信息
final stats = SVGAParser.getCacheStats();
final memoryUsage = stats['total']['size_formatted'];
final cacheCount = stats['svga_cache']['count'];

print('缓存内存占用: $memoryUsage');
print('缓存项目数量: $cacheCount');
```

### 3. 测试工具

使用示例应用中的"内存优化测试"页面可以：
- 切换不同优化配置
- 实时查看内存统计
- 对比优化前后效果
- 测试不同SVGA文件的优化效果

## 注意事项

### 1. 质量与性能平衡
- 过度压缩可能影响动画质量
- 精灵过滤可能导致动画不完整
- 建议先用平衡模式测试效果

### 2. 设备适配
- 低端设备建议使用高性能模式
- 高端设备可以使用高质量模式
- 可根据可用内存动态调整配置

### 3. 测试验证
- 在真实设备上测试优化效果
- 关注动画播放是否正常
- 监控内存使用情况

### 4. 缓存考虑
- 优化后的图片会被缓存
- 不同配置的同一文件会生成不同缓存
- 建议在应用启动时设置固定配置

## 最佳实践

1. **应用启动时设置配置**: 避免运行时频繁切换
2. **根据设备性能选择**: 低内存设备用高性能模式
3. **测试关键动画**: 确保重要动画质量不受影响
4. **监控内存使用**: 定期检查实际优化效果
5. **渐进式优化**: 从平衡模式开始，逐步调整参数 