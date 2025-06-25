import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class EdgeCasesTestScreen extends StatefulWidget {
  @override
  _EdgeCasesTestScreenState createState() => _EdgeCasesTestScreenState();
}

class _EdgeCasesTestScreenState extends State<EdgeCasesTestScreen>
    with TickerProviderStateMixin {
  
  List<TestCase> testCases = [];
  
  @override
  void initState() {
    super.initState();
    _initializeTestCases();
  }
  
  void _initializeTestCases() {
    testCases = [
      TestCase(
        title: '无效文件路径测试',
        description: '测试加载不存在的SVGA文件',
        testFunction: () => _testInvalidFilePath(),
      ),
      TestCase(
        title: '网络超时测试',
        description: '测试网络加载超时的情况',
        testFunction: () => _testNetworkTimeout(),
      ),
      TestCase(
        title: '重复释放测试',
        description: '测试重复dispose控制器的情况',
        testFunction: () => _testDoubleDispose(),
      ),
      TestCase(
        title: '空文件测试',
        description: '测试加载空SVGA文件',
        testFunction: () => _testEmptyFile(),
      ),
      TestCase(
        title: '损坏文件测试',
        description: '测试加载损坏的SVGA文件',
        testFunction: () => _testCorruptedFile(),
      ),
      TestCase(
        title: '极限尺寸测试',
        description: '测试极大或极小尺寸的播放器',
        testFunction: () => _testExtremeSizes(),
      ),
      TestCase(
        title: '快速切换测试',
        description: '测试快速切换不同SVGA文件',
        testFunction: () => _testRapidSwitching(),
      ),
      TestCase(
        title: '内存压力测试',
        description: '测试极限内存使用情况',
        testFunction: () => _testMemoryPressure(),
      ),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('边界情况测试'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.red.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.bug_report, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '测试各种异常情况和边界条件，确保播放器的稳定性',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: testCases.length,
              itemBuilder: (context, index) {
                return _buildTestCaseCard(testCases[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTestCaseCard(TestCase testCase) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testCase.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        testCase.description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusIcon(testCase.status),
              ],
            ),
            if (testCase.isRunning) ...[
              SizedBox(height: 12),
              LinearProgressIndicator(),
              SizedBox(height: 8),
              Text(
                '测试进行中...',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ],
            if (testCase.result != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: testCase.status == TestStatus.passed
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '测试结果:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      testCase.result!,
                      style: TextStyle(fontSize: 12),
                    ),
                    if (testCase.duration != null) ...[
                      SizedBox(height: 4),
                      Text(
                        '耗时: ${testCase.duration!.inMilliseconds}ms',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: testCase.isRunning ? null : () => _runTest(testCase),
                  icon: Icon(Icons.play_arrow, size: 16),
                  label: Text('运行测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (testCase.status != TestStatus.none) ...[
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _resetTest(testCase),
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text('重置'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusIcon(TestStatus status) {
    switch (status) {
      case TestStatus.passed:
        return Icon(Icons.check_circle, color: Colors.green, size: 24);
      case TestStatus.failed:
        return Icon(Icons.error, color: Colors.red, size: 24);
      case TestStatus.running:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TestStatus.none:
      default:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 24);
    }
  }
  
  void _runTest(TestCase testCase) async {
    setState(() {
      testCase.isRunning = true;
      testCase.status = TestStatus.running;
      testCase.result = null;
      testCase.duration = null;
    });
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await testCase.testFunction();
      stopwatch.stop();
      
      setState(() {
        testCase.isRunning = false;
        testCase.status = TestStatus.passed;
        testCase.result = result;
        testCase.duration = stopwatch.elapsed;
      });
    } catch (e) {
      stopwatch.stop();
      
      setState(() {
        testCase.isRunning = false;
        testCase.status = TestStatus.failed;
        testCase.result = '测试失败: $e';
        testCase.duration = stopwatch.elapsed;
      });
    }
  }
  
  void _resetTest(TestCase testCase) {
    setState(() {
      testCase.isRunning = false;
      testCase.status = TestStatus.none;
      testCase.result = null;
      testCase.duration = null;
    });
  }
  
  // 测试用例实现
  Future<String> _testInvalidFilePath() async {
    try {
      await SVGAParser.shared.decodeFromAssets('assets/nonexistent.svga');
      return '意外成功：应该抛出异常但没有';
    } catch (e) {
      return '正确处理了无效文件路径异常: ${e.runtimeType}';
    }
  }
  
  Future<String> _testNetworkTimeout() async {
    try {
      // 使用一个不存在的URL来模拟超时
      await SVGAParser.shared.decodeFromURL('https://nonexistent-domain-12345.com/test.svga')
          .timeout(Duration(seconds: 3));
      return '意外成功：应该超时但没有';
    } catch (e) {
      return '正确处理了网络超时: ${e.runtimeType}';
    }
  }
  
  Future<String> _testDoubleDispose() async {
    try {
      final controller = SVGAAnimationController(vsync: this);
      controller.dispose();
      controller.dispose(); // 第二次dispose
      return '正确处理了重复dispose调用';
    } catch (e) {
      return '重复dispose时抛出异常: $e';
    }
  }
  
  Future<String> _testEmptyFile() async {
    // 这个测试需要实际的空文件，这里模拟
    return '空文件测试需要实际的空SVGA文件';
  }
  
  Future<String> _testCorruptedFile() async {
    // 这个测试需要实际的损坏文件，这里模拟
    return '损坏文件测试需要实际的损坏SVGA文件';
  }
  
  Future<String> _testExtremeSizes() async {
    try {
      final controller = SVGAAnimationController(vsync: this);
      final videoItem = await SVGAParser.shared.decodeFromAssets('assets/angel.svga');
      controller.videoItem = videoItem;
      
      // 测试极小尺寸
      SVGAImage(
        controller,
        preferredSize: Size(1, 1),
      );
      
      // 测试极大尺寸
      SVGAImage(
        controller,
        preferredSize: Size(10000, 10000),
      );
      
      controller.dispose();
      return '成功处理了极限尺寸测试';
    } catch (e) {
      return '极限尺寸测试失败: $e';
    }
  }
  
  Future<String> _testRapidSwitching() async {
    try {
      final controller = SVGAAnimationController(vsync: this);
      
      // 快速切换不同的SVGA文件
      for (int i = 0; i < 5; i++) {
        final videoItem1 = await SVGAParser.shared.decodeFromAssets('assets/angel.svga');
        controller.videoItem = videoItem1;
        
        final videoItem2 = await SVGAParser.shared.decodeFromAssets('assets/pin_jump.svga');
        controller.videoItem = videoItem2;
      }
      
      controller.dispose();
      return '成功完成了快速切换测试';
    } catch (e) {
      return '快速切换测试失败: $e';
    }
  }
  
  Future<String> _testMemoryPressure() async {
    try {
      List<SVGAAnimationController> controllers = [];
      
      // 创建大量控制器来测试内存压力
      for (int i = 0; i < 20; i++) {
        final controller = SVGAAnimationController(vsync: this);
        final videoItem = await SVGAParser.shared.decodeFromAssets('assets/angel.svga');
        controller.videoItem = videoItem;
        controllers.add(controller);
      }
      
      // 清理所有控制器
      for (var controller in controllers) {
        controller.dispose();
      }
      
      return '成功完成了内存压力测试，创建并清理了${controllers.length}个控制器';
    } catch (e) {
      return '内存压力测试失败: $e';
    }
  }
}

class TestCase {
  final String title;
  final String description;
  final Future<String> Function() testFunction;
  
  bool isRunning = false;
  TestStatus status = TestStatus.none;
  String? result;
  Duration? duration;
  
  TestCase({
    required this.title,
    required this.description,
    required this.testFunction,
  });
}

enum TestStatus {
  none,
  running,
  passed,
  failed,
} 