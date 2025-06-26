import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:async';
import 'dart:math' as math;

class MemoryTestScreen extends StatefulWidget {
  @override
  _MemoryTestScreenState createState() => _MemoryTestScreenState();
}

class _MemoryTestScreenState extends State<MemoryTestScreen>
    with TickerProviderStateMixin {
  
  List<TestInstance> instances = [];
  Timer? memoryTimer;
  int nextInstanceId = 1;
  
  // 内存监控数据
  List<int> memoryHistory = [];
  int currentMemoryUsage = 0;
  int peakMemoryUsage = 0;
  
  // 测试配置
  final List<String> testFiles = [
    'assets/angel.svga',
    'assets/pin_jump.svga',
  ];
  
  bool autoCleanup = true;
  int maxInstances = 10;
  
  @override
  void initState() {
    super.initState();
    _startMemoryMonitoring();
  }
  
  @override
  void dispose() {
    _disposeAllInstances();
    memoryTimer?.cancel();
    super.dispose();
  }
  
  void _startMemoryMonitoring() {
    memoryTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateMemoryUsage();
    });
  }
  
  void _updateMemoryUsage() {
    // 使用真实的内存使用计算
    int totalMemory = 0;
    for (var instance in instances) {
      if (instance.isLoaded && instance.videoItem != null) {
        // 使用真实的内存估算方法
        totalMemory += instance.videoItem!.estimateMemoryUsage();
      }
    }
    
    // 将字节转换为MB
    totalMemory = totalMemory ~/ (1024 * 1024);
    
    setState(() {
      currentMemoryUsage = totalMemory;
      if (currentMemoryUsage > peakMemoryUsage) {
        peakMemoryUsage = currentMemoryUsage;
      }
      
      memoryHistory.add(currentMemoryUsage);
      if (memoryHistory.length > 60) {
        memoryHistory.removeAt(0);
      }
    });
    
    // 自动清理逻辑
    if (autoCleanup && instances.length > maxInstances) {
      _cleanupOldestInstance();
    }
  }
  
  void _createInstance(String filePath) async {
    final instance = TestInstance(
      id: nextInstanceId++,
      filePath: filePath,
      controller: SVGAAnimationController(vsync: this),
      createdAt: DateTime.now(),
    );
    
    setState(() {
      instances.add(instance);
    });
    
    try {
      final videoItem = await SVGAParser.shared.decodeFromAssets(filePath);
      instance.videoItem = videoItem;
      instance.controller.videoItem = videoItem;
      instance.isLoaded = true;
      instance.estimatedMemoryUsage = _calculateMemoryUsage(videoItem);
      
      setState(() {});
      
      // 自动开始播放
      instance.controller.repeat();
    } catch (e) {
      instance.error = e.toString();
      setState(() {});
    }
  }
  
  int _calculateMemoryUsage(MovieEntity videoItem) {
    // 使用真实的内存使用估算
    return videoItem.estimateMemoryUsage() ~/ (1024 * 1024); // 转换为MB
  }
  
  void _disposeInstance(TestInstance instance) {
    instance.controller.dispose();
    instance.videoItem = null;
    
    setState(() {
      instances.remove(instance);
    });
  }
  
  void _disposeAllInstances() {
    for (var instance in instances) {
      instance.controller.dispose();
    }
    instances.clear();
  }
  
  void _cleanupOldestInstance() {
    if (instances.isNotEmpty) {
      final oldest = instances.reduce((a, b) => 
          a.createdAt.isBefore(b.createdAt) ? a : b);
      _disposeInstance(oldest);
    }
  }
  
  void _forceGarbageCollection() {
    // 在Flutter中无法直接强制GC，但可以通过一些操作来触发
    // 这里主要是UI提示作用
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已尝试触发垃圾回收'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('内存管理测试'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: () {
              _disposeAllInstances();
              setState(() {});
            },
            tooltip: '清理所有实例',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _forceGarbageCollection,
            tooltip: '强制垃圾回收',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMemoryInfo(),
          _buildControlPanel(),
          Expanded(
            child: _buildInstancesList(),
          ),
        ],
      ),
      floatingActionButton: _buildCreateInstanceFAB(),
    );
  }
  
  Widget _buildMemoryInfo() {
    // 获取真实的缓存统计数据
    final cacheStats = SVGAParser.getCacheStats();
    final performanceManager = SVGAPerformanceManager();
    final advice = performanceManager.getPerformanceAdvice();
    
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.green.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.memory, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '内存使用监控',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMemoryCard('当前使用', '$currentMemoryUsage MB', Colors.blue),
              _buildMemoryCard('峰值使用', '$peakMemoryUsage MB', Colors.orange),
              _buildMemoryCard('实例数量', '${instances.length}', Colors.purple),
            ],
          ),
          // 添加缓存统计信息
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text('缓存统计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('缓存: ${cacheStats['total']?['size_formatted'] ?? '0B'}', style: TextStyle(fontSize: 11)),
                    Text('SVGA: ${cacheStats['svga_cache']?['count'] ?? 0}个', style: TextStyle(fontSize: 11)),
                    Text('图片: ${cacheStats['image_cache']?['count'] ?? 0}个', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // 显示性能建议
          if (advice.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('性能建议:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ...advice.map((suggestion) => Text('• $suggestion', style: TextStyle(fontSize: 11))),
                ],
              ),
            ),
          ],
          SizedBox(height: 16),
          Container(
            height: 60,
            child: _buildMemoryChart(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMemoryCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryChart() {
    if (memoryHistory.isEmpty) {
      return Center(child: Text('内存使用图表'));
    }
    
    return CustomPaint(
      painter: MemoryChartPainter(memoryHistory),
      child: Container(),
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Text('自动清理: '),
              Switch(
                value: autoCleanup,
                onChanged: (value) {
                  setState(() {
                    autoCleanup = value;
                  });
                },
              ),
              SizedBox(width: 16),
              Text('最大实例数: '),
              Expanded(
                child: Slider(
                  value: maxInstances.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: maxInstances.toString(),
                  onChanged: (value) {
                    setState(() {
                      maxInstances = value.toInt();
                    });
                  },
                ),
              ),
              Text('$maxInstances'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _createInstance(testFiles[0]),
                icon: Icon(Icons.add),
                label: Text('创建Angel'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              ElevatedButton.icon(
                onPressed: () => _createInstance(testFiles[1]),
                icon: Icon(Icons.add),
                label: Text('创建PinJump'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              ),
              ElevatedButton.icon(
                onPressed: _createRandomInstances,
                icon: Icon(Icons.auto_awesome),
                label: Text('批量创建'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstancesList() {
    if (instances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.memory, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '暂无SVGA实例',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              '点击下方按钮创建实例进行内存测试',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: instances.length,
      itemBuilder: (context, index) {
        return _buildInstanceCard(instances[index]);
      },
    );
  }
  
  Widget _buildInstanceCard(TestInstance instance) {
    final age = DateTime.now().difference(instance.createdAt);
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // 预览区域
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: instance.isLoaded && instance.videoItem != null
                  ? SVGAImage(
                      instance.controller,
                      fit: BoxFit.contain,
                      allowDrawingOverflow: false,
                      filterQuality: FilterQuality.low,
                    )
                  : Center(
                      child: instance.error != null
                          ? Icon(Icons.error, color: Colors.red)
                          : CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
            
            SizedBox(width: 12),
            
            // 信息区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ID: ${instance.id}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: instance.isLoaded ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          instance.isLoaded ? '已加载' : '加载中',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    instance.filePath.split('/').last,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '内存: ${instance.estimatedMemoryUsage} MB',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                  Text(
                    '存活: ${age.inSeconds}s',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (instance.error != null) ...[
                    SizedBox(height: 4),
                    Text(
                      '错误: ${instance.error}',
                      style: TextStyle(fontSize: 10, color: Colors.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // 控制按钮
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    instance.controller.isAnimating ? Icons.pause : Icons.play_arrow,
                    color: instance.controller.isAnimating ? Colors.orange : Colors.green,
                  ),
                  onPressed: instance.isLoaded ? () {
                    if (instance.controller.isAnimating) {
                      instance.controller.stop();
                    } else {
                      instance.controller.repeat();
                    }
                    setState(() {});
                  } : null,
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _disposeInstance(instance),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreateInstanceFAB() {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '选择要创建的SVGA实例',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                ...testFiles.map((file) => ListTile(
                  leading: Icon(Icons.play_circle_outline),
                  title: Text(file.split('/').last),
                  subtitle: Text(file),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createInstance(file);
                  },
                )).toList(),
              ],
            ),
          ),
        );
      },
      child: Icon(Icons.add),
      backgroundColor: Colors.green,
    );
  }
  
  void _createRandomInstances() {
    final random = math.Random();
    final count = 3 + random.nextInt(5); // 3-7个实例
    
    for (int i = 0; i < count; i++) {
      final randomFile = testFiles[random.nextInt(testFiles.length)];
      Future.delayed(Duration(milliseconds: i * 200), () {
        _createInstance(randomFile);
      });
    }
  }
}

class TestInstance {
  final int id;
  final String filePath;
  final SVGAAnimationController controller;
  final DateTime createdAt;
  
  MovieEntity? videoItem;
  bool isLoaded = false;
  int estimatedMemoryUsage = 0;
  String? error;
  
  TestInstance({
    required this.id,
    required this.filePath,
    required this.controller,
    required this.createdAt,
  });
}

class MemoryChartPainter extends CustomPainter {
  final List<int> memoryHistory;
  
  MemoryChartPainter(this.memoryHistory);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (memoryHistory.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final fillPath = Path();
    
    final maxMemory = memoryHistory.isEmpty ? 1 : 
        memoryHistory.reduce((a, b) => a > b ? a : b).toDouble();
    
    // 绘制填充区域
    fillPath.moveTo(0, size.height);
    
    for (int i = 0; i < memoryHistory.length; i++) {
      final x = (i / (memoryHistory.length - 1)) * size.width;
      final normalizedMemory = memoryHistory[i] / maxMemory;
      final y = size.height - (normalizedMemory * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // 完成填充路径
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 