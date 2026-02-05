// lib/pages/chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String currentUser;
  final String friendName;

  const ChatPage({
    super.key,
    required this.currentUser,
    required this.friendName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isRecording = false;
  Timer? _timer;
  int _recordSeconds = 0;

  final List<String> _stickers = [
    '😀', '😂', '😍', '😎', '😭', '👍', '🎉', '❤️', '🔥', '🥳',
  ];

  void _sendMessage(String text, {bool isSticker = false}) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add({
        'sender': widget.currentUser,
        'text': t,
        'sticker': isSticker,
      });
    });
    _controller.clear();
    _scrollToBottom();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _messages.add({
        'sender': widget.currentUser,
        'text': '[語音訊息 ${_recordSeconds}s]',
        'sticker': false,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openStickerPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        children: _stickers.map((s) {
          return InkWell(
            onTap: () {
              Navigator.pop(context);
              _sendMessage(s, isSticker: true);
            },
            child: Center(
              child: Text(s, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final bool isMine = msg['sender'] == widget.currentUser;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isMine ? Colors.orange[300] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: msg['sticker'] == true
            ? Text(msg['text'], style: const TextStyle(fontSize: 26))
            : Text(
                msg['text'],
                style: TextStyle(
                  color: isMine ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 6,
              backgroundColor: Colors.green,
            ),
            const SizedBox(width: 8),
            Text(widget.friendName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: _messages.map(_buildMessage).toList(),
            ),
          ),
          if (_isRecording)
            Container(
              color: Colors.redAccent,
              padding: const EdgeInsets.all(8),
              child: Text(
                '錄音中… $_recordSeconds s',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined),
                onPressed: _openStickerPicker,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '輸入訊息…',
                    border: InputBorder.none,
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.mic, color: Colors.redAccent),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.orange),
                onPressed: () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
