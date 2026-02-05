import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class LiveChatPage extends StatefulWidget {
  final String title;
  final String host;
  final String image;

  const LiveChatPage({
    super.key,
    required this.title,
    required this.host,
    required this.image,
  });

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  int _viewerCount = 132;
  int _heartCount = 0;
  late Timer _viewerTimer;

  @override
  void initState() {
    super.initState();
    _messages.add({'system': true, 'text': '🎬 ${widget.title} 開始直播！'});
    _startViewerSimulation();
  }

  void _startViewerSimulation() {
    _viewerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() {
        final delta = ([-2, -1, 0, 1, 2]..shuffle()).first;
        _viewerCount = (_viewerCount + delta).clamp(100, 999);
      });
    });
  }

  @override
  void dispose() {
    _viewerTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'user': '我', 'text': text});
    });
    _controller.clear();
  }

  void _sendHeart() {
    setState(() => _heartCount++);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.redAccent,
        actions: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, size: 20),
              const SizedBox(width: 4),
              Text('$_viewerCount'),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Image.network(widget.image,
                  width: double.infinity, height: 180, fit: BoxFit.cover),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[_messages.length - 1 - index];
                    if (msg['system'] == true) {
                      return Center(
                        child: Text(
                          msg['text'],
                          style: const TextStyle(
                              color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      );
                    }
                    return Align(
                      alignment: msg['user'] == '我'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: msg['user'] == '我'
                              ? Colors.blueAccent
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg['text'],
                          style: TextStyle(
                            color: msg['user'] == '我'
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: '發送訊息...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
                        onPressed: _sendHeart),
                    IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: () => _sendMessage(_controller.text)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        label: const Text('結束直播'),
        icon: const Icon(Icons.stop),
        onPressed: () {
          notifier.addNotification(
            type: '互動',
            title: '直播結束',
            message: '${widget.title} 已結束，感謝您的收看！',
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}
