import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class OptimizedSVGAExample extends StatefulWidget {
  const OptimizedSVGAExample({Key? key}) : super(key: key);

  @override
  State<OptimizedSVGAExample> createState() => _OptimizedSVGAExampleState();
}

class _OptimizedSVGAExampleState extends State<OptimizedSVGAExample>
    with TickerProviderStateMixin {
  SVGAAnimationController? _controller;
  final _performanceManager = SVGAPerformanceManager();
  List<String> _performanceAdvice = [];

  @override
  void initState() {
    super.initState();
    _initializeController();
    _loadAnimation();
    _startPerformanceMonitoring();
  }

  void _initializeController() {
    _controller = SVGAAnimationController(vsync: this);
  }

  Future<void> _loadAnimation() async {
    try {
      // 使用优化后的解析器，自动包含缓存和并发优化
      final movieEntity = await SVGAParser.shared.decodeFromAssets('assets/angel.svga');
      
      if (mounted && _controller != null) {
        _controller!.videoItem = movieEntity;
        _controller!.repeat();
        
        // 优化内存使用
        movieEntity.optimizeMemory();
      }
    } catch (e) {
      debugPrint('加载SVGA动画失败: $e');
    }
  }

  void _startPerformanceMonitoring() {
    // 定期检查性能建议
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _performanceAdvice = _performanceManager.getPerformanceAdvice();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('优化版SVGA播放器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory),
            onPressed: _showPerformanceInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // 性能建议提示
          if (_performanceAdvice.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '性能建议：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ..._performanceAdvice.map(
                    (advice) => Text('• $advice'),
                  ),
                ],
              ),
            ),
          
          // SVGA播放器
          Expanded(
            child: Center(
              child: _controller == null
                  ? const CircularProgressIndicator()
                  : SVGAImage(
                      _controller!,
                      fit: BoxFit.contain,
                      // 使用高质量过滤器以获得更好的视觉效果
                      filterQuality: FilterQuality.high,
                      // 防止绘制溢出，减少内存开销
                      allowDrawingOverflow: false,
                    ),
            ),
          ),
          
          // 控制按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _controller?.forward(),
                  child: const Text('播放'),
                ),
                ElevatedButton(
                  onPressed: () => _controller?.stop(),
                  child: const Text('停止'),
                ),
                ElevatedButton(
                  onPressed: () => _controller?.reset(),
                  child: const Text('重置'),
                ),
                ElevatedButton(
                  onPressed: _forceMemoryCleanup,
                  child: const Text('清理内存'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPerformanceInfo() {
    final memoryUsage = _performanceManager.memoryUsage;
    final totalMemory = _performanceManager.totalMemoryUsage;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('性能信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总内存使用: ${(totalMemory / 1024 / 1024).toStringAsFixed(2)} MB'),
            const SizedBox(height: 8),
            const Text('各动画内存使用:'),
            ...memoryUsage.entries.map(
              (entry) => Text(
                '${entry.key}: ${(entry.value / 1024).toStringAsFixed(1)} KB',
              ),
            ),
            const SizedBox(height: 16),
            const Text('性能建议:'),
            if (_performanceAdvice.isEmpty)
              const Text('暂无性能问题')
            else
              ..._performanceAdvice.map(
                (advice) => Text('• $advice'),
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

  void _forceMemoryCleanup() {
    _performanceManager.forceMemoryCleanup();
    SVGAParser.clearImageCache();
    setState(() {
      _performanceAdvice = _performanceManager.getPerformanceAdvice();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('内存清理完成')),
    );
  }
}

/// 展示多个SVGA动画的性能优化示例
class MultiSVGAExample extends StatefulWidget {
  const MultiSVGAExample({Key? key}) : super(key: key);

  @override
  State<MultiSVGAExample> createState() => _MultiSVGAExampleState();
}

class _MultiSVGAExampleState extends State<MultiSVGAExample>
    with TickerProviderStateMixin {
  final List<SVGAAnimationController> _controllers = [];
  final List<String> _animations = [
    'assets/angel.svga',
    'assets/pin_jump.svga',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (int i = 0; i < _animations.length; i++) {
      final controller = SVGAAnimationController(vsync: this);
      _controllers.add(controller);
      
      // 异步加载动画，利用并发优化
      SVGAParser.shared.decodeFromAssets(_animations[i]).then((movieEntity) {
        if (mounted && i < _controllers.length) {
          _controllers[i].videoItem = movieEntity;
          _controllers[i].repeat();
          
          // 每个动画都进行内存优化
          movieEntity.optimizeMemory();
        }
      }).catchError((e) {
        debugPrint('加载动画 ${_animations[i]} 失败: $e');
      });
    }
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
        title: const Text('多SVGA动画优化示例'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _controllers.length,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SVGAImage(
              _controllers[index],
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium, // 适中的质量以平衡性能
              allowDrawingOverflow: false,
            ),
          );
        },
      ),
    );
  }
} 