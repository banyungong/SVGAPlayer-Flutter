import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class RepeatPlaybackTestScreen extends StatefulWidget {
  @override
  _RepeatPlaybackTestScreenState createState() => _RepeatPlaybackTestScreenState();
}

class _RepeatPlaybackTestScreenState extends State<RepeatPlaybackTestScreen>
    with TickerProviderStateMixin {
  SVGAAnimationController? controller;
  
  // 测试状态
  bool isLoading = false;
  String statusText = '等待开始测试';
  int playCount = 0;
  int errorCount = 0;
  String? lastError;
  
  // 测试配置
  final String testUrl = 'https://reosurce-preview.hokilive.net/app-animation/moment_crazy_like1.svga';
  bool autoRepeat = false;
  int targetPlayCount = 10;
  
  // 日志
  final List<LogEntry> logs = [];
  
  @override
  void initState() {
    super.initState();
    _addLog('初始化重复播放测试', LogLevel.info);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
  
  void _addLog(String message, LogLevel level) {
    setState(() {
      logs.insert(0, LogEntry(
        timestamp: DateTime.now(),
        message: message,
        level: level,
      ));
      
      // 只保留最近的100条日志
      if (logs.length > 100) {
        logs.removeRange(100, logs.length);
      }
    });
    
    if (kDebugMode) {
      print('[${level.name.toUpperCase()}] $message');
    }
  }

  Future<void> _loadSVGA() async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
      statusText = '正在加载SVGA文件...';
      lastError = null;
    });
    
    _addLog('开始加载SVGA: $testUrl', LogLevel.info);
    
    try {
      // 先释放之前的控制器
      if (controller != null) {
        _addLog('释放之前的控制器', LogLevel.info);
        controller!.dispose();
        controller = null;
      }
      
      // 创建新的控制器
      controller = SVGAAnimationController(vsync: this);
      
      // 解析SVGA文件
      final videoItem = await SVGAParser.shared.decodeFromURL(testUrl);
      
      if (mounted) {
        setState(() {
          controller!.videoItem = videoItem;
          statusText = 'SVGA加载成功，准备播放';
          isLoading = false;
        });
        
                 _addLog('SVGA加载成功', LogLevel.success);
         _addLog('视频信息: ${videoItem.params.frames}帧, ${videoItem.params.fps}fps, 尺寸: ${videoItem.params.viewBoxWidth}x${videoItem.params.viewBoxHeight}', LogLevel.info);
         _addLog('图片资源数量: ${videoItem.bitmapCache.length}', LogLevel.info);
         _addLog('精灵数量: ${videoItem.sprites.length}', LogLevel.info);
         
         // 显示缓存状态
         final cacheStats = SVGAParser.getCacheStats();
         _addLog('缓存状态: ${cacheStats}', LogLevel.info);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          statusText = '加载失败: $e';
          isLoading = false;
          lastError = e.toString();
          errorCount++;
        });
        
        _addLog('SVGA加载失败: $e', LogLevel.error);
      }
    }
  }

  Future<void> _playSingle() async {
    if (controller?.videoItem == null) {
      _addLog('请先加载SVGA文件', LogLevel.warning);
      return;
    }
    
    try {
      setState(() {
        statusText = '播放中... (第${playCount + 1}次)';
      });
      
             _addLog('开始播放 (第${playCount + 1}次)', LogLevel.info);
       
       // 检查播放前的图片状态
       final videoItem = controller!.videoItem!;
       _addLog('播放前检查: bitmapCache中有${videoItem.bitmapCache.length}个图片', LogLevel.info);
       
       // 检查图片是否有效
       int validImageCount = 0;
       int invalidImageCount = 0;
       for (var entry in videoItem.bitmapCache.entries) {
         try {
           final width = entry.value.width;
           final height = entry.value.height;
           if (width > 0 && height > 0) {
             validImageCount++;
           } else {
             invalidImageCount++;
           }
         } catch (e) {
           invalidImageCount++;
           _addLog('发现无效图片: ${entry.key} - $e', LogLevel.warning);
         }
       }
       _addLog('图片状态检查: $validImageCount个有效, $invalidImageCount个无效', LogLevel.info);
       
       // 重置到开始位置
       controller!.reset();
       
       // 开始播放
       await controller!.forward();
      
      setState(() {
        playCount++;
        statusText = '播放完成 (总计${playCount}次)';
      });
      
      _addLog('播放完成 (第$playCount次)', LogLevel.success);
      
      // 如果开启了自动重复播放
      if (autoRepeat && playCount < targetPlayCount) {
        // 等待一小段时间再播放下一次
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted && autoRepeat) {
          _playSingle();
        }
      }
      
    } catch (e) {
      setState(() {
        statusText = '播放出错: $e';
        lastError = e.toString();
        errorCount++;
      });
      
      _addLog('播放出错: $e', LogLevel.error);
    }
  }

  void _toggleAutoRepeat() {
    setState(() {
      autoRepeat = !autoRepeat;
    });
    
    if (autoRepeat) {
      _addLog('开启自动重复播放模式 (目标次数: $targetPlayCount)', LogLevel.info);
      _playSingle();
    } else {
      _addLog('关闭自动重复播放模式', LogLevel.info);
    }
  }

  void _resetTest() {
    setState(() {
      playCount = 0;
      errorCount = 0;
      lastError = null;
      statusText = '测试已重置';
      autoRepeat = false;
    });
    
    _addLog('测试状态已重置', LogLevel.info);
    
    // 重新加载SVGA
    _loadSVGA();
  }

  void _clearLogs() {
    setState(() {
      logs.clear();
    });
  }

  void _checkStatus() {
    if (controller?.videoItem == null) return;
    
    final videoItem = controller!.videoItem!;
    
    _addLog('=== 当前状态检查 ===', LogLevel.info);
    _addLog('控制器状态: isAnimating=${controller!.isAnimating}, value=${controller!.value.toStringAsFixed(3)}', LogLevel.info);
    _addLog('autorelease: ${videoItem.autorelease}', LogLevel.info);
    
    // 检查图片缓存状态
    _addLog('bitmapCache: ${videoItem.bitmapCache.length}个图片', LogLevel.info);
    int validImages = 0;
    int invalidImages = 0;
    
    for (var entry in videoItem.bitmapCache.entries) {
      try {
        final width = entry.value.width;
        final height = entry.value.height;
        if (width > 0 && height > 0) {
          validImages++;
          _addLog('  ✓ ${entry.key}: ${width}x${height}', LogLevel.success);
        } else {
          invalidImages++;
          _addLog('  ✗ ${entry.key}: 尺寸无效 (${width}x${height})', LogLevel.error);
        }
      } catch (e) {
        invalidImages++;
        _addLog('  ✗ ${entry.key}: 访问失败 - $e', LogLevel.error);
      }
    }
    
    _addLog('图片状态汇总: $validImages个有效, $invalidImages个无效', LogLevel.info);
    
    // 检查动态图片
    final dynamicImages = videoItem.dynamicItem.dynamicImages;
    _addLog('动态图片: ${dynamicImages.length}个', LogLevel.info);
    
    // 检查全局缓存状态
    final cacheStats = SVGAParser.getCacheStats();
    _addLog('全局缓存: $cacheStats', LogLevel.info);
    
    _addLog('=== 检查完成 ===', LogLevel.info);
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '测试控制',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // 状态显示
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(child: Text(statusText)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text('播放次数: $playCount', style: TextStyle(color: Colors.green)),
                      SizedBox(width: 16),
                      Text('错误次数: $errorCount', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  if (lastError != null) ...[
                    SizedBox(height: 8),
                    Text(
                      '最后错误: $lastError',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // 控制按钮
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _loadSVGA,
                  icon: isLoading 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.download),
                  label: Text(isLoading ? '加载中...' : '加载SVGA'),
                ),
                ElevatedButton.icon(
                  onPressed: (controller?.videoItem == null || isLoading || autoRepeat) 
                    ? null 
                    : _playSingle,
                  icon: Icon(Icons.play_arrow),
                  label: Text('单次播放'),
                ),
                ElevatedButton.icon(
                  onPressed: (controller?.videoItem == null || isLoading) 
                    ? null 
                    : _toggleAutoRepeat,
                  icon: Icon(autoRepeat ? Icons.stop : Icons.repeat),
                  label: Text(autoRepeat ? '停止自动播放' : '自动重复播放'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: autoRepeat ? Colors.red : null,
                  ),
                ),
                                 OutlinedButton.icon(
                   onPressed: _resetTest,
                   icon: Icon(Icons.refresh),
                   label: Text('重置测试'),
                 ),
                 OutlinedButton.icon(
                   onPressed: (controller?.videoItem == null) ? null : _checkStatus,
                   icon: Icon(Icons.info),
                   label: Text('检查状态'),
                 ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 自动重复设置
            Row(
              children: [
                Text('目标播放次数: '),
                DropdownButton<int>(
                  value: targetPlayCount,
                  items: [5, 10, 20, 50, 100].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count次'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      targetPlayCount = value!;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SVGA预览',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: controller?.videoItem != null
                ? SVGAImage(controller!)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.movie_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('请先加载SVGA文件', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogs() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '执行日志 (${logs.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: logs.isEmpty ? null : _clearLogs,
                  icon: Icon(Icons.clear_all, size: 16),
                  label: Text('清空'),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: logs.isEmpty
                ? Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                              '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                              '${log.timestamp.second.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: log.level.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.level.name.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('重复播放测试'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('测试说明'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('此测试用于复现和调试重复播放SVGA时出现的问题：'),
                      SizedBox(height: 8),
                      Text('• 第一次播放通常成功'),
                      Text('• 第二次播放可能出现 drawBitmap 错误'),
                      Text('• 错误信息: "Failed assertion: line 6358"'),
                      SizedBox(height: 8),
                      Text('测试URL:'),
                      Text(
                        testUrl,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('确定'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildControlPanel(),
            SizedBox(height: 16),
            _buildPreview(),
            SizedBox(height: 16),
            _buildLogs(),
          ],
        ),
      ),
    );
  }
}

// 日志条目类
class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });
}

// 日志级别枚举
enum LogLevel { info, success, warning, error }

extension LogLevelExtension on LogLevel {
  Color get color {
    switch (this) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.success:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  String get name {
    switch (this) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.success:
        return 'SUCCESS';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
    }
  }
} 