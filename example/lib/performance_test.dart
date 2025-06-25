import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:async';
import 'dart:math' as math;

class PerformanceTestScreen extends StatefulWidget {
  @override
  _PerformanceTestScreenState createState() => _PerformanceTestScreenState();
}

class _PerformanceTestScreenState extends State<PerformanceTestScreen>
    with TickerProviderStateMixin {
  
  List<SVGAAnimationController> controllers = [];
  List<MovieEntity?> videoItems = [];
  bool isLoading = false;
  int currentCount = 1;
  Timer? performanceTimer;
  
  // 性能监控数据
  List<double> fpsHistory = [];
  double currentFPS = 0;
  int frameCount = 0;
  DateTime lastFrameTime = DateTime.now();
  
  // 内存监控
  int memoryUsage = 0;
  Timer? memoryTimer;
  
  // 测试选项
  final List<String> testFiles = [
    'assets/angel.svga',
    'assets/pin_jump.svga',
    'assets/test1.svga',
  ];
  
  String selectedFile = 'assets/angel.svga';
  bool showFPS = true;
  bool showMemory = true;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers(currentCount);
    _startPerformanceMonitoring();
  }
  
  @override
  void dispose() {
    _disposeControllers();
    performanceTimer?.cancel();
    memoryTimer?.cancel();
    super.dispose();
  }
  
  void _initializeControllers(int count) {
    setState(() {
      isLoading = true;
    });
    
    _disposeControllers();
    
    controllers = List.generate(count, (index) => 
        SVGAAnimationController(vsync: this));
    videoItems = List.generate(count, (index) => null);
    
    // 立即更新状态，确保UI知道新的列表长度
    setState(() {});
    
    _loadAnimations();
  }
  
  void _disposeControllers() {
    for (var controller in controllers) {
      controller.dispose();
    }
    // 不调用clear()，直接重新赋值空列表
    controllers = <SVGAAnimationController>[];
    videoItems = <MovieEntity?>[];
  }
  
  void _loadAnimations() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromAssets(selectedFile);
      
      // 检查控制器列表是否仍然有效（可能在加载过程中被重置）
      if (controllers.isEmpty) return;
      
      for (int i = 0; i < controllers.length; i++) {
        videoItems[i] = videoItem;
        controllers[i].videoItem = videoItem;
      }
      
      setState(() {
        isLoading = false;
      });
      
      _playAllAnimations();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('加载失败: $e');
    }
  }
  
  void _playAllAnimations() {
    for (var controller in controllers) {
      if (controller.videoItem != null) {
        controller.repeat();
      }
    }
  }
  
  void _stopAllAnimations() {
    for (var controller in controllers) {
      controller.stop();
    }
  }
  
  void _startPerformanceMonitoring() {
    performanceTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _updateFPS();
    });
    
    memoryTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateMemoryUsage();
    });
  }
  
  void _updateFPS() {
    final now = DateTime.now();
    final deltaTime = now.difference(lastFrameTime).inMilliseconds;
    
    if (deltaTime > 0) {
      final fps = 1000.0 / deltaTime;
      setState(() {
        currentFPS = fps;
        fpsHistory.add(fps);
        if (fpsHistory.length > 100) {
          fpsHistory.removeAt(0);
        }
      });
    }
    
    lastFrameTime = now;
    frameCount++;
  }
  
  void _updateMemoryUsage() {
    // 这里可以集成实际的内存监控
    // 暂时使用模拟数据
    setState(() {
      memoryUsage = (controllers.length * 5 + math.Random().nextInt(10));
    });
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('性能压力测试'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          _buildPerformanceInfo(),
          Expanded(
            child: _buildAnimationGrid(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '同时播放 $currentCount 个动画',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('数量: '),
              Expanded(
                child: Slider(
                  value: currentCount.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: currentCount.toString(),
                  onChanged: isLoading ? null : (value) {
                    setState(() {
                      currentCount = value.toInt();
                    });
                    _initializeControllers(currentCount);
                  },
                ),
              ),
              Text('$currentCount'),
            ],
          ),
          Row(
            children: [
              const Text('文件: '),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedFile,
                  isExpanded: true,
                  onChanged: isLoading ? null : (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedFile = newValue;
                        isLoading = true;
                      });
                      _loadAnimations();
                    }
                  },
                  items: testFiles.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.split('/').last),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _playAllAnimations,
                icon: const Icon(Icons.play_arrow),
                label: const Text('全部播放'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _stopAllAnimations,
                icon: const Icon(Icons.stop),
                label: const Text('全部停止'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => _initializeControllers(currentCount),
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceInfo() {
    if (!showFPS && !showMemory) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          if (showFPS) ...[
            Row(
              children: [
                Icon(Icons.speed, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('FPS: ${currentFPS.toStringAsFixed(1)}'),
                SizedBox(width: 16),
                Text('平均: ${_getAverageFPS().toStringAsFixed(1)}'),
                SizedBox(width: 16),
                Text('最低: ${_getMinFPS().toStringAsFixed(1)}'),
              ],
            ),
            SizedBox(height: 8),
            Container(
              height: 40,
              child: _buildFPSChart(),
            ),
          ],
          if (showFPS && showMemory) SizedBox(height: 8),
          if (showMemory) ...[
            Row(
              children: [
                Icon(Icons.memory, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('内存使用: ${memoryUsage}MB'),
                SizedBox(width: 16),
                Text('控制器数量: ${controllers.length}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFPSChart() {
    if (fpsHistory.isEmpty) return SizedBox.shrink();
    
    return CustomPaint(
      painter: FPSChartPainter(fpsHistory),
      child: Container(),
    );
  }
  
  Widget _buildAnimationGrid() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载 $currentCount 个动画...'),
          ],
        ),
      );
    }
    
    // 确保列表长度匹配
    if (controllers.length != currentCount || videoItems.length != currentCount) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在初始化控制器...'),
          ],
        ),
      );
    }
    
    final crossAxisCount = math.sqrt(currentCount).ceil();
    
    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: currentCount,
      itemBuilder: (context, index) {
        return _buildAnimationItem(index);
      },
    );
  }
  
  Widget _buildAnimationItem(int index) {
    // 安全检查，避免数组越界
    if (index >= controllers.length || index >= videoItems.length) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '初始化中...',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    
    final controller = controllers[index];
    final videoItem = videoItems[index];
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${index + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return Icon(
                      controller.isAnimating ? Icons.play_arrow : Icons.pause,
                      size: 16,
                      color: controller.isAnimating ? Colors.green : Colors.grey,
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: videoItem != null
                ? SVGAImage(
                    controller,
                    fit: BoxFit.contain,
                    allowDrawingOverflow: false,
                    filterQuality: FilterQuality.low,
                  )
                : const Center(
                    child: Text(
                      '加载中...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('性能监控设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('显示FPS信息'),
              value: showFPS,
              onChanged: (value) {
                setState(() {
                  showFPS = value;
                });
                Navigator.of(context).pop();
              },
            ),
            SwitchListTile(
              title: const Text('显示内存信息'),
              value: showMemory,
              onChanged: (value) {
                setState(() {
                  showMemory = value;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  double _getAverageFPS() {
    if (fpsHistory.isEmpty) return 0;
    return fpsHistory.reduce((a, b) => a + b) / fpsHistory.length;
  }
  
  double _getMinFPS() {
    if (fpsHistory.isEmpty) return 0;
    return fpsHistory.reduce((a, b) => a < b ? a : b);
  }
}

class FPSChartPainter extends CustomPainter {
  final List<double> fpsHistory;
  
  FPSChartPainter(this.fpsHistory);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (fpsHistory.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final maxFPS = 60.0;
    final minFPS = 0.0;
    
    for (int i = 0; i < fpsHistory.length; i++) {
      final x = (i / (fpsHistory.length - 1)) * size.width;
      final normalizedFPS = (fpsHistory[i] - minFPS) / (maxFPS - minFPS);
      final y = size.height - (normalizedFPS * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // 绘制60FPS基准线
    final baseLinePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, 0),
      baseLinePaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 