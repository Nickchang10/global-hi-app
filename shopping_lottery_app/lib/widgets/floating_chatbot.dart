// lib/widgets/floating_chatbot.dart
import 'package:flutter/material.dart';

class FloatingChatbot extends StatefulWidget {
  const FloatingChatbot({Key? key}) : super(key: key);

  @override
  State<FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends State<FloatingChatbot> {
  bool _isOpen = false;

  void _toggleChat() {
    setState(() => _isOpen = !_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            right: 20,
            bottom: 100,
            child: Container(
              width: 280,
              height: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Osmile 智能客服',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(height: 1),
                  Expanded(
                    child: Center(
                      child: Text(
                        '您好！請問需要什麼幫助？',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'global_chatbot_fab', // ✅ 唯一 tag
            backgroundColor: Colors.blueAccent,
            onPressed: _toggleChat,
            child: Icon(_isOpen ? Icons.close : Icons.chat_bubble_outline),
          ),
        ),
      ],
    );
  }
}
