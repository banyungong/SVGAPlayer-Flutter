import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

// 导入测试页面
import 'basic_sample.dart';
import 'performance_test.dart';
import 'memory_test.dart';
import 'dynamic_content_test.dart';
import 'network_test.dart';
import 'optimization_test.dart';
import 'cache_test.dart';
import 'repeat_playback_test.dart';
import 'business_scenario_test.dart';
import 'cache_crash_test.dart';

void main() => runApp(ExampleApp());

class ExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVGA Flutter 完整测试',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  // 清除缓存对话框
  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('清除缓存'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要清除所有SVGA缓存吗？'),
              SizedBox(height: 8),
              Text(
                '这将清除所有已缓存的SVGA文件和图片，下次加载时需要重新解析。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                _clearAllCache(context);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('清除'),
            ),
          ],
        );
      },
    );
  }

  // 执行清除缓存
  void _clearAllCache(BuildContext context) {
    try {
      // 获取清除前的缓存统计
      final stats = SVGAParser.getCacheStats();
      final beforeSize = stats['total']?['size_formatted'] ?? '0B';
      final beforeCount = stats['svga_cache']?['count'] ?? 0;
      
      // 清除所有缓存
      SVGAParser.clearCache();
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '缓存清除成功！\n清除了 $beforeCount 个缓存项，释放了 $beforeSize 内存',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('清除缓存失败: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // 定义测试场景
  final List<TestCategory> testCategories = [
    TestCategory(
      title: '基础功能测试',
      description: '基本的SVGA播放功能和控制测试',
      icon: Icons.play_circle_outline,
      color: Colors.blue,
      builder: (context) => BasicSampleScreen(),
    ),
    TestCategory(
      title: '缓存系统测试',
      description: 'LRU缓存和资源复用效果测试',
      icon: Icons.storage,
      color: Colors.purple,
      builder: (context) => CacheTestScreen(),
    ),
    TestCategory(
      title: '性能压力测试',
      description: '多个动画同时播放的性能测试',
      icon: Icons.speed,
      color: Colors.orange,
      builder: (context) => PerformanceTestScreen(),
    ),
    TestCategory(
      title: '内存管理测试',
      description: '内存使用和释放情况测试',
      icon: Icons.memory,
      color: Colors.green,
      builder: (context) => MemoryTestScreen(),
    ),
    TestCategory(
      title: '内存优化测试',
      description: '精灵过滤、图片压缩和音效控制测试',
      icon: Icons.tune,
      color: Colors.deepOrange,
      builder: (context) => OptimizationTestScreen(),
    ),
    TestCategory(
      title: '动态内容测试',
      description: '动态文本和图片替换测试',
      icon: Icons.dynamic_form,
      color: Colors.indigo,
      builder: (context) => DynamicContentTestScreen(),
    ),
    TestCategory(
      title: '网络加载测试',
      description: '网络SVGA文件加载测试',
      icon: Icons.cloud_download,
      color: Colors.teal,
      builder: (context) => NetworkTestScreen(),
    ),
    TestCategory(
      title: '重复播放测试',
      description: '测试SVGA重复播放时的问题复现与调试',
      icon: Icons.repeat_one,
      color: Colors.red,
      builder: (context) => RepeatPlaybackTestScreen(),
    ),
    TestCategory(
      title: '业务场景重现',
      description: '模拟业务中的SVGA加载方式：下载→readAsBytes→decodeFromBuffer',
      icon: Icons.business_center,
      color: Colors.deepOrange,
      builder: (context) => BusinessScenarioTestScreen(),
    ),
    TestCategory(
      title: '缓存崩溃测试',
      description: '测试多实例播放+缓存清理的JNI异常修复效果',
      icon: Icons.bug_report,
      color: Colors.red,
      builder: (context) => CacheCrashTestScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SVGA Flutter 完整测试套件'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            tooltip: '清除所有缓存',
            onPressed: () => _showClearCacheDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: testCategories.length,
          itemBuilder: (context, index) {
            final category = testCategories[index];
            return Card(
              margin: EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: category.builder,
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 30,
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              category.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TestCategory {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext) builder;

  TestCategory({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class SVGASampleScreen extends StatefulWidget {
  final String? name;
  final String image;
  final void Function(MovieEntity entity)? dynamicCallback;
  const SVGASampleScreen(
      {Key? key, required this.image, this.name, this.dynamicCallback})
      : super(key: key);

  @override
  _SVGASampleScreenState createState() => _SVGASampleScreenState();
}

class _SVGASampleScreenState extends State<SVGASampleScreen>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? animationController;
  bool isLoading = true;
  Color backgroundColor = Colors.transparent;
  bool allowOverflow = true;
  // Canvaskit need FilterQuality.high
  FilterQuality filterQuality = kIsWeb ? FilterQuality.high : FilterQuality.low;
  BoxFit fit = BoxFit.contain;
  late double containerWidth;
  late double containerHeight;
  bool hideOptions = false;
  
  // 性能监控相关
  Timer? _performanceTimer;
  Map<String, dynamic> _cacheStats = {};
  bool _showPerformanceOverlay = false;
  @override
  void initState() {
    super.initState();
    this.animationController = SVGAAnimationController(vsync: this);
    this._loadAnimation();
    _startPerformanceMonitoring();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    containerWidth = math.min(350, MediaQuery.of(context).size.width);
    containerHeight = math.min(350, MediaQuery.of(context).size.height);
  }

  @override
  void dispose() {
    _performanceTimer?.cancel();
    this.animationController?.dispose();
    this.animationController = null;
    super.dispose();
  }

  void _loadAnimation() async {
    // FIXME: may throw error on loading
    final videoItem = await _loadVideoItem(widget.image);
    if (widget.dynamicCallback != null) {
      widget.dynamicCallback!(videoItem);
    }
    if (mounted)
      setState(() {
        this.isLoading = false;
        this.animationController?.videoItem = videoItem;
        _playAnimation();
      });
  }

  void _playAnimation() {
    if (animationController?.isCompleted == true) {
      animationController?.reset();
    }
    animationController?.repeat(); // or animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name ?? "")),
      body: Stack(
        children: <Widget>[
          Container(
              padding: const EdgeInsets.all(8.0),
              child: Text("Url: ${widget.image}",
                  style: Theme.of(context).textTheme.titleSmall)),
          if (isLoading) LinearProgressIndicator(),
          Center(
            child: ColoredBox(
              color: backgroundColor,
              child: SVGAImage(
                this.animationController!,
                fit: fit,
                clearsAfterStop: false,
                allowDrawingOverflow: allowOverflow,
                filterQuality: filterQuality,
                preferredSize: Size(containerWidth, containerHeight),
              ),
            ),
          ),
          Positioned(bottom: 10, child: _buildOptions(context)),
          // 性能监控悬浮层
          if (_showPerformanceOverlay) _buildPerformanceOverlay(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "performance",
            onPressed: () {
              setState(() {
                _showPerformanceOverlay = !_showPerformanceOverlay;
              });
            },
            child: Icon(_showPerformanceOverlay ? Icons.close : Icons.analytics),
          ),
          SizedBox(height: 8),
          if (!isLoading && animationController!.videoItem != null)
            FloatingActionButton.extended(
              heroTag: "playPause",
              label: Text(animationController!.isAnimating ? "Pause" : "Play"),
              icon: Icon(animationController!.isAnimating
                  ? Icons.pause
                  : Icons.play_arrow),
              onPressed: () {
                if (animationController?.isAnimating == true) {
                  animationController?.stop();
                } else {
                  _playAnimation();
                }
                setState(() {});
              }),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.black12,
      padding: EdgeInsets.all(8.0),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          showValueIndicator: ShowValueIndicator.always,
          trackHeight: 2,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6, pressedElevation: 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
                onPressed: () {
                  setState(() {
                    hideOptions = !hideOptions;
                  });
                },
                icon: hideOptions
                    ? Icon(Icons.arrow_drop_up)
                    : Icon(Icons.arrow_drop_down),
                label: Text(hideOptions ? 'Show options' : 'Hide options')),
            AnimatedBuilder(
                animation: animationController!,
                builder: (context, child) {
                  return Text(
                      'Current frame: ${animationController!.currentFrame + 1}/${animationController!.frames}');
                }),
            if (!hideOptions) ...[
              AnimatedBuilder(
                  animation: animationController!,
                  builder: (context, child) {
                    return Slider(
                      min: 0,
                      max: animationController!.frames.toDouble(),
                      value: animationController!.currentFrame.toDouble(),
                      label: '${animationController!.currentFrame}',
                      onChanged: (v) {
                        if (animationController?.isAnimating == true) {
                          animationController?.stop();
                        }
                        animationController?.value =
                            v / animationController!.frames;
                      },
                    );
                  }),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Image filter quality'),
                  DropdownButton<FilterQuality>(
                    value: filterQuality,
                    onChanged: (FilterQuality? newValue) {
                      setState(() {
                        filterQuality = newValue!;
                      });
                    },
                    items: FilterQuality.values.map((FilterQuality value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value.toString().split('.').last),
                      );
                    }).toList(),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Allow drawing overflow'),
                  const SizedBox(width: 8),
                  Switch(
                    value: allowOverflow,
                    onChanged: (v) {
                      setState(() {
                        allowOverflow = v;
                      });
                    },
                  )
                ],
              ),
              Text('Container options:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(' width:'),
                  Slider(
                    min: 100,
                    max: MediaQuery.of(context).size.width.roundToDouble(),
                    value: containerWidth,
                    label: '$containerWidth',
                    onChanged: (v) {
                      setState(() {
                        containerWidth = v.truncateToDouble();
                      });
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(' height:'),
                  Slider(
                    min: 100,
                    max: MediaQuery.of(context).size.height.roundToDouble(),
                    label: '$containerHeight',
                    value: containerHeight,
                    onChanged: (v) {
                      setState(() {
                        containerHeight = v.truncateToDouble();
                      });
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(' box fit: '),
                  const SizedBox(width: 8),
                  DropdownButton<BoxFit>(
                    value: fit,
                    onChanged: (BoxFit? newValue) {
                      setState(() {
                        fit = newValue!;
                      });
                    },
                    items: BoxFit.values.map((BoxFit value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value.toString().split('.').last),
                      );
                    }).toList(),
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Colors.transparent,
                  Colors.red,
                  Colors.green,
                  Colors.blue,
                  Colors.yellow,
                  Colors.black,
                ]
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          setState(() {
                            backgroundColor = e;
                          });
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: ShapeDecoration(
                            color: e,
                            shape: CircleBorder(
                              side: backgroundColor == e
                                  ? const BorderSide(
                                      color: Colors.white,
                                      width: 3,
                                    )
                                  : const BorderSide(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      setState(() {
        _cacheStats = SVGAParser.getCacheStats();
      });
    });
  }
  
  Widget _buildPerformanceOverlay() {
    final performanceManager = SVGAPerformanceManager();
    final advice = performanceManager.getPerformanceAdvice();
    final totalMemory = performanceManager.totalMemoryUsage;
    
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        width: 200,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '实时性能监控',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            if (_cacheStats.isNotEmpty) ...[
              Text(
                '缓存: ${_cacheStats['total']?['size_formatted'] ?? '0B'}',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                'SVGA: ${_cacheStats['svga_cache']?['count'] ?? 0}个',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                '图片: ${_cacheStats['image_cache']?['count'] ?? 0}个',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                '使用率: ${_cacheStats['total']?['usage_percentage'] ?? '0.0'}%',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                '内存: ${(totalMemory / (1024 * 1024)).toStringAsFixed(1)}MB',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
            if (advice.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                '性能建议:',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              ...advice.map((suggestion) => Text(
                '• $suggestion',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              )),
            ] else ...[
              SizedBox(height: 4),
              Text(
                '✓ 性能良好',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future _loadVideoItem(String image) {
  Future Function(String) decoder;
  if (image.startsWith(RegExp(r'https?://'))) {
    decoder = SVGAParser.shared.decodeFromURL;
  } else {
    decoder = SVGAParser.shared.decodeFromAssets;
  }
  return decoder(image);
}
