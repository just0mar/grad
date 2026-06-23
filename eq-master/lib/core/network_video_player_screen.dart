import 'package:flutter/material.dart';
import 'app_video_player.dart';

class NetworkVideoPlayerScreen extends StatelessWidget {
  final String title;
  final String url;
  final Map<String, String>? headers;

  const NetworkVideoPlayerScreen({
    super.key,
    required this.title,
    required this.url,
    this.headers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'SFPro', fontSize: 16),
        ),
      ),
      body: Center(
        child: AppVideoPlayer(
          url: url,
          autoPlay: true,
          showControls: true,
        ),
      ),
    );
  }
}
