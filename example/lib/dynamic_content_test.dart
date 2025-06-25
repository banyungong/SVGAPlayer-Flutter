import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class DynamicContentTestScreen extends StatefulWidget {
  @override
  _DynamicContentTestScreenState createState() => _DynamicContentTestScreenState();
}

class _DynamicContentTestScreenState extends State<DynamicContentTestScreen>
    with SingleTickerProviderStateMixin {
  
  SVGAAnimationController? controller;
  bool isLoading = true;
  String dynamicText = "Hello, World!";
  
  @override
  void initState() {
    super.initState();
    controller = SVGAAnimationController(vsync: this);
    _loadAnimation();
  }
  
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
  
  void _loadAnimation() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(
        'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/kingset.svga'
      );
      
      // 设置动态文本
      videoItem.dynamicItem.setText(
        TextPainter(
          text: TextSpan(
            text: dynamicText,
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        "banner",
      );
      
      controller?.videoItem = videoItem;
      setState(() {
        isLoading = false;
      });
      
      controller?.repeat();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('动态内容测试'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.purple.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.dynamic_form, color: Colors.purple),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '测试动态文本和图片替换功能',
                    style: TextStyle(color: Colors.purple[700]),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Expanded(
              child: Center(
                child: SVGAImage(
                  controller!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: '动态文本',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        dynamicText = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _updateDynamicContent,
                    child: Text('更新动态内容'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _updateDynamicContent() {
    final videoItem = controller?.videoItem;
    if (videoItem != null) {
      videoItem.dynamicItem.setText(
        TextPainter(
          text: TextSpan(
            text: dynamicText,
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        "banner",
      );
      
      controller?.reset();
      controller?.repeat();
    }
  }
} 