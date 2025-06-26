import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class OptimizationTestScreen extends StatefulWidget {
  @override
  _OptimizationTestScreenState createState() => _OptimizationTestScreenState();
}

class _OptimizationTestScreenState extends State<OptimizationTestScreen> with TickerProviderStateMixin {
  SVGAAnimationController? controller;
  String currentFile = 'assets/test1.svga';
  SVGAOptimizationConfig currentConfig = SVGAOptimizationConfig.balanced;
  bool isLoading = false;
  String? loadingError;
  Map<String, dynamic> beforeStats = {};
  Map<String, dynamic> afterStats = {};

  final List<String> testFiles = [
    'assets/test1.svga',
    'assets/angel.svga',
    'assets/pin_jump.svga',
  ];

  final Map<String, SVGAOptimizationConfig> configs = {
    '高质量模式': SVGAOptimizationConfig.highQuality,
    '平衡模式': SVGAOptimizationConfig.balanced,
    '高性能模式': SVGAOptimizationConfig.highPerformance,
    '自定义模式': const SVGAOptimizationConfig(
      enableSpriteFiltering: true,
      maxSpriteMemoryBytes: 2 * 1024 * 1024,
      // 2MB
      enableImageCompression: true,
      maxImageWidth: 512,
      maxImageHeight: 512,
      imageCompressionQuality: 0.5,
      maxImageMemoryBytes: 10 * 1024 * 1024,
      // 10MB
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
    controller?.dispose();
    super.dispose();
  }

  Future<void> _loadAnimation() async {
    setState(() {
      isLoading = true;
      loadingError = null;
    });

    try {
      // 清除缓存确保是全新加载
      SVGAParser.clearCache();

      // 记录加载前状态
      beforeStats = SVGAParser.getCacheStats();

      // 设置当前配置
      SVGAParser.setOptimizationConfig(currentConfig);

      // 释放旧控制器
      controller?.dispose();

      // 创建新控制器并加载
      controller = SVGAAnimationController(vsync: this);
      final videoItem = await SVGAParser.shared.decodeFromAssets(currentFile);
      controller!.videoItem = videoItem;

      // 记录加载后状态
      afterStats = SVGAParser.getCacheStats();

      // 开始播放
      controller!.repeat();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        loadingError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('内存优化测试'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          _buildConfigPanel(),
          _buildStatsPanel(),
          Expanded(
            child: _buildAnimationArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.green.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '优化配置',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // 文件选择
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: currentFile,
                  isExpanded: true,
                  items: testFiles.map((file) {
                    final fileName = file.split('/').last;
                    return DropdownMenuItem(
                      value: file,
                      child: Text(fileName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        currentFile = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          // 配置选择
          Row(
            children: [
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
                  onChanged: (value) {
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
              onPressed: isLoading ? null : _loadAnimation,
              child: Text(isLoading ? '加载中...' : '加载动画'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '内存统计',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (afterStats.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '缓存项目',
                    '${afterStats['svga_cache']?['count'] ?? 0}个',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '内存占用',
                    afterStats['total']?['size_formatted'] ?? '0B',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '图片缓存',
                    '${afterStats['image_cache']?['count'] ?? 0}个',
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '使用率',
                    '${afterStats['total']?['usage_percentage'] ?? '0.0'}%',
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // 当前配置信息
            _buildConfigInfo(),
            
            // 显示性能建议
            SizedBox(height: 8),
            _buildPerformanceAdvice(),
          ] else
            Text('暂无统计数据，请先加载动画'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigInfo() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前优化配置:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            '• 精灵过滤: ${currentConfig.enableSpriteFiltering ? "启用" : "禁用"}',
            style: TextStyle(fontSize: 11),
          ),
          if (currentConfig.enableSpriteFiltering)
            Text(
              '  - 最大精灵内存: ${currentConfig.formatBytes(currentConfig.maxSpriteMemoryBytes)}',
              style: TextStyle(fontSize: 11),
            ),
          Text(
            '• 图片压缩: ${currentConfig.enableImageCompression ? "启用" : "禁用"}',
            style: TextStyle(fontSize: 11),
          ),
          if (currentConfig.enableImageCompression) ...[
            Text(
              '  - 最大尺寸: ${currentConfig.maxImageWidth}x${currentConfig.maxImageHeight}',
              style: TextStyle(fontSize: 11),
            ),
            Text(
              '  - 最大图片内存: ${currentConfig.formatBytes(currentConfig.maxImageMemoryBytes)}',
              style: TextStyle(fontSize: 11),
            ),
          ],
          Text(
            '• 音效加载: ${currentConfig.loadAudio ? "启用" : "禁用"}',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
    }
  
  Widget _buildPerformanceAdvice() {
    final performanceManager = SVGAPerformanceManager();
    final advice = performanceManager.getPerformanceAdvice();
    
    if (advice.isEmpty) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('性能良好，无优化建议', style: TextStyle(fontSize: 11, color: Colors.green[700])),
          ],
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text('性能建议:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange[700])),
            ],
          ),
          SizedBox(height: 4),
          ...advice.map((suggestion) => Padding(
            padding: EdgeInsets.only(left: 24),
            child: Text('• $suggestion', style: TextStyle(fontSize: 11)),
          )),
        ],
      ),
    );
  }
  
  Widget _buildAnimationArea() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.animation, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                '动画预览',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: Center(
              child: _buildAnimationContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationContent() {
    if (isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载动画...'),
        ],
      );
    }

    if (loadingError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8),
          Text(
            loadingError!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    if (controller?.videoItem == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie, color: Colors.grey, size: 48),
          SizedBox(height: 16),
          Text('请选择配置并加载动画'),
        ],
      );
    }

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SVGAImage(controller!),
    );
  }
}
