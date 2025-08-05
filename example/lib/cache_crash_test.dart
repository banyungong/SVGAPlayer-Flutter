import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

/// 缓存崩溃测试页面
/// 专门测试多个组件同时播放时的JNI异常修复
class CacheCrashTestScreen extends StatefulWidget {
  @override
  _CacheCrashTestScreenState createState() => _CacheCrashTestScreenState();
}

class _CacheCrashTestScreenState extends State<CacheCrashTestScreen>
    with TickerProviderStateMixin {
  
  // 测试状态
  bool isRunning = false;
  String statusText = '准备测试缓存清理JNI异常修复';
  int testRound = 0;
  int successfulRounds = 0;
  int failedRounds = 0;
  
  // 播放器实例
  final List<SVGAAnimationController> controllers = [];
  final List<bool> playingStates = [];
  
  // 测试配置
  final String testUrl = 'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/rose.svga';
  int playerCount = 3;
  
  // 日志
  final List<String> logs = [];
  Timer? testTimer;
  
  @override
  void initState() {
    super.initState();
    _addLog('缓存崩溃测试初始化完成');
    _addLog('目标：测试多实例播放+缓存清理的JNI异常修复');
  }
  
  @override
  void dispose() {
    testTimer?.cancel();
    _cleanupControllers();
    super.dispose();
  }
  
  void _cleanupControllers() {
    for (final controller in controllers) {
      try {
        controller.dispose();
      } catch (e) {
        _addLog('清理控制器失败: $e');
      }
    }
    controllers.clear();
    playingStates.clear();
  }
  
  /// 开始自动化测试
  void _startAutomaticTest() {
    if (isRunning) {
      _stopTest();
      return;
    }
    
    setState(() {
      isRunning = true;
      statusText = '开始自动化测试...';
      testRound = 0;
      successfulRounds = 0;
      failedRounds = 0;
    });
    
    _addLog('🚀 开始自动化JNI异常测试');
    
    // 每3秒执行一轮测试
    testTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted || !isRunning) {
        timer.cancel();
        return;
      }
      
      _runSingleTestRound();
    });
  }
  
  /// 执行单轮测试
  void _runSingleTestRound() async {
    testRound++;
    _addLog('--- 第 $testRound 轮测试开始 ---');
    
    try {
      // 步骤1：创建多个播放器实例
      await _createMultiplePlayers();
      
      // 步骤2：等待一段时间让它们播放
      await Future.delayed(Duration(milliseconds: 500));
      
      // 步骤3：强制清理缓存（这是最容易触发JNI异常的操作）
      _forceClearCache();
      
      // 步骤4：再等待一段时间观察是否有异常
      await Future.delayed(Duration(milliseconds: 500));
      
      // 步骤5：清理当前实例，准备下一轮
      _cleanupControllers();
      
      // 如果没有异常，记录成功
      successfulRounds++;
      _addLog('✅ 第 $testRound 轮测试成功');
      
      setState(() {
        statusText = '测试进行中... 成功:$successfulRounds 失败:$failedRounds';
      });
      
    } catch (e) {
      failedRounds++;
      _addLog('❌ 第 $testRound 轮测试失败: $e');
      
      // 检查是否是JNI异常
      if (e.toString().contains('CheckException') || 
          e.toString().contains('jni') ||
          e.toString().contains('native')) {
        _addLog('🎯 检测到JNI异常！修复可能未完全生效');
      }
      
      setState(() {
        statusText = 'JNI异常已检测到！成功:$successfulRounds 失败:$failedRounds';
      });
    }
  }
  
  /// 创建多个播放器实例
  Future<void> _createMultiplePlayers() async {
    _addLog('创建 $playerCount 个播放器实例');
    
    for (int i = 0; i < playerCount; i++) {
      try {
        final controller = SVGAAnimationController(vsync: this);
        
        // 加载SVGA资源（使用共享模式，更容易触发问题）
        final movieEntity = await SVGAParser.shared.decodeFromURL(testUrl);
        
        controller.videoItem = movieEntity;
        controller.repeat();
        
        controllers.add(controller);
        playingStates.add(true);
        
        _addLog('播放器 #$i 创建成功');
        
      } catch (e) {
        _addLog('播放器 #$i 创建失败: $e');
        playingStates.add(false);
        rethrow;
      }
    }
  }
  
  /// 强制清理缓存
  void _forceClearCache() {
    _addLog('⚠️ 强制清理缓存（在有活跃播放器的情况下）');
    
    try {
      // 显示清理前的缓存状态
      final beforeStats = SVGAParser.getCacheStats();
      _addLog('清理前: ${beforeStats['svga_cache']['count']}个文件');
      
      // 执行清理
      SVGAParser.clearCache();
      
      // 显示清理后的状态
      final afterStats = SVGAParser.getCacheStats();
      _addLog('清理后: ${afterStats['svga_cache']['count']}个文件');
      
      _addLog('✅ 缓存清理完成，未发生异常');
      
    } catch (e) {
      _addLog('❌ 缓存清理时发生异常: $e');
      rethrow;
    }
  }
  
  void _stopTest() {
    testTimer?.cancel();
    setState(() {
      isRunning = false;
      statusText = '测试已停止';
    });
    _addLog('测试已手动停止');
  }
  
  void _clearLogs() {
    setState(() {
      logs.clear();
    });
  }
  
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    final logMessage = '[$timestamp] $message';
    
    setState(() {
      logs.add(logMessage);
      if (logs.length > 100) {
        logs.removeAt(0);
      }
    });
    
    if (kDebugMode) {
      print('CacheCrashTest: $logMessage');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('缓存崩溃测试'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          // 状态面板
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '状态: $statusText',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('轮次: $testRound', style: TextStyle(color: Colors.blue)),
                    ),
                    Expanded(
                      child: Text('成功: $successfulRounds', style: TextStyle(color: Colors.green)),
                    ),
                    Expanded(
                      child: Text('失败: $failedRounds', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('当前播放器: ${controllers.length}个'),
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
                        onPressed: _startAutomaticTest,
                        child: Text(isRunning ? '停止测试' : '开始自动测试'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRunning ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isRunning ? null : () => _runSingleTestRound(),
                        child: Text('单次测试'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Text('播放器数量: '),
                    Expanded(
                      child: Slider(
                        value: playerCount.toDouble(),
                        min: 2,
                        max: 8,
                        divisions: 6,
                        label: playerCount.toString(),
                        onChanged: isRunning ? null : (value) {
                          setState(() {
                            playerCount = value.toInt();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 说明文本
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Colors.orange[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('测试说明:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                    SizedBox(height: 4),
                    Text('• 创建多个播放器同时播放同一SVGA资源', style: TextStyle(fontSize: 12)),
                    Text('• 在播放过程中强制清理缓存', style: TextStyle(fontSize: 12)), 
                    Text('• 监控是否出现JNI异常崩溃', style: TextStyle(fontSize: 12, color: Colors.red)),
                    Text('• 如果修复生效，应该不会崩溃', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ),
            ),
          ),
          
          // 日志面板
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text('测试日志', style: TextStyle(fontWeight: FontWeight.bold)),
                        Spacer(),
                        TextButton(
                          onPressed: _clearLogs,
                          child: Text('清空'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        Color textColor = Colors.black;
                        
                        if (log.contains('✅')) textColor = Colors.green;
                        else if (log.contains('❌') || log.contains('异常')) textColor = Colors.red;
                        else if (log.contains('⚠️')) textColor = Colors.orange;
                        else if (log.contains('🎯')) textColor = Colors.purple;
                        
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: textColor,
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
    );
  }
}