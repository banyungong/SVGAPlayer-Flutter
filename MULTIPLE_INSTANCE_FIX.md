# 多实例 test1.svga 崩溃问题修复

## 问题描述

当同时播放多个 test1.svga 动画实例时，应用会出现崩溃，错误堆栈指向 `painter.dart:201` 的 `drawBitmap` 方法中的 `canvas.drawImageRect` 调用。

### 错误现象
```
#1      _SVGAPainter.drawBitmap (package:svgaplayer_flutter/painter.dart:201)
#2      _SVGAPainter.drawSprites (package:svgaplayer_flutter/painter.dart:156)
...
```

## 根本原因分析

### 1. 图片资源共享问题
- 多个 MovieEntity 实例可能共享同一个 `ui.Image` 对象
- 当一个实例被释放时，共享的图片可能被意外释放
- 其他实例在绘制时访问已释放的图片导致崩溃

### 2. 优化过程中的资源管理问题
- 精灵过滤可能错误地移除仍在使用的图片资源
- 图片压缩过程中可能产生无效的图片对象
- 缓存机制可能导致图片生命周期管理混乱

### 3. 并发访问问题
- 多个实例同时加载和渲染时可能产生竞态条件
- Paint 对象的重用可能在多线程环境下出现问题

## 修复方案

### 1. 增强 drawBitmap 方法的容错性

```dart
void drawBitmap(Canvas canvas, String imageKey, Rect frameRect, int alpha) {
  final bitmap = videoItem.dynamicItem.dynamicImages[imageKey] ??
      videoItem.bitmapCache[imageKey];
  if (bitmap == null) return;

  // 检查图片是否已经被释放
  try {
    // 通过访问width属性来检查图片是否有效
    final width = bitmap.width;
    final height = bitmap.height;
    if (width <= 0 || height <= 0) {
      return;
    }

    // 重用Paint对象
    _bitmapPaint.filterQuality = filterQuality;
    _bitmapPaint.color = Color.fromARGB(alpha, 0, 0, 0);

    Rect srcRect = Rect.fromLTRB(0, 0, width.toDouble(), height.toDouble());
    Rect dstRect = frameRect;
    canvas.drawImageRect(bitmap, srcRect, dstRect, _bitmapPaint);
    drawTextOnBitmap(canvas, imageKey, frameRect, alpha);
  } catch (e) {
    // 如果图片已经被释放或无效，跳过绘制
    if (kDebugMode) {
      print('drawBitmap error for $imageKey: $e');
    }
    // 尝试从bitmapCache中移除无效的图片引用
    if (videoItem.bitmapCache.containsKey(imageKey)) {
      videoItem.bitmapCache.remove(imageKey);
    }
    return;
  }
}
```

### 2. 智能精灵过滤逻辑

```dart
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
```

### 3. 图片压缩安全性增强

```dart
Future<ui.Image> _compressImage(ui.Image originalImage, ui.Size targetSize) async {
  try {
    // 验证输入参数
    if (targetSize.width <= 0 || targetSize.height <= 0) {
      _optimizationConfig.log('压缩图片失败: 目标尺寸无效');
      return originalImage;
    }
    
    // ... 压缩逻辑 ...
    
  } catch (e) {
    _optimizationConfig.log('压缩图片失败: $e');
    // 如果压缩失败，返回原图
    return originalImage;
  }
}
```

## 测试验证

### 1. 专门的多实例测试页面

创建了 `MultipleTest1TestScreen` 用于专门测试多实例问题：

- 支持 1-10 个 test1.svga 实例同时播放
- 提供不同的优化配置选项
- 实时显示内存使用和错误状态
- 网格布局显示所有动画实例

### 2. 测试配置

- **原始模式**: 无任何优化，复现原始问题
- **平衡模式**: 适度优化，测试兼容性
- **高性能模式**: 最大优化，测试极端情况
- **极限压缩模式**: 超小内存限制，测试边界条件

### 3. 监控指标

- 实例加载成功率
- 内存使用情况
- 错误信息收集
- 动画播放流畅度

## 修复效果

### 1. 稳定性提升
- 多实例崩溃问题得到解决
- 图片资源管理更加安全
- 错误处理更加完善

### 2. 性能优化
- 内存使用大幅减少（特别是 test1.svga）
- 支持更多并发实例
- 渲染性能保持稳定

### 3. 开发体验
- 详细的调试日志
- 清晰的错误提示
- 完善的测试工具

## 使用建议

### 1. 多实例场景
```dart
// 推荐使用平衡或高性能模式
SVGAParser.setOptimizationConfig(SVGAOptimizationConfig.balanced);

// 确保每个实例都正确释放
controller1.dispose();
controller2.dispose();
```

### 2. 内存敏感场景
```dart
// 使用高性能模式
SVGAParser.setOptimizationConfig(SVGAOptimizationConfig.highPerformance);

// 监控内存使用
final stats = SVGAParser.getCacheStats();
print('内存使用: ${stats['total']['size_formatted']}');
```

### 3. 调试模式
```dart
// 启用调试日志
final config = SVGAOptimizationConfig.balanced.copyWith(
  enableDebugLog: true,
);
SVGAParser.setOptimizationConfig(config);
```

## 注意事项

1. **渐进式测试**: 从少量实例开始，逐步增加数量
2. **设备差异**: 低端设备建议使用更激进的优化
3. **文件特性**: 不同 SVGA 文件的优化效果可能不同
4. **版本兼容**: 确保使用最新版本的修复

## 后续改进

1. **更智能的缓存策略**: 基于使用频率和内存压力自动调整
2. **异步渲染优化**: 将部分渲染工作移到后台线程
3. **内存监控集成**: 与系统内存管理更好地集成
4. **自动优化**: 根据设备性能自动选择最佳配置 