import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class BusinessScenarioTestScreen extends StatefulWidget {
  @override
  _BusinessScenarioTestScreenState createState() => _BusinessScenarioTestScreenState();
}

class _BusinessScenarioTestScreenState extends State<BusinessScenarioTestScreen>
    with TickerProviderStateMixin {
  
  // 测试状态
  bool isLoading = false;
  String statusText = '等待开始测试';
  int totalAnimations = 0;
  int successCount = 0;
  int errorCount = 0;
  String? lastError;
  
  // 文件管理
  File? downloadedFile;
  String? filePath;
  
  // 测试配置
  final String testUrl = 'https://reosurce-preview.hokilive.net/app-animation/moment_crazy_like1.svga';
  bool autoMode = false;
  int batchSize = 3; // 一次创建多少个动画
  Duration animationDuration = Duration(milliseconds: 1000);
  
  // 活跃的Overlay条目追踪
  final List<OverlayEntry> activeOverlays = [];
  final List<AnimationInstance> animationInstances = [];
  
  // 日志
  final List<LogEntry> logs = [];
  
  @override
  void initState() {
    super.initState();
    _addLog('初始化业务场景测试', LogLevel.info);
    _addLog('模拟场景: Overlay叠加 + 多实例并发 + 快速创建销毁', LogLevel.info);
  }

  @override
  void dispose() {
    // 清理所有活跃的overlay
    _clearAllOverlays();
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

  /// 模拟SmartAnimationResourceManager的下载逻辑
  Future<File?> _downloadAnimationFile(String url) async {
    try {
      _addLog('开始下载SVGA文件: $url', LogLevel.info);
      
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last.split('?').first;
      final file = File('${tempDir.path}/svga_cache/$fileName');
      
      // 检查文件是否已存在
      if (await file.exists()) {
        _addLog('发现缓存文件，直接使用: ${file.path}', LogLevel.info);
        return file;
      }
      
      // 创建目录
      await file.parent.create(recursive: true);
      
      // 下载文件
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        _addLog('文件下载完成: ${file.path} (${response.bodyBytes.length} bytes)', LogLevel.success);
        return file;
      } else {
        _addLog('下载失败: HTTP ${response.statusCode}', LogLevel.error);
        return null;
      }
    } catch (e) {
      _addLog('下载异常: $e', LogLevel.error);
      return null;
    }
  }

  /// 预加载SVGA文件
  Future<void> _preloadSVGAFile() async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
      statusText = '正在预加载SVGA文件...';
      lastError = null;
    });
    
    try {
      // Step 1: 下载文件
      downloadedFile = await _downloadAnimationFile(testUrl);
      
      if (downloadedFile == null || !downloadedFile!.existsSync()) {
        throw Exception('SVGA文件下载失败');
      }
      
      filePath = downloadedFile!.path;
      _addLog('文件预加载完成: ${filePath}', LogLevel.success);
      
      setState(() {
        statusText = 'SVGA文件已预加载，可以开始测试';
        isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        statusText = '预加载失败: $e';
        isLoading = false;
        lastError = e.toString();
        errorCount++;
      });
      
      _addLog('预加载失败: $e', LogLevel.error);
    }
  }

  /// 模拟业务中的addAnimation方法
  Future<void> _addAnimation(BuildContext context, String momentCrazyLikePath, {int instanceId = 0}) async {
    final animationId = DateTime.now().millisecondsSinceEpoch + instanceId;
    
    try {
      _addLog('创建动画实例 #$animationId', LogLevel.info);
      
      final overlay = Overlay.of(context);
      
      // 随机位置，模拟多个动画的叠加效果
      final random = Random();
      final rightOffset = random.nextDouble() * 100;
      final bottomOffset = 70 + random.nextDouble() * 100;
      
      OverlayEntry entry = OverlayEntry(
        builder: (context) => PositionedDirectional(
          end: rightOffset,
          bottom: bottomOffset,
          child: SizedBox(
            width: 280,
            height: 280,
            child: Transform.scale(
              scaleX: random.nextBool() ? 1 : -1, // 随机镜像翻转
              child: SvgaPlayerWidget(
                url: momentCrazyLikePath,
                useAssets: false, // 使用网络加载
                onCompleted: () {
                  _addLog('动画实例 #$animationId 播放完成', LogLevel.success);
                  setState(() {
                    successCount++;
                  });
                },
                onError: (error) {
                  _addLog('动画实例 #$animationId 播放出错: $error', LogLevel.error);
                  setState(() {
                    errorCount++;
                    lastError = error.toString();
                  });
                },
              ),
            ),
          ),
        ),
      );
      
      // 记录实例
      final instance = AnimationInstance(
        id: animationId,
        entry: entry,
        createdAt: DateTime.now(),
      );
      
      setState(() {
        activeOverlays.add(entry);
        animationInstances.add(instance);
        totalAnimations++;
      });
      
      // 插入overlay
      overlay.insert(entry);
      _addLog('动画实例 #$animationId 已插入Overlay', LogLevel.info);
      
      // 等待指定时间后移除
      await Future.delayed(animationDuration);
      
      // 移除overlay
      try {
        entry.remove();
        setState(() {
          activeOverlays.remove(entry);
          animationInstances.removeWhere((instance) => instance.id == animationId);
        });
        _addLog('动画实例 #$animationId 已移除', LogLevel.info);
      } catch (e) {
        _addLog('移除动画实例 #$animationId 失败: $e', LogLevel.warning);
      }
      
    } catch (e) {
      _addLog('创建动画实例 #$animationId 失败: $e', LogLevel.error);
      setState(() {
        errorCount++;
        lastError = e.toString();
      });
    }
  }

  /// 批量创建动画（模拟快速点击或触发）
  Future<void> _createBatchAnimations() async {
    if (downloadedFile == null) {
      _addLog('请先预加载SVGA文件', LogLevel.warning);
      return;
    }
    
    _addLog('开始批量创建 $batchSize 个动画实例', LogLevel.info);
    
    // 同时创建多个动画实例
    final List<Future> futures = [];
    for (int i = 0; i < batchSize; i++) {
      futures.add(_addAnimation(context, testUrl, instanceId: i));
    }
    
    // 等待所有动画完成
    await Future.wait(futures);
    _addLog('批量动画创建完成', LogLevel.success);
  }

  /// 自动测试模式
  void _toggleAutoMode() {
    setState(() {
      autoMode = !autoMode;
    });
    
    if (autoMode) {
      _addLog('开启自动测试模式', LogLevel.info);
      _runAutoTest();
    } else {
      _addLog('关闭自动测试模式', LogLevel.info);
    }
  }

  /// 自动测试循环
  void _runAutoTest() async {
    if (!autoMode || downloadedFile == null) return;
    
    await _createBatchAnimations();
    
    // 等待一段时间再创建下一批
    if (autoMode) {
      await Future.delayed(Duration(milliseconds: 1500));
      if (mounted && autoMode) {
        _runAutoTest();
      }
    }
  }

  /// 清理所有Overlay
  void _clearAllOverlays() {
    _addLog('清理所有活跃的Overlay (${activeOverlays.length}个)', LogLevel.info);
    
    for (final entry in activeOverlays) {
      try {
        entry.remove();
      } catch (e) {
        _addLog('移除Overlay失败: $e', LogLevel.warning);
      }
    }
    
    setState(() {
      activeOverlays.clear();
      animationInstances.clear();
    });
  }

  /// 重置测试
  void _resetTest() {
    _clearAllOverlays();
    
    setState(() {
      totalAnimations = 0;
      successCount = 0;
      errorCount = 0;
      lastError = null;
      statusText = '测试已重置';
      autoMode = false;
    });
    
    _addLog('测试状态已重置', LogLevel.info);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('业务场景重现测试'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 控制面板
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('业务场景测试控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('模拟: Overlay叠加 + 多实例并发 + 快速创建销毁', style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 16),
                    
                    // 状态显示
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statusText),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text('总创建: $totalAnimations', style: TextStyle(color: Colors.blue)),
                              SizedBox(width: 12),
                              Text('成功: $successCount', style: TextStyle(color: Colors.green)),
                              SizedBox(width: 12),
                              Text('错误: $errorCount', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                          Text('活跃实例: ${activeOverlays.length}'),
                          if (lastError != null) 
                            Text('错误: $lastError', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 按钮
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: isLoading ? null : _preloadSVGAFile,
                          child: Text(isLoading ? '下载中...' : '预加载SVGA'),
                        ),
                        ElevatedButton(
                          onPressed: downloadedFile == null ? null : _createBatchAnimations,
                          child: Text('创建$batchSize个动画'),
                        ),
                        ElevatedButton(
                          onPressed: downloadedFile == null ? null : _toggleAutoMode,
                          child: Text(autoMode ? '停止自动' : '自动测试'),
                        ),
                        OutlinedButton(
                          onPressed: _resetTest,
                          child: Text('重置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // 日志
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('执行日志', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: logs.isEmpty
                        ? Center(child: Text('暂无日志', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                child: Text(
                                  '[${log.level.name}] ${log.message}',
                                  style: TextStyle(
                                    color: log.level.color,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 动画实例类
class AnimationInstance {
  final int id;
  final OverlayEntry entry;
  final DateTime createdAt;

  AnimationInstance({
    required this.id,
    required this.entry,
    required this.createdAt,
  });
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

// SvgaPlayerWidget 组件（模拟您的业务组件）
class SvgaPlayerWidget extends StatefulWidget {
  final String url;
  final bool useAssets;
  final VoidCallback? onCompleted;
  final Function(dynamic)? onError;

  const SvgaPlayerWidget({
    Key? key,
    required this.url,
    this.useAssets = false,
    this.onCompleted,
    this.onError,
  }) : super(key: key);

  @override
  _SvgaPlayerWidgetState createState() => _SvgaPlayerWidgetState();
}

class _SvgaPlayerWidgetState extends State<SvgaPlayerWidget>
    with TickerProviderStateMixin {
  SVGAAnimationController? controller;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAndPlay();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    try {
      // 模拟您的业务加载方式
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last.split('?').first;
      final file = File('${tempDir.path}/svga_cache/$fileName');
      
      if (!await file.exists()) {
        throw Exception('SVGA文件不存在，请先预加载');
      }
      
      // 读取字节并解析 - 这里是关键！
      final bytes = await file.readAsBytes();
      final videoItem = await SVGAParser.shared.decodeFromBuffer(bytes);
      
      if (mounted) {
        controller = SVGAAnimationController(vsync: this);
        controller!.videoItem = videoItem;
        
        setState(() {
          isLoading = false;
        });
        
        // 开始播放
        await controller!.forward();
        
        // 播放完成回调
        widget.onCompleted?.call();
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = e.toString();
        });
        
        widget.onError?.call(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (error != null) {
      return Center(
        child: Icon(
          Icons.error,
          color: Colors.red,
          size: 48,
        ),
      );
    }
    
    if (controller?.videoItem == null) {
      return Center(
        child: Icon(
          Icons.movie_filter,
          color: Colors.grey,
          size: 48,
        ),
      );
    }
    
    return SVGAImage(controller!);
  }
} 