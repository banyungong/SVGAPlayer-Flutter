import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class MemoryCheckTest extends StatefulWidget {
  @override
  _MemoryCheckTestState createState() => _MemoryCheckTestState();
}

class _MemoryCheckTestState extends State<MemoryCheckTest> 
    with TickerProviderStateMixin {
  List<SVGAAnimationController> controllers = [];
  bool isLoading = false;
  Map<String, dynamic> cacheStats = {};
  Set<int> entityHashCodes = <int>{};

  @override
  void initState() {
    super.initState();
    _updateCacheStats();
  }

  @override
  void dispose() {
    _disposeAllControllers();
    super.dispose();
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
    entityHashCodes.clear();
  }

  Future<void> _createMultipleAnimations(int count) async {
    setState(() {
      isLoading = true;
    });
    
    _disposeAllControllers();
    
    try {
      for (int i = 0; i < count; i++) {
        print('=== 创建第${i+1}个动画实例 ===');
        final controller = SVGAAnimationController(vsync: this);
        final videoItem = await SVGAParser.shared.decodeFromAssets('assets/angel.svga');
        
        entityHashCodes.add(videoItem.hashCode);
        print('第${i+1}个MovieEntity hashCode: ${videoItem.hashCode}');
        
        controller.videoItem = videoItem;
        controllers.add(controller);
        controller.repeat();
      }
      
      setState(() {
        isLoading = false;
      });
      
      _updateCacheStats();
      
      // 分析结果
      if (entityHashCodes.length == 1) {
        _showMessage('✅ 成功！${count}个动画共享1个MovieEntity实例', Colors.green);
      } else {
        _showMessage('❌ 失败！创建了${entityHashCodes.length}个不同的MovieEntity实例', Colors.red);
      }
      
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('创建失败: $e');
    }
  }

  void _clearCache() {
    SVGAParser.clearCache();
    _updateCacheStats();
    _showMessage('缓存已清空！', Colors.blue);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    _showMessage(message, Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('内存复用验证测试'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          // 缓存统计
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Colors.purple.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '缓存统计信息',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                if (cacheStats.isNotEmpty) ...[
                  Text('SVGA缓存: ${cacheStats['svga_cache']?['count'] ?? 0}项'),
                  Text('总大小: ${cacheStats['total']?['size_formatted'] ?? '0B'}'),
                ] else
                  Text('暂无缓存数据'),
                
                SizedBox(height: 12),
                Text(
                  '实例分析',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('当前控制器数量: ${controllers.length}'),
                Text('不同MovieEntity数量: ${entityHashCodes.length}'),
                if (entityHashCodes.isNotEmpty)
                  Text('MovieEntity HashCodes: ${entityHashCodes.join(', ')}'),
              ],
            ),
          ),
          
          // 控制按钮
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _createMultipleAnimations(3),
                        child: Text(isLoading ? '创建中...' : '创建3个动画'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _createMultipleAnimations(10),
                        child: Text(isLoading ? '创建中...' : '创建10个动画'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _clearCache,
                        child: Text('清空缓存'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _disposeAllControllers();
                          setState(() {});
                        },
                        child: Text('清空动画'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 期望结果说明
          Container(
            padding: EdgeInsets.all(16),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '期望结果',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 8),
                Text('• 多个相同动画应该共享同一个MovieEntity实例'),
                Text('• 不同MovieEntity数量应该始终为1'),
                Text('• 所有MovieEntity的hashCode应该相同'),
                Text('• 缓存大小应该约等于单个SVGA文件的大小'),
              ],
            ),
          ),
          
          // 动画显示区域
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : controllers.isEmpty
                    ? Center(child: Text('暂无动画'))
                    : GridView.builder(
                        padding: EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: controllers.length,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: controllers[index].videoItem != null
                                ? SVGAImage(controllers[index])
                                : Center(child: Text('${index + 1}')),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: MemoryCheckTest(),
    debugShowCheckedModeBanner: false,
  ));
} 