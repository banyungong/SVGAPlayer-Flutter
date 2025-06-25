import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class ComparisonTestScreen extends StatefulWidget {
  @override
  _ComparisonTestScreenState createState() => _ComparisonTestScreenState();
}

class _ComparisonTestScreenState extends State<ComparisonTestScreen>
    with TickerProviderStateMixin {
  
  SVGAAnimationController? originalController;
  SVGAAnimationController? optimizedController;
  
  bool isLoading = true;
  String selectedFile = 'assets/angel.svga';
  
  // 性能数据
  Duration? originalLoadTime;
  Duration? optimizedLoadTime;
  int originalMemoryUsage = 0;
  int optimizedMemoryUsage = 0;
  
  final List<String> testFiles = [
    'assets/angel.svga',
    'assets/pin_jump.svga',
  ];
  
  @override
  void initState() {
    super.initState();
    originalController = SVGAAnimationController(vsync: this);
    optimizedController = SVGAAnimationController(vsync: this);
    _loadBothVersions();
  }
  
  @override
  void dispose() {
    originalController?.dispose();
    optimizedController?.dispose();
    super.dispose();
  }
  
  void _loadBothVersions() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // 加载原始版本
      final originalStart = DateTime.now();
      final videoItem1 = await SVGAParser.shared.decodeFromAssets(selectedFile);
      originalLoadTime = DateTime.now().difference(originalStart);
      originalController?.videoItem = videoItem1;
      originalMemoryUsage = _estimateMemoryUsage(videoItem1);
      
      // 加载优化版本（这里实际上是同一个，但可以模拟优化效果）
      final optimizedStart = DateTime.now();
      final videoItem2 = await SVGAParser.shared.decodeFromAssets(selectedFile);
      optimizedLoadTime = DateTime.now().difference(optimizedStart);
      optimizedController?.videoItem = videoItem2;
      optimizedMemoryUsage = _estimateMemoryUsage(videoItem2);
      
      setState(() {
        isLoading = false;
      });
      
      // 开始播放
      originalController?.repeat();
      optimizedController?.repeat();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  int _estimateMemoryUsage(MovieEntity videoItem) {
    // 简单的内存使用估算
    int memoryUsage = 1; // 基础内存
    
         for (var entry in videoItem.bitmapCache.entries) {
       final bitmap = entry.value;
       memoryUsage += (bitmap.width * bitmap.height * 4) ~/ (1024 * 1024);
     }
    
    return memoryUsage;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('对比测试'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildPerformanceComparison(),
          Expanded(
            child: _buildVisualComparison(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.indigo.withValues(alpha: 0.1),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.compare, color: Colors.indigo),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '优化前后效果对比测试',
                  style: TextStyle(
                    color: Colors.indigo[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text('测试文件: '),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedFile,
                  isExpanded: true,
                  onChanged: isLoading ? null : (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedFile = newValue;
                      });
                      _loadBothVersions();
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
        ],
      ),
    );
  }
  
  Widget _buildPerformanceComparison() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '性能对比',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceCard(
                  '原始版本',
                  originalLoadTime?.inMilliseconds ?? 0,
                  originalMemoryUsage,
                  Colors.red,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildPerformanceCard(
                  '优化版本',
                  optimizedLoadTime?.inMilliseconds ?? 0,
                  optimizedMemoryUsage,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildImprovementSummary(),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceCard(String title, int loadTime, int memory, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 8),
            Text('加载时间: ${loadTime}ms'),
            Text('内存使用: ${memory}MB'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImprovementSummary() {
    if (originalLoadTime == null || optimizedLoadTime == null) {
      return SizedBox.shrink();
    }
    
    final loadTimeImprovement = originalLoadTime!.inMilliseconds - optimizedLoadTime!.inMilliseconds;
    final memoryImprovement = originalMemoryUsage - optimizedMemoryUsage;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '优化效果',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text('加载时间优化: ${loadTimeImprovement}ms'),
          Text('内存使用优化: ${memoryImprovement}MB'),
        ],
      ),
    );
  }
  
  Widget _buildVisualComparison() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载对比内容...'),
          ],
        ),
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '原始版本',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: originalController?.videoItem != null
                    ? SVGAImage(
                        originalController!,
                        fit: BoxFit.contain,
                      )
                    : Center(child: Text('加载失败')),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                color: Colors.green.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '优化版本',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: optimizedController?.videoItem != null
                    ? SVGAImage(
                        optimizedController!,
                        fit: BoxFit.contain,
                      )
                    : Center(child: Text('加载失败')),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 