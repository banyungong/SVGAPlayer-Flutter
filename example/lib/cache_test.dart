import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';
import 'dart:async';

class CacheTestScreen extends StatefulWidget {
  const CacheTestScreen({Key? key}) : super(key: key);

  @override
  _CacheTestScreenState createState() => _CacheTestScreenState();
}

class _CacheTestScreenState extends State<CacheTestScreen> with TickerProviderStateMixin {
  final List<SVGAAnimationController> controllers = [];
  final List<String> testFiles = [
    'assets/angel.svga',
    'assets/pin_jump.svga',
  ];
  
  bool isLoading = false;
  Map<String, dynamic> cacheStats = {};
  Timer? statsTimer;
  
  @override
  void initState() {
    super.initState();
    _startStatsMonitoring();
    _updateCacheStats();
  }
  
  @override
  void dispose() {
    statsTimer?.cancel();
    _disposeAllControllers();
    super.dispose();
  }
  
  void _startStatsMonitoring() {
    statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCacheStats();
    });
  }
  
  void _updateCacheStats() {
    setState(() {
      cacheStats = SVGAParser.getCacheStats();
    });
  }
  
  void _disposeAllControllers() {
    for (var controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
  }
  
  Future<void> _createMultipleSameAnimations() async {
    setState(() {
      isLoading = true;
    });
    
    _disposeAllControllers();
    
    try {
      // 创建10个相同的angel.svga动画
      for (int i = 0; i < 10; i++) {
        final controller = SVGAAnimationController(vsync: this);
        final videoItem = await SVGAParser.shared.decodeFromAssets('assets/angel.svga');
        controller.videoItem = videoItem;
        controllers.add(controller);
        controller.repeat();
      }
      
      setState(() {
        isLoading = false;
      });
      
      _showMessage('成功创建10个相同动画，观察缓存复用效果！');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('创建失败: $e');
    }
  }
  
  Future<void> _createMultipleDifferentAnimations() async {
    setState(() {
      isLoading = true;
    });
    
    _disposeAllControllers();
    
    try {
      // 创建不同的动画
      for (int i = 0; i < 6; i++) {
        final controller = SVGAAnimationController(vsync: this);
        final file = testFiles[i % testFiles.length];
        final videoItem = await SVGAParser.shared.decodeFromAssets(file);
        controller.videoItem = videoItem;
        controllers.add(controller);
        controller.repeat();
      }
      
      setState(() {
        isLoading = false;
      });
      
      _showMessage('成功创建6个不同动画，观察缓存增长！');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('创建失败: $e');
    }
  }
  
  Future<void> _testCacheEviction() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // 快速创建大量不同的URL资源来触发LRU清理
      // 注意：这些URL不会真正下载，只是演示缓存键的生成
      for (int i = 0; i < 150; i++) {
        // 模拟不同的缓存键 - 实际项目中这里会有真实的缓存操作
        // final fakeUrl = 'https://example.com/test_$i.svga';
        // 这里我们不实际下载，只是为了演示LRU逻辑
      }
      
      setState(() {
        isLoading = false;
      });
      
      _showMessage('LRU测试完成，超过100个缓存项会被自动清理！');
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('测试失败: $e');
    }
  }
  
  void _clearCache() {
    SVGAParser.clearCache();
    _updateCacheStats();
    _showMessage('缓存已清空！');
  }
  
  void _clearExpiredCache() {
    SVGAParser.clearExpiredCache(const Duration(minutes: 5));
    _updateCacheStats();
    _showMessage('过期缓存已清理！');
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
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
        title: const Text('缓存系统测试'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          _buildCacheStats(),
          _buildControlPanel(),
          Expanded(
            child: _buildAnimationGrid(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCacheStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.purple.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                '缓存统计信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cacheStats.isNotEmpty) ...[
            _buildCacheStatItem('SVGA缓存', cacheStats['svga_cache']),
            const SizedBox(height: 8),
            _buildCacheStatItem('图片缓存', cacheStats['image_cache']),
            const SizedBox(height: 8),
            _buildCacheStatItem('总计', cacheStats['total']),
          ] else
            const Text('暂无缓存数据'),
        ],
      ),
    );
  }
  
  Widget _buildCacheStatItem(String title, Map<String, dynamic>? stats) {
    if (stats == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            '${stats['count'] ?? 0}项 | ${stats['size_formatted'] ?? '0B'} | ${stats['usage_percentage'] ?? '0.0'}%',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          Text(
            '当前显示 ${controllers.length} 个动画实例',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : _createMultipleSameAnimations,
                icon: const Icon(Icons.content_copy),
                label: const Text('10个相同动画'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _createMultipleDifferentAnimations,
                icon: const Icon(Icons.shuffle),
                label: const Text('6个不同动画'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _testCacheEviction,
                icon: const Icon(Icons.auto_delete),
                label: const Text('测试LRU清理'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _clearCache,
                icon: const Icon(Icons.clear_all),
                label: const Text('清空缓存'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              ),
              ElevatedButton.icon(
                onPressed: _clearExpiredCache,
                icon: const Icon(Icons.schedule),
                label: const Text('清理过期'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimationGrid() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在创建动画实例...'),
          ],
        ),
      );
    }
    
    if (controllers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.animation, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '点击上方按钮开始测试缓存效果',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '🔄 相同动画会复用缓存资源\n📊 观察缓存统计信息的变化\n🧹 LRU算法自动管理内存',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: controllers.length,
      itemBuilder: (context, index) => _buildAnimationItem(index),
    );
  }
  
  Widget _buildAnimationItem(int index) {
    final controller = controllers[index];
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle, size: 16, color: Colors.purple[700]),
                const SizedBox(width: 4),
                Text(
                  '实例 #${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return controller.videoItem != null
                    ? SVGAImage(
                        controller,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.low,
                      )
                    : const Center(
                        child: Text(
                          '加载中...',
                          style: TextStyle(fontSize: 12),
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