import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class NetworkTestScreen extends StatefulWidget {
  @override
  _NetworkTestScreenState createState() => _NetworkTestScreenState();
}

class _NetworkTestScreenState extends State<NetworkTestScreen> {
  
  final List<String> networkUrls = [
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/TwitterHeart.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Walkthrough.svga",
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('网络加载测试'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.teal.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.cloud_download, color: Colors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '测试从网络加载SVGA文件的功能和性能',
                    style: TextStyle(color: Colors.teal[700]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: networkUrls.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(Icons.cloud, color: Colors.teal),
                    title: Text(networkUrls[index].split('/').last),
                    subtitle: Text(
                      networkUrls[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(Icons.play_arrow),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NetworkSampleScreen(
                            url: networkUrls[index],
                          ),
                        ),
                      );
                    },
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

class NetworkSampleScreen extends StatefulWidget {
  final String url;
  
  const NetworkSampleScreen({Key? key, required this.url}) : super(key: key);
  
  @override
  _NetworkSampleScreenState createState() => _NetworkSampleScreenState();
}

class _NetworkSampleScreenState extends State<NetworkSampleScreen>
    with SingleTickerProviderStateMixin {
  
  SVGAAnimationController? controller;
  bool isLoading = true;
  String? error;
  DateTime? startTime;
  DateTime? endTime;
  
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
    setState(() {
      isLoading = true;
      error = null;
      startTime = DateTime.now();
    });
    
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(widget.url);
      endTime = DateTime.now();
      
      controller?.videoItem = videoItem;
      setState(() {
        isLoading = false;
      });
      
      controller?.repeat();
    } catch (e) {
      endTime = DateTime.now();
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final loadTime = startTime != null && endTime != null
        ? endTime!.difference(startTime!).inMilliseconds
        : null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('网络SVGA'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAnimation,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'URL: ${widget.url}',
                  style: TextStyle(fontSize: 12),
                ),
                if (loadTime != null) ...[
                  SizedBox(height: 4),
                  Text(
                    '加载时间: ${loadTime}ms',
                    style: TextStyle(
                      fontSize: 12,
                      color: error != null ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在从网络加载...'),
                      ],
                    ),
                  )
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            SizedBox(height: 16),
                            Text(
                              '加载失败',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: SVGAImage(
                          controller!,
                          fit: BoxFit.contain,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
} 