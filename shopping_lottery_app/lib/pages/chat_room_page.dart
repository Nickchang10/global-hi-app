// lib/pages/chat_room_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class ChatRoomPage extends StatefulWidget {
  final String title;
  final List<String> members; // 群組成員或對方名稱
  final bool isGroup;

  const ChatRoomPage({
    super.key,
    required this.title,
    required this.members,
    this.isGroup = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _sc = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _peerTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    // 預設幾則訊息示範
    _messages.addAll([
      {
        'id': 'm1',
        'user': widget.isGroup ? widget.members[0] : widget.title,
        'text': '嗨，你好！',
        'time': DateTime.now().subtract(const Duration(minutes: 10)),
        'isMe': false,
        'imageBytes': null,
        'reaction': null,
        'status': 'read'
      },
      {
        'id': 'm2',
        'user': '我',
        'text': '你好，很高興跟你聊天！',
        'time': DateTime.now().subtract(const Duration(minutes: 9)),
        'isMe': true,
        'imageBytes': null,
        'reaction': null,
        'status': 'read'
      },
    ]);

    // 模擬對方後續訊息
    Future.delayed(const Duration(seconds: 4), () => _simulateIncoming('剛剛看了你張貼的貼文，超讚的！'));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _sc.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // 送文字訊息
  void _sendText() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    _ctrl.clear();
    _addMessage(user: '我', text: txt, isMe: true);
  }

  // 送圖片（使用 image_picker）
  Future<void> _sendImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _addMessage(user: '我', text: null, isMe: true, imageBytes: bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('選圖失敗：$e')));
    }
  }

  // 共用新增訊息函式（含模擬送達狀態）
  void _addMessage({
    required String user,
    String? text,
    required bool isMe,
    Uint8List? imageBytes,
  }) {
    final msg = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user': user,
      'text': text ?? '',
      'time': DateTime.now(),
      'isMe': isMe,
      'imageBytes': imageBytes,
      'reaction': null,
      'status': isMe ? 'sending' : 'delivered',
    };

    setState(() => _messages.add(msg));
    _jumpToBottom();

    // 如果是自己發送，模擬送達流程
    if (isMe) {
      Future.delayed(const Duration(milliseconds: 350), () {
        _updateStatus(msg['id'], 'sent');
      });
      Future.delayed(const Duration(seconds: 1), () {
        _updateStatus(msg['id'], 'delivered');
      });
      Future.delayed(const Duration(seconds: 3), () {
        _updateStatus(msg['id'], 'read');
      });
      // 如果對方沒在回應，模擬對方 typing 與回覆
      Future.delayed(const Duration(seconds: 2), () {
        _simulatePeerTypingThenReply();
      });
    }
  }

  void _updateStatus(String id, String status) {
    final idx = _messages.indexWhere((m) => m['id'] == id);
    if (idx >= 0) {
      setState(() => _messages[idx]['status'] = status);
    }
  }

  // 模擬對方輸入與回覆
  void _simulatePeerTypingThenReply() {
    setState(() => _peerTyping = true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() => _peerTyping = false);
      _addMessage(user: widget.isGroup ? widget.members[0] : widget.title, text: '謝謝你的分享！我稍後再看商品連結～', isMe: false);
    });
  }

  // 模擬外部收到訊息
  void _simulateIncoming(String text) {
    setState(() => _peerTyping = true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() => _peerTyping = false);
      _addMessage(user: widget.isGroup ? widget.members[0] : widget.title, text: text, isMe: false);
    });
  }

  // 長按訊息加入 reaction
  void _showReactionPicker(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final emojis = ['👍','❤️','😂','😮','😢','👏'];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis.map((e) {
              return InkWell(
                onTap: () {
                  setState(() => message['reaction'] = e);
                  Navigator.pop(ctx);
                },
                child: Text(e, style: const TextStyle(fontSize: 22)),
              );
            }).toList(),
          ),
        );
      }
    );
  }

  // 複製訊息
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製訊息')));
  }

  // 滾到底
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) {
        _sc.animateTo(_sc.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> m, bool showAvatar) {
    final isMe = m['isMe'] as bool;
    final time = m['time'] as DateTime;
    final reaction = m['reaction'] as String?;
    final status = m['status'] as String?;
    final bubbleColor = isMe ? Colors.blue.shade100 : Colors.white;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(isMe ? 12 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            if (showAvatar)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade400,
                  child: Text(((m['user'] as String).isNotEmpty ? (m['user'] as String)[0] : '?')),
                ),
              )
            else
              const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: align,
              children: [
                if (!isMe && showAvatar) Text(m['user'] as String, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                GestureDetector(
                  onLongPress: () => _showMessageActions(m),
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: m['imageBytes'] != null
                        ? const EdgeInsets.all(6)
                        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: radius,
                      boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 2)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (m['imageBytes'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(m['imageBytes'] as Uint8List, width: 220, fit: BoxFit.cover),
                          ),
                        if ((m['text'] as String).isNotEmpty) ...[
                          Text(m['text'] as String, style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatTime(time), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(width: 6),
                            if (reaction != null) Text(reaction, style: const TextStyle(fontSize: 16)),
                            if (isMe) const SizedBox(width: 6),
                            if (isMe)
                              _statusIcon(status),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            // 我方頭像
            if (showAvatar)
              CircleAvatar(radius: 16, backgroundColor: Colors.blue.shade300, child: const Text('我'))
            else
              const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _statusIcon(String? status) {
    switch (status) {
      case 'sending':
        return const Icon(Icons.access_time, size: 14, color: Colors.grey);
      case 'sent':
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
      default:
        return const SizedBox.shrink();
    }
  }

  // 訊息操作選單（長按）
  void _showMessageActions(Map<String, dynamic> m) {
    showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.emoji_emotions_outlined),
                  title: const Text('加入表情'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReactionPicker(m);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('複製'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copyMessage(m['text'] as String? ?? '');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('刪除'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _messages.removeWhere((x) => x['id'] == m['id']));
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // 判斷是否要顯示頭像（若前一筆同使用者且時間差少於 5 分鐘，則不顯示）
  bool _shouldShowAvatar(int index) {
    if (index == 0) return true;
    final cur = _messages[index];
    final prev = _messages[index - 1];
    if (cur['user'] != prev['user']) return true;
    final diff = (cur['time'] as DateTime).difference(prev['time'] as DateTime).inMinutes;
    return diff > 5;
  }

  // 日期 separator
  Widget _buildDateSeparator(DateTime date) {
    final today = DateTime.now();
    final sameDay = date.year == today.year && date.month == today.month && date.day == today.day;
    final text = sameDay ? '今天' : '${date.year}/${date.month}/${date.day}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(text, style: const TextStyle(color: Colors.black54))),
        const Expanded(child: Divider()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(backgroundColor: Colors.blueGrey, child: Text(widget.title.isNotEmpty ? widget.title[0] : '?')),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            Text(widget.isGroup ? '${widget.members.length} 位成員' : '線上', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('語音通話（示範）')))),
          IconButton(icon: const Icon(Icons.videocam), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('視訊通話（示範）')))),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('聊天室資訊（示範）')))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (sn) {
                // 可根據需要顯示「往下」按鈕
                return false;
              },
              child: ListView.builder(
                controller: _sc,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: _messages.length + (_peerTyping ? 1 : 0),
                itemBuilder: (ctx, idx) {
                  // 如果 peer typing，放在最底下
                  if (_peerTyping && idx == _messages.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade400, child: Text(widget.isGroup ? widget.members[0][0] : widget.title[0])),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                            child: const Text('正在輸入...'),
                          )
                        ],
                      ),
                    );
                  }

                  final m = _messages[idx];
                  // show date separator when first item or date different from previous
                  final prevDate = idx == 0 ? null : (_messages[idx - 1]['time'] as DateTime);
                  final curDate = m['time'] as DateTime;
                  final needDateSep = prevDate == null ||
                      prevDate.year != curDate.year ||
                      prevDate.month != curDate.month ||
                      prevDate.day != curDate.day;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (needDateSep) _buildDateSeparator(curDate),
                      _buildMessageBubble(m, _shouldShowAvatar(idx)),
                    ],
                  );
                },
              ),
            ),
          ),

          // input
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.photo), onPressed: _sendImage),
                  IconButton(icon: const Icon(Icons.emoji_emotions_outlined), onPressed: () {
                    // 簡單示範 emoji 插入
                    _ctrl.text = '${_ctrl.text}🙂';
                    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
                  }),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: '輸入訊息...',
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendText(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FloatingActionButton(
                    heroTag: 'send_btn',
                    mini: true,
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendText,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
