import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class MultipleTest1TestScreen extends StatefulWidget {
  @override
  _MultipleTest1TestScreenState createState() => _MultipleTest1TestScreenState();
}

class _MultipleTest1TestScreenState extends State<MultipleTest1TestScreen> 
    with TickerProviderStateMixin {
  List<SVGAAnimationController> controllers = [];
  int animationCount = 3;
  bool isLoading = false;
  String? error;
  SVGAOptimizationConfig currentConfig = SVGAOptimizationConfig.balanced;
  
  final Map<String, SVGAOptimizationConfig> configs = {
    '原始模式 (无优化)': SVGAOptimizationConfig.highQuality,
    '平衡模式': SVGAOptimizationConfig.balanced,
    '高性能模式': SVGAOptimizationConfig.highPerformance,
    '极限压缩模式': SVGAOptimizationConfig(
      enableSpriteFiltering: true,
      maxSpriteMemoryBytes: 1024 * 1024, // 1MB
      enableImageCompression: true,
      maxImageWidth: 256,
      maxImageHeight: 256,
      imageCompressionQuality: 0.3,
      maxImageMemoryBytes: 5 * 1024 * 1024, // 5MB
      loadAudio: false,
      enableDebugLog: true,
    ),
  };

  @override
  void initState() {
    super.initState();
    SVGAParser.setOptimizationConfig(currentConfig);
  }

  @override
  void dispose() {
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    for (var controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
  }

  Future<void> _loadAnimations() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // 先清理旧的控制器
      _disposeAllControllers();
      
      // 清除缓存确保全新加载
      SVGAParser.clearCache();
      
      // 设置优化配置
      SVGAParser.setOptimizationConfig(currentConfig);
      
      print('开始加载 $animationCount 个 test1.svga 实例...');
      
      // 并发创建多个控制器和加载动画
      final futures = List.generate(animationCount, (index) async {
        final controller = SVGAAnimationController(vsync: this);
        
        try {
          print('正在加载第 ${index + 1} 个实例...');
          final videoItem = await SVGAParser.shared.decodeFromAssets('assets/test1.svga');
          controller.videoItem = videoItem;
          return controller;
        } catch (e) {
          print('加载第 ${index + 1} 个实例失败: $e');
          controller.dispose();
          rethrow;
        }
      });
      
      final loadedControllers = await Future.wait(futures);
      
      setState(() {
        controllers = loadedControllers;
        isLoading = false;
      });
      
      // 开始播放所有动画
      for (var controller in controllers) {
        controller.repeat();
      }
      
      print('成功加载 ${controllers.length} 个 test1.svga 实例');
      
      // 打印缓存统计
      final stats = SVGAParser.getCacheStats();
      print('缓存统计: ${stats['total']['size_formatted']}, ${stats['svga_cache']['count']} 项');
      
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
      print('加载失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('多实例 Test1.svga 测试'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadAnimations,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConfigPanel(),
          _buildStatsPanel(),
          Expanded(
            child: _buildAnimationGrid(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfigPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.red.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '测试配置',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 12),
          
          // 动画数量选择
          Row(
            children: [
              Text('实例数量: '),
              Expanded(
                child: Slider(
                  value: animationCount.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$animationCount 个',
                  onChanged: isLoading ? null : (value) {
                    setState(() {
                      animationCount = value.toInt();
                    });
                  },
                ),
              ),
              Text('$animationCount'),
            ],
          ),
          
          // 优化配置选择
          Row(
            children: [
              Text('优化模式: '),
              Expanded(
                child: DropdownButton<SVGAOptimizationConfig>(
                  value: currentConfig,
                  isExpanded: true,
                  items: configs.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.value,
                      child: Text(entry.key),
                    );
                  }).toList(),
                  onChanged: isLoading ? null : (value) {
                    if (value != null) {
                      setState(() {
                        currentConfig = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // 加载按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _loadAnimations,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(isLoading ? '加载中...' : '开始测试'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsPanel() {
    final stats = SVGAParser.getCacheStats();
    
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '测试状态',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: Text('实例状态: ${controllers.length} / $animationCount 已加载'),
              ),
              if (stats.isNotEmpty)
                Text('内存: ${stats['total']['size_formatted']}'),
            ],
          ),
          
          if (error != null) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '错误: $error',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAnimationGrid() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载 $animationCount 个 test1.svga 实例...'),
          ],
        ),
      );
    }
    
    if (controllers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text('请配置参数并开始测试'),
          ],
        ),
      );
    }
    
    // 计算网格布局
    final crossAxisCount = (controllers.length <= 4) ? 2 : 3;
    
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '动画网格 (${controllers.length} 个实例)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 16),
          
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: controllers.length,
              itemBuilder: (context, index) {
                final controller = controllers[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        SVGAImage(controller),
                        
                        // 实例编号标签
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 