import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class BasicSampleScreen extends StatelessWidget {
  final samples = const <String>[
    "assets/angel.svga",
    "assets/pin_jump.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/TwitterHeart.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Walkthrough.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/kingset.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/halloween.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/heartbeat.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/matteBitmap.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/matteBitmap_1.x.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/matteRect.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/mutiMatte.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/posche.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/rose.svga",
  ].map((e) => [e.split('/').last, e]).toList(growable: false);

  // callback for register dynamicItem
  final dynamicSamples = <String, void Function(MovieEntity entity)>{
    "kingset.svga": (entity) => entity.dynamicItem
      ..setText(
          TextPainter(
              text: TextSpan(
                  text: "Hello, World!",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ))),
          "banner")
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('基础功能测试'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '测试各种SVGA文件的基本播放功能，包括本地资源和网络资源',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: samples.length,
              separatorBuilder: (_, __) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                final sample = samples[index];
                final isLocal = !sample.last.startsWith('http');
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isLocal ? Colors.green : Colors.orange,
                      child: Icon(
                        isLocal ? Icons.storage : Icons.cloud,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      sample.first,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sample.last,
                          style: TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLocal ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isLocal ? '本地' : '网络',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (dynamicSamples.containsKey(sample.first)) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '动态内容',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.play_arrow),
                    onTap: () => _goToSample(context, sample),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _goToSample(BuildContext context, List<String> sample) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return SVGASampleScreen(
        name: sample.first,
        image: sample.last,
        dynamicCallback: dynamicSamples[sample.first],
      );
    }));
  }
}

class SVGASampleScreen extends StatefulWidget {
  final String? name;
  final String image;
  final void Function(MovieEntity entity)? dynamicCallback;
  
  const SVGASampleScreen({
    Key? key,
    required this.image,
    this.name,
    this.dynamicCallback,
  }) : super(key: key);

  @override
  _SVGASampleScreenState createState() => _SVGASampleScreenState();
}

class _SVGASampleScreenState extends State<SVGASampleScreen>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? animationController;
  bool isLoading = true;
  String? errorMessage;
  DateTime? loadStartTime;
  DateTime? loadEndTime;
  
  // 播放控制选项
  Color backgroundColor = Colors.transparent;
  bool allowOverflow = true;
  FilterQuality filterQuality = kIsWeb ? FilterQuality.high : FilterQuality.low;
  BoxFit fit = BoxFit.contain;
  late double containerWidth;
  late double containerHeight;
  bool hideOptions = false;
  
  // 统计信息
  int playCount = 0;
  Duration? loadDuration;

  @override
  void initState() {
    super.initState();
    animationController = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    containerWidth = math.min(350, MediaQuery.of(context).size.width);
    containerHeight = math.min(350, MediaQuery.of(context).size.height);
  }

  @override
  void dispose() {
    animationController?.dispose();
    animationController = null;
    super.dispose();
  }

  void _loadAnimation() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      loadStartTime = DateTime.now();
    });

    try {
      final videoItem = await _loadVideoItem(widget.image);
      loadEndTime = DateTime.now();
      loadDuration = loadEndTime!.difference(loadStartTime!);
      
      if (widget.dynamicCallback != null) {
        widget.dynamicCallback!(videoItem);
      }
      
      if (mounted) {
        setState(() {
          isLoading = false;
          animationController?.videoItem = videoItem;
          _playAnimation();
        });
      }
    } catch (e) {
      loadEndTime = DateTime.now();
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  void _playAnimation() {
    if (animationController?.isCompleted == true) {
      animationController?.reset();
    }
    animationController?.repeat();
    setState(() {
      playCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name ?? "SVGA播放器"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAnimation,
            tooltip: '重新加载',
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          // 文件信息
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "文件: ${widget.image}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (loadDuration != null) ...[
                  SizedBox(height: 4),
                  Text(
                    "加载时间: ${loadDuration!.inMilliseconds}ms",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
                if (playCount > 0) ...[
                  SizedBox(height: 4),
                  Text(
                    "播放次数: $playCount",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 加载指示器
          if (isLoading) 
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载SVGA文件...'),
                ],
              ),
            ),
          
          // 错误信息
          if (errorMessage != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text(
                        '加载失败',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // SVGA播放器
          if (!isLoading && errorMessage == null)
            Center(
              child: ColoredBox(
                color: backgroundColor,
                child: SVGAImage(
                  animationController!,
                  fit: fit,
                  clearsAfterStop: false,
                  allowDrawingOverflow: allowOverflow,
                  filterQuality: filterQuality,
                  preferredSize: Size(containerWidth, containerHeight),
                ),
              ),
            ),
          
          // 控制选项
          if (!isLoading && errorMessage == null)
            Positioned(
              bottom: 10,
              left: 10,
              child: _buildOptions(context),
            ),
        ],
      ),
      
      // 播放控制按钮
      floatingActionButton: isLoading || 
          animationController?.videoItem == null ||
          errorMessage != null
          ? null
          : FloatingActionButton.extended(
              label: Text(animationController!.isAnimating ? "暂停" : "播放"),
              icon: Icon(animationController!.isAnimating
                  ? Icons.pause
                  : Icons.play_arrow),
              onPressed: () {
                if (animationController?.isAnimating == true) {
                  animationController?.stop();
                } else {
                  _playAnimation();
                }
                setState(() {});
              },
            ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 显示/隐藏选项按钮
          InkWell(
            onTap: () {
              setState(() {
                hideOptions = !hideOptions;
              });
            },
            child: Row(
              children: [
                Icon(
                  hideOptions ? Icons.expand_more : Icons.expand_less,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  hideOptions ? '显示选项' : '隐藏选项',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          
          // 帧信息
          if (!hideOptions) ...[
            SizedBox(height: 8),
            AnimatedBuilder(
              animation: animationController!,
              builder: (context, child) {
                return Text(
                  '当前帧: ${animationController!.currentFrame + 1}/${animationController!.frames}',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
            
            // 帧控制滑块
            AnimatedBuilder(
              animation: animationController!,
              builder: (context, child) {
                return Slider(
                  min: 0,
                  max: animationController!.frames.toDouble(),
                  value: animationController!.currentFrame.toDouble(),
                  onChanged: (v) {
                    if (animationController?.isAnimating == true) {
                      animationController?.stop();
                    }
                    animationController?.value = v / animationController!.frames;
                  },
                );
              },
            ),
            
            // 图片质量选择
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('图片质量', style: TextStyle(color: Colors.white, fontSize: 12)),
                DropdownButton<FilterQuality>(
                  value: filterQuality,
                  dropdownColor: Colors.grey[800],
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (FilterQuality? newValue) {
                    setState(() {
                      filterQuality = newValue!;
                    });
                  },
                  items: FilterQuality.values.map((FilterQuality value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value.toString().split('.').last),
                    );
                  }).toList(),
                ),
              ],
            ),
            
            // 允许溢出绘制
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('允许溢出绘制', style: TextStyle(color: Colors.white, fontSize: 12)),
                Switch(
                  value: allowOverflow,
                  onChanged: (v) {
                    setState(() {
                      allowOverflow = v;
                    });
                  },
                ),
              ],
            ),
            
            // 背景颜色选择
            Text('背景颜色:', style: TextStyle(color: Colors.white, fontSize: 12)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Colors.transparent,
                Colors.red,
                Colors.green,
                Colors.blue,
                Colors.yellow,
                Colors.black,
              ].map((color) => GestureDetector(
                onTap: () {
                  setState(() {
                    backgroundColor = color;
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: backgroundColor == color ? Colors.white : Colors.grey,
                      width: backgroundColor == color ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

Future _loadVideoItem(String image) {
  Future Function(String) decoder;
  if (image.startsWith(RegExp(r'https?://'))) {
    decoder = SVGAParser.shared.decodeFromURL;
  } else {
    decoder = SVGAParser.shared.decodeFromAssets;
  }
  return decoder(image);
} 