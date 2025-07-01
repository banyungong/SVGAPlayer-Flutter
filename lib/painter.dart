part of 'player.dart';

class _SVGAPainter extends CustomPainter {
  final BoxFit fit;
  final SVGAAnimationController controller;
  int get currentFrame => controller.currentFrame;
  MovieEntity get videoItem => controller.videoItem!;
  final FilterQuality filterQuality;

  /// Guaranteed to draw within the canvas bounds
  final bool clipRect;
  
  // Paint对象池，减少对象创建开销
  static final Paint _bitmapPaint = Paint()..isAntiAlias = true;
  static final Paint _fillPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke;
  
  // 缓存上一帧的索引，避免重复计算
  int? _lastFrameIndex;
  List<bool>? _visibleSprites;
  
  _SVGAPainter(
    this.controller, {
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.clipRect = true,
  })  : assert(
            controller.videoItem != null, 'Invalid SVGAAnimationController!'),
        super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (controller._canvasNeedsClear) {
      // mark cleared
      controller._canvasNeedsClear = false;
      _lastFrameIndex = null;
      _visibleSprites = null;
      return;
    }
    
    // 检查MovieEntity是否已被释放
    if (controller.videoItem == null || controller.videoItem!.isDisposed) {
      return;
    }
    
    // 记录帧渲染性能
    controller.recordFrameRender(
      videoItem.hashCode.toString(), 
      currentFrame
    );
    if (size.isEmpty) return;
    
    final params = videoItem.params;
    final Size viewBoxSize = Size(params.viewBoxWidth, params.viewBoxHeight);
    if (viewBoxSize.isEmpty) return;
    
    // 检查是否需要重新计算可见sprite
    final currentFrameIndex = currentFrame;
    if (_lastFrameIndex != currentFrameIndex) {
      _updateVisibleSprites(currentFrameIndex);
      _lastFrameIndex = currentFrameIndex;
    }
    
    canvas.save();
    try {
      final canvasRect = Offset.zero & size;
      if (clipRect) canvas.clipRect(canvasRect);
      scaleCanvasToViewBox(canvas, canvasRect, Offset.zero & viewBoxSize);
      drawSprites(canvas, size);
    } finally {
      canvas.restore();
    }
  }
  
  /// 预计算当前帧的可见sprite，避免在绘制时重复检查
  void _updateVisibleSprites(int frameIndex) {
    if (_visibleSprites == null || _visibleSprites!.length != videoItem.sprites.length) {
      _visibleSprites = List.filled(videoItem.sprites.length, false);
    }
    
    for (int i = 0; i < videoItem.sprites.length; i++) {
      final sprite = videoItem.sprites[i];
      final imageKey = sprite.imageKey;
      
      // 检查sprite是否在当前帧可见
      _visibleSprites![i] = imageKey.isNotEmpty && 
          videoItem.dynamicItem.dynamicHidden[imageKey] != true &&
          frameIndex < sprite.frames.length;
    }
  }

  void scaleCanvasToViewBox(Canvas canvas, Rect canvasRect, Rect viewBoxRect) {
    final fittedSizes = applyBoxFit(fit, viewBoxRect.size, canvasRect.size);

    // scale viewbox size (source) to canvas size (destination)
    var sx = fittedSizes.destination.width / fittedSizes.source.width;
    var sy = fittedSizes.destination.height / fittedSizes.source.height;
    final Size scaledHalfViewBoxSize =
        Size(viewBoxRect.size.width * sx, viewBoxRect.size.height * sy) / 2.0;
    final Size halfCanvasSize = canvasRect.size / 2.0;
    // center align
    final Offset shift = Offset(
      halfCanvasSize.width - scaledHalfViewBoxSize.width,
      halfCanvasSize.height - scaledHalfViewBoxSize.height,
    );
    if (shift != Offset.zero) canvas.translate(shift.dx, shift.dy);
    if (sx != 1.0 && sy != 1.0) canvas.scale(sx, sy);
  }

  void drawSprites(Canvas canvas, Size size) {
    for (int i = 0; i < videoItem.sprites.length; i++) {
      // 使用预计算的可见性检查
      if (_visibleSprites != null && !_visibleSprites![i]) {
        continue;
      }
      
      final sprite = videoItem.sprites[i];
      final imageKey = sprite.imageKey;
      final frameItem = sprite.frames[currentFrame];
      
      // 检查当前帧是否有内容需要绘制
      if (!_hasVisibleContent(frameItem, imageKey)) {
        continue;
      }
      
      final needTransform = frameItem.hasTransform();
      final needClip = frameItem.hasClipPath();
      
      if (needTransform) {
        canvas.save();
        canvas.transform(Float64List.fromList(<double>[
          frameItem.transform.a,
          frameItem.transform.b,
          0.0,
          0.0,
          frameItem.transform.c,
          frameItem.transform.d,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          frameItem.transform.tx,
          frameItem.transform.ty,
          0.0,
          1.0
        ]));
      }
      if (needClip) {
        canvas.save();
        canvas.clipPath(buildDPath(frameItem.clipPath));
      }
      // 验证layout尺寸的有效性，防止创建无效矩形
      final layoutWidth = frameItem.layout.width;
      final layoutHeight = frameItem.layout.height;
      
      // 如果layout尺寸无效，跳过绘制但需要正确处理canvas状态
      if (layoutWidth <= 0 || layoutHeight <= 0 || 
          !layoutWidth.isFinite || !layoutHeight.isFinite) {
        if (kDebugMode) {
          print('Skipping sprite $imageKey with invalid layout: width=$layoutWidth, height=$layoutHeight');
        }
        // 确保正确恢复canvas状态
        if (needClip) {
          canvas.restore();
        }
        if (needTransform) {
          canvas.restore();
        }
        continue;
      }
      
      final frameRect = Rect.fromLTRB(0, 0, layoutWidth, layoutHeight);
      final frameAlpha =
          frameItem.hasAlpha() ? (frameItem.alpha * 255).toInt() : 255;
      drawBitmap(canvas, imageKey, frameRect, frameAlpha);
      drawShape(canvas, frameItem.shapes, frameAlpha);
      // draw dynamic
      final dynamicDrawer = videoItem.dynamicItem.dynamicDrawer[imageKey];
      if (dynamicDrawer != null) {
        dynamicDrawer(canvas, currentFrame);
      }
      if (needClip) {
        canvas.restore();
      }
      if (needTransform) {
        canvas.restore();
      }
    }
  }
  
  /// 检查当前帧是否有可见内容
  bool _hasVisibleContent(FrameEntity frameItem, String imageKey) {
    // 检查透明度
    if (frameItem.hasAlpha() && frameItem.alpha <= 0.01) {
      return false;
    }
    
    // 检查layout是否有效
    final layoutWidth = frameItem.layout.width;
    final layoutHeight = frameItem.layout.height;
    if (layoutWidth <= 0 || layoutHeight <= 0 || 
        !layoutWidth.isFinite || !layoutHeight.isFinite) {
      return false;
    }
    
    // 检查是否有bitmap、shape或动态内容
    final hasBitmap = _isValidBitmap(imageKey);
    final hasShapes = frameItem.shapes.isNotEmpty;
    final hasDynamic = videoItem.dynamicItem.dynamicDrawer[imageKey] != null ||
        videoItem.dynamicItem.dynamicText[imageKey] != null;
    
    return hasBitmap || hasShapes || hasDynamic;
  }
  
  /// 检查bitmap是否有效
  bool _isValidBitmap(String imageKey) {
    // 首先检查MovieEntity是否已被释放
    if (videoItem.isDisposed) {
      return false;
    }
    
    final bitmap = videoItem.dynamicItem.dynamicImages[imageKey] ??
        videoItem.bitmapCache[imageKey];
    
    if (bitmap == null) return false;
    
    try {
      // 尝试访问图片属性来检查是否有效
      final width = bitmap.width;
      final height = bitmap.height;
      return width > 0 && height > 0;
    } catch (e) {
      // 如果访问失败，说明图片已被释放
      return false;
    }
  }

  void drawBitmap(Canvas canvas, String imageKey, Rect frameRect, int alpha) {
    // 检查MovieEntity是否已被释放
    if (videoItem.isDisposed) {
      return;
    }
    
    final bitmap = videoItem.dynamicItem.dynamicImages[imageKey] ??
        videoItem.bitmapCache[imageKey];
    
    if (bitmap == null) return;

    // 多层保护检查图片是否已经被释放
    try {
      // 1. 首先检查图片对象本身是否还有效
      if (!_isImageValid(bitmap)) {
        _cleanupInvalidBitmap(imageKey);
        return;
      }

      // 2. 通过访问width/height属性进行二次验证
      final width = bitmap.width;
      final height = bitmap.height;
      if (width <= 0 || height <= 0) {
        _cleanupInvalidBitmap(imageKey);
        return;
      }

      // 3. 设置画笔属性（使用保护性的alpha值）
      _bitmapPaint.filterQuality = filterQuality;
      // 确保alpha值在有效范围内，防止断言失败
      final safeAlpha = alpha.clamp(0, 255);
      _bitmapPaint.color = Color.fromARGB(safeAlpha, 255, 255, 255);

      // 4. 创建安全的绘制区域
      final Rect srcRect = Rect.fromLTRB(0, 0, width.toDouble(), height.toDouble());
      final Rect dstRect = frameRect;
      
      // 5. 验证绘制区域是否有效
      if (srcRect.isEmpty || dstRect.isEmpty || !srcRect.isFinite || !dstRect.isFinite ||
          dstRect.width <= 0 || dstRect.height <= 0) {
        if (kDebugMode) {
          print('drawBitmap: Invalid rect for $imageKey - srcRect: $srcRect, dstRect: $dstRect');
        }
        return;
      }

      // 6. 执行绘制操作，并处理可能的异常
      canvas.drawImageRect(bitmap, srcRect, dstRect, _bitmapPaint);
      drawTextOnBitmap(canvas, imageKey, frameRect, alpha);
      
    } catch (e) {
      // 全面的错误处理和日志记录
      if (kDebugMode) {
        print('drawBitmap error for $imageKey: $e. Cleaning up invalid bitmap.');
      }
      _cleanupInvalidBitmap(imageKey);
      
      // 记录错误信息以便调试
      _recordBitmapError(imageKey, e);
      return;
    }
  }
  
  /// 检查Image对象是否仍然有效
  bool _isImageValid(ui.Image image) {
    try {
      // 尝试访问图片的基本属性
      // 如果图片已被dispose，这些操作会抛出异常
      final _ = image.width;
      final __ = image.height;
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 记录bitmap错误信息，用于调试和监控
  void _recordBitmapError(String imageKey, dynamic error) {
    // 在这里可以添加错误统计、上报等逻辑
    // 目前先简单记录到debug输出
    if (kDebugMode) {
      final errorType = error.runtimeType.toString();
      final errorMessage = error.toString();
      print('BitmapError - Key: $imageKey, Type: $errorType, Message: $errorMessage');
      
      // 输出一些上下文信息帮助调试
      if (!videoItem.isDisposed) {
        print('VideoItem state - bitmapCache size: ${videoItem.bitmapCache.length}, autorelease: ${videoItem.autorelease}, references: ${videoItem.referenceCount}');
      } else {
        print('VideoItem state - DISPOSED, references: ${videoItem.referenceCount}');
      }
    }
  }
  
  /// 清理无效的图片引用
  void _cleanupInvalidBitmap(String imageKey) {
    // 如果MovieEntity已被释放，不进行清理操作
    if (videoItem.isDisposed) {
      return;
    }
    
    // 从bitmapCache中移除无效的图片引用
    if (videoItem.bitmapCache.containsKey(imageKey)) {
      videoItem.bitmapCache.remove(imageKey);
    }
    // 从动态图片中移除无效的引用
    if (videoItem.dynamicItem.dynamicImages.containsKey(imageKey)) {
      videoItem.dynamicItem.dynamicImages.remove(imageKey);
    }
  }

  void drawShape(Canvas canvas, List<ShapeEntity> shapes, int frameAlpha) {
    if (shapes.isEmpty) return;
    for (var shape in shapes) {
      final path = buildPath(shape);
      if (shape.hasTransform()) {
        canvas.save();
        canvas.transform(Float64List.fromList(<double>[
          shape.transform.a,
          shape.transform.b,
          0.0,
          0.0,
          shape.transform.c,
          shape.transform.d,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          shape.transform.tx,
          shape.transform.ty,
          0.0,
          1.0
        ]));
      }

      final fill = shape.styles.fill;
      if (fill.isInitialized()) {
        _fillPaint.color = Color.fromARGB(
          (fill.a * frameAlpha).toInt(),
          (fill.r * 255).toInt(),
          (fill.g * 255).toInt(),
          (fill.b * 255).toInt(),
        );
        canvas.drawPath(path, _fillPaint);
      }
      final strokeWidth = shape.styles.strokeWidth;
      if (strokeWidth > 0) {
        if (shape.styles.stroke.isInitialized()) {
          _strokePaint.color = Color.fromARGB(
            (shape.styles.stroke.a * frameAlpha).toInt(),
            (shape.styles.stroke.r * 255).toInt(),
            (shape.styles.stroke.g * 255).toInt(),
            (shape.styles.stroke.b * 255).toInt(),
          );
        }
        _strokePaint.strokeWidth = strokeWidth;
        final lineCap = shape.styles.lineCap;
        switch (lineCap) {
          case ShapeEntity_ShapeStyle_LineCap.LineCap_BUTT:
            _strokePaint.strokeCap = StrokeCap.butt;
            break;
          case ShapeEntity_ShapeStyle_LineCap.LineCap_ROUND:
            _strokePaint.strokeCap = StrokeCap.round;
            break;
          case ShapeEntity_ShapeStyle_LineCap.LineCap_SQUARE:
            _strokePaint.strokeCap = StrokeCap.square;
            break;
          default:
        }
        final lineJoin = shape.styles.lineJoin;
        switch (lineJoin) {
          case ShapeEntity_ShapeStyle_LineJoin.LineJoin_MITER:
            _strokePaint.strokeJoin = StrokeJoin.miter;
            break;
          case ShapeEntity_ShapeStyle_LineJoin.LineJoin_ROUND:
            _strokePaint.strokeJoin = StrokeJoin.round;
            break;
          case ShapeEntity_ShapeStyle_LineJoin.LineJoin_BEVEL:
            _strokePaint.strokeJoin = StrokeJoin.bevel;
            break;
          default:
        }
        _strokePaint.strokeMiterLimit = shape.styles.miterLimit;
        List<double> lineDash = [
          shape.styles.lineDashI,
          shape.styles.lineDashII,
          shape.styles.lineDashIII
        ];
        if (lineDash[0] > 0 || lineDash[1] > 0) {
          canvas.drawPath(
              dashPath(
                path,
                dashArray: CircularIntervalList([
                  lineDash[0] < 1.0 ? 1.0 : lineDash[0],
                  lineDash[1] < 0.1 ? 0.1 : lineDash[1],
                ]),
                dashOffset: DashOffset.absolute(lineDash[2]),
              ),
              _strokePaint);
        } else {
          canvas.drawPath(path, _strokePaint);
        }
      }
      if (shape.hasTransform()) {
        canvas.restore();
      }
    }
  }

  static const _validMethods = 'MLHVCSQRZmlhvcsqrz';

  Path buildPath(ShapeEntity shape) {
    final path = Path();
    if (shape.type == ShapeEntity_ShapeType.SHAPE) {
      final args = shape.shape;
      final argD = args.d;
      return buildDPath(argD, path: path);
    } else if (shape.type == ShapeEntity_ShapeType.ELLIPSE) {
      final args = shape.ellipse;
      final xv = args.x;
      final yv = args.y;
      final rxv = args.radiusX;
      final ryv = args.radiusY;
      final rect = Rect.fromLTWH(xv - rxv, yv - ryv, rxv * 2, ryv * 2);
      if (!rect.isEmpty) path.addOval(rect);
    } else if (shape.type == ShapeEntity_ShapeType.RECT) {
      final args = shape.rect;
      final xv = args.x;
      final yv = args.y;
      final wv = args.width;
      final hv = args.height;
      final crv = args.cornerRadius;
      final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(xv, yv, wv, hv), Radius.circular(crv));
      if (!rrect.isEmpty) path.addRRect(rrect);
    }
    return path;
  }

  Path buildDPath(String argD, {Path? path}) {
    // 优化路径缓存机制
    if (videoItem.pathCache[argD] != null) {
      return Path.from(videoItem.pathCache[argD]!);
    }
    
    path ??= Path();
    final d = argD.replaceAllMapped(RegExp('([a-df-zA-Z])'), (match) {
      return "|||${match.group(1)} ";
    }).replaceAll(RegExp(","), " ");
    var currentPointX = 0.0;
    var currentPointY = 0.0;
    double? currentPointX1;
    double? currentPointY1;
    double? currentPointX2;
    double? currentPointY2;
    
    final segments = d.split("|||");
    for (final segment in segments) {
      if (segment.isEmpty) {
        continue;
      }
      final firstLetter = segment.substring(0, 1);
      if (_validMethods.contains(firstLetter)) {
        final args = segment.substring(1).trim().split(" ");
        if (firstLetter == "M") {
          currentPointX = double.parse(args[0]);
          currentPointY = double.parse(args[1]);
          path.moveTo(currentPointX, currentPointY);
        } else if (firstLetter == "m") {
          currentPointX += double.parse(args[0]);
          currentPointY += double.parse(args[1]);
          path.moveTo(currentPointX, currentPointY);
        } else if (firstLetter == "L") {
          currentPointX = double.parse(args[0]);
          currentPointY = double.parse(args[1]);
          path.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "l") {
          currentPointX += double.parse(args[0]);
          currentPointY += double.parse(args[1]);
          path.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "H") {
          currentPointX = double.parse(args[0]);
          path.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "h") {
          currentPointX += double.parse(args[0]);
          path.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "V") {
          currentPointY = double.parse(args[0]);
          path.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "v") {
          currentPointY += double.parse(args[0]);
          path.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "C") {
          currentPointX1 = double.parse(args[0]);
          currentPointY1 = double.parse(args[1]);
          currentPointX2 = double.parse(args[2]);
          currentPointY2 = double.parse(args[3]);
          currentPointX = double.parse(args[4]);
          currentPointY = double.parse(args[5]);
          path.cubicTo(
            currentPointX1,
            currentPointY1,
            currentPointX2,
            currentPointY2,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "c") {
          currentPointX1 = currentPointX + double.parse(args[0]);
          currentPointY1 = currentPointY + double.parse(args[1]);
          currentPointX2 = currentPointX + double.parse(args[2]);
          currentPointY2 = currentPointY + double.parse(args[3]);
          currentPointX += double.parse(args[4]);
          currentPointY += double.parse(args[5]);
          path.cubicTo(
            currentPointX1,
            currentPointY1,
            currentPointX2,
            currentPointY2,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "S") {
          if (currentPointX1 != null &&
              currentPointY1 != null &&
              currentPointX2 != null &&
              currentPointY2 != null) {
            currentPointX1 = currentPointX - currentPointX2 + currentPointX;
            currentPointY1 = currentPointY - currentPointY2 + currentPointY;
            currentPointX2 = double.parse(args[0]);
            currentPointY2 = double.parse(args[1]);
            currentPointX = double.parse(args[2]);
            currentPointY = double.parse(args[3]);
            path.cubicTo(
              currentPointX1,
              currentPointY1,
              currentPointX2,
              currentPointY2,
              currentPointX,
              currentPointY,
            );
          } else {
            currentPointX1 = double.parse(args[0]);
            currentPointY1 = double.parse(args[1]);
            currentPointX = double.parse(args[2]);
            currentPointY = double.parse(args[3]);
            path.quadraticBezierTo(
                currentPointX1, currentPointY1, currentPointX, currentPointY);
          }
        } else if (firstLetter == "s") {
          if (currentPointX1 != null &&
              currentPointY1 != null &&
              currentPointX2 != null &&
              currentPointY2 != null) {
            currentPointX1 = currentPointX - currentPointX2 + currentPointX;
            currentPointY1 = currentPointY - currentPointY2 + currentPointY;
            currentPointX2 = currentPointX + double.parse(args[0]);
            currentPointY2 = currentPointY + double.parse(args[1]);
            currentPointX += double.parse(args[2]);
            currentPointY += double.parse(args[3]);
            path.cubicTo(
              currentPointX1,
              currentPointY1,
              currentPointX2,
              currentPointY2,
              currentPointX,
              currentPointY,
            );
          } else {
            currentPointX1 = currentPointX + double.parse(args[0]);
            currentPointY1 = currentPointY + double.parse(args[1]);
            currentPointX += double.parse(args[2]);
            currentPointY += double.parse(args[3]);
            path.quadraticBezierTo(
              currentPointX1,
              currentPointY1,
              currentPointX,
              currentPointY,
            );
          }
        } else if (firstLetter == "Q") {
          currentPointX1 = double.parse(args[0]);
          currentPointY1 = double.parse(args[1]);
          currentPointX = double.parse(args[2]);
          currentPointY = double.parse(args[3]);
          path.quadraticBezierTo(
              currentPointX1, currentPointY1, currentPointX, currentPointY);
        } else if (firstLetter == "q") {
          currentPointX1 = currentPointX + double.parse(args[0]);
          currentPointY1 = currentPointY + double.parse(args[1]);
          currentPointX += double.parse(args[2]);
          currentPointY += double.parse(args[3]);
          path.quadraticBezierTo(
            currentPointX1,
            currentPointY1,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "Z" || firstLetter == "z") {
          path.close();
        }
      }
    }
    
    // 限制路径缓存大小，防止内存无限增长
    if (videoItem.pathCache.length > 100) {
      final keys = videoItem.pathCache.keys.take(50).toList();
      for (final key in keys) {
        videoItem.pathCache.remove(key);
      }
    }
    
    videoItem.pathCache[argD] = Path.from(path);
    return path;
  }

  void drawTextOnBitmap(
      Canvas canvas, String imageKey, Rect frameRect, int frameAlpha) {
    var dynamicText = videoItem.dynamicItem.dynamicText;
    if (dynamicText.isEmpty) return;
    if (dynamicText[imageKey] == null) return;

    // 验证frameRect是否有效
    if (frameRect.isEmpty || !frameRect.isFinite || 
        frameRect.width <= 0 || frameRect.height <= 0) {
      if (kDebugMode) {
        print('drawTextOnBitmap: Invalid frameRect for $imageKey - $frameRect');
      }
      return;
    }

    TextPainter? textPainter = dynamicText[imageKey];
    if (textPainter == null) return;

    try {
      textPainter.paint(
        canvas,
        Offset(
          (frameRect.width - textPainter.width) / 2.0,
          (frameRect.height - textPainter.height) / 2.0,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('drawTextOnBitmap error for $imageKey: $e');
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SVGAPainter oldDelegate) {
    return controller != oldDelegate.controller ||
        fit != oldDelegate.fit ||
        filterQuality != oldDelegate.filterQuality ||
        clipRect != oldDelegate.clipRect;
  }
}
