import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

/// 缓存测试页面，用于验证内存使用情况
class CacheTestPage extends StatefulWidget {
  const CacheTestPage({Key? key}) : super(key: key);

  @override
  State<CacheTestPage> createState() => _CacheTestPageState();
}

class _CacheTestPageState extends State<CacheTestPage> {
  final List<SVGAAnimationController> _controllers = [];
  final List<String> _svgaFiles = [
    'assets/angel.svga',
    'assets/pin_jump.svga',
    'assets/test1.svga',
  ];
  
  int _loadedCount = 0;
  Map<String, dynamic>? _cacheStats;

  @override
  void initState() {
    super.initState();
    _loadSVGAs();
    _updateCacheStats();
  }

  void _loadSVGAs() async {
    for (int i = 0; i < 300; i++) {
      final controller = SVGAAnimationController(vsync: this);
      
      // 循环使用3个SVGA文件
      final svgaFile = _svgaFiles[i % _svgaFiles.length];
      
      try {
        final movie = await SVGAParser.shared.decodeFromAssets(svgaFile);
        controller.videoItem = movie;
        
        setState(() {
          _controllers.add(controller);
          _loadedCount++;
        });
        
        // 每加载10个更新一次缓存统计
        if (_loadedCount % 10 == 0) {
          _updateCacheStats();
        }
        
        // 模拟页面滚动，只显示前50个
        if (_loadedCount > 50) {
          // 停止不在可见区域的动画
          controller.stop();
        }
        
      } catch (e) {
        print('加载SVGA失败: $e');
      }
    }
  }

  void _updateCacheStats() {
    setState(() {
      _cacheStats = SVGAParser.getCacheStats();
    });
  }

  void _clearCache() {
    SVGAParser.clearCache();
    _updateCacheStats();
  }

  void _cleanupDuplicates() {
    SVGAParser.cleanupDuplicateImages();
    _updateCacheStats();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVGA缓存测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateCacheStats,
            tooltip: '刷新统计',
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _cleanupDuplicates,
            tooltip: '清理重复缓存',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearCache,
            tooltip: '清空缓存',
          ),
        ],
      ),
      body: Column(
        children: [
          // 缓存统计信息
          if (_cacheStats != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已加载SVGA数量: $_loadedCount'),
                  const SizedBox(height: 8),
                  Text('SVGA缓存: ${_cacheStats!['svga_cache']['count']} 个, ${_cacheStats!['svga_cache']['size_formatted']}'),
                  Text('图片缓存: ${_cacheStats!['image_cache']['count']} 个, ${_cacheStats!['image_cache']['size_formatted']}'),
                  Text('实际图片: ${_cacheStats!['actual_images']['total_count']} 个, ${_cacheStats!['actual_images']['total_memory_formatted']}'),
                  Text('总内存: ${_cacheStats!['total']['size_formatted']} (${_cacheStats!['total']['usage_percentage']}%)'),
                ],
              ),
            ),
          
          // SVGA列表
          Expanded(
            child: ListView.builder(
              itemCount: _controllers.length,
              itemBuilder: (context, index) {
                final controller = _controllers[index];
                return Container(
                  height: 100,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // SVGA显示区域
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: SVGAImage(controller),
                      ),
                      
                      // 信息区域
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('SVGA #${index + 1}'),
                              Text('文件: ${_svgaFiles[index % _svgaFiles.length]}'),
                              Text('状态: ${controller.isAnimating ? "播放中" : "已停止"}'),
                              Text('引用计数: ${controller.videoItem?.referenceCount ?? 0}'),
                            ],
                          ),
                        ),
                      ),
                      
                      // 控制按钮
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(controller.isAnimating ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              if (controller.isAnimating) {
                                controller.stop();
                              } else {
                                controller.repeat();
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
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
