// lib/pages/admin/marketing/campaign_builder_page_v2.dart
//
// ✅ CampaignBuilderPage v2（支援節點連線與流程模擬｜完整版）
// ------------------------------------------------------------
// - 節點類型：segment / auto_campaign / lottery / notify
// - Firestore 集合：/campaign_flows, /campaign_links
// - 功能：
//   1. 拖曳節點
//   2. 連線箭頭顯示上下游節點
//   3. 編輯節點（名稱、描述、類型）
//   4. 新增 / 刪除節點、連線
//   5. 流程模擬（顯示執行順序）
// ------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CampaignBuilderPageV2 extends StatefulWidget {
  const CampaignBuilderPageV2({super.key});

  @override
  State<CampaignBuilderPageV2> createState() => _CampaignBuilderPageV2State();
}

class _CampaignBuilderPageV2State extends State<CampaignBuilderPageV2> {
  bool _loading = true;
  List<Map<String, dynamic>> _nodes = [];
  List<Map<String, dynamic>> _links = [];
  String? _linkStartNode;
  String? _selectedNode;

  @override
  void initState() {
    super.initState();
    _loadFlows();
  }

  Future<void> _loadFlows() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final nodeSnap = await fs.collection('campaign_flows').get();
      final linkSnap = await fs.collection('campaign_links').get();

      setState(() {
        _nodes = nodeSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _links = linkSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入失敗：$e')));
    }
  }

  Future<void> _saveNode(Map<String, dynamic> node) async {
    final ref = FirebaseFirestore.instance.collection('campaign_flows');
    if (node['id'] == null) {
      await ref.add({
        ...node,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.doc(node['id']).update({
        ...node,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _loadFlows();
  }

  Future<void> _deleteNode(String id) async {
    final fs = FirebaseFirestore.instance;
    await fs.collection('campaign_flows').doc(id).delete();
    final toDelete = _links.where((l) => l['from'] == id || l['to'] == id);
    for (final l in toDelete) {
      await fs.collection('campaign_links').doc(l['id']).delete();
    }
    _loadFlows();
  }

  Future<void> _createLink(String from, String to) async {
    if (from == to) return;
    final exists = _links.any((l) => l['from'] == from && l['to'] == to);
    if (exists) return;
    await FirebaseFirestore.instance.collection('campaign_links').add({
      'from': from,
      'to': to,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _loadFlows();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷流程設計器 v2'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFlows),
          IconButton(icon: const Icon(Icons.play_arrow), onPressed: _simulateFlow),
          IconButton(icon: const Icon(Icons.add), onPressed: _openEditor),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(300),
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: _FlowLinkPainter(_nodes, _links),
                        child: Container(),
                      ),
                      for (final node in _nodes) _buildNode(node),
                    ],
                  ),
                ),
                if (_linkStartNode != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('取消連線模式'),
                      onPressed: () => setState(() => _linkStartNode = null),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildNode(Map<String, dynamic> node) {
    final offset = Offset(
      (node['x'] ?? Random().nextDouble() * 400).toDouble(),
      (node['y'] ?? Random().nextDouble() * 300).toDouble(),
    );
    final selected = _selectedNode == node['id'];
    final linking = _linkStartNode != null && _linkStartNode == node['id'];

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onTap: () {
          if (_linkStartNode != null && _linkStartNode != node['id']) {
            _createLink(_linkStartNode!, node['id']);
            setState(() => _linkStartNode = null);
          } else {
            setState(() => _selectedNode = node['id']);
          }
        },
        onLongPress: () => setState(() => _linkStartNode = node['id']),
        onDoubleTap: () => _openEditor(existing: node),
        child: Draggable<Map<String, dynamic>>(
          data: node,
          feedback: _nodeBox(node, selected: true, opacity: 0.6),
          childWhenDragging: _nodeBox(node, selected: false, opacity: 0.3),
          onDragEnd: (details) {
            final box = context.findRenderObject() as RenderBox;
            final pos = box.globalToLocal(details.offset);
            node['x'] = pos.dx;
            node['y'] = pos.dy;
            _saveNode(node);
          },
          child: _nodeBox(node, selected: selected, linking: linking),
        ),
      ),
    );
  }

  Widget _nodeBox(Map<String, dynamic> node,
      {bool selected = false, bool linking = false, double opacity = 1}) {
    final color = _colorByType(node['type'] ?? 'segment');
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(selected ? 0.95 : 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: linking ? Colors.red : selected ? Colors.blue : Colors.white,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconByType(node['type']), color: Colors.white),
            const SizedBox(height: 6),
            Text(node['title'] ?? '未命名',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text(node['type'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white70, size: 18),
              onPressed: () => _confirmDelete(node['id']),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除節點'),
        content: const Text('確定要刪除此節點及其連線嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNode(id);
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // 模擬流程
  // =====================================================
  void _simulateFlow() {
    if (_nodes.isEmpty) return;
    final startNodes = _nodes.where((n) => !_links.any((l) => l['to'] == n['id']));
    final sb = StringBuffer();
    for (final start in startNodes) {
      _simulateNode(start['id'], sb, 0);
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('流程模擬結果'),
        content: SingleChildScrollView(child: Text(sb.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        ],
      ),
    );
  }

  void _simulateNode(String id, StringBuffer sb, int depth) {
    final node = _nodes.firstWhere((n) => n['id'] == id, orElse: () => {});
    if (node.isEmpty) return;
    sb.writeln('${'  ' * depth}➡ ${node['title']} (${node['type']})');
    final nextLinks = _links.where((l) => l['from'] == id);
    for (final l in nextLinks) {
      _simulateNode(l['to'], sb, depth + 1);
    }
  }

  // =====================================================
  // 編輯器 Dialog
  // =====================================================
  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    String type = existing?['type'] ?? 'segment';
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? '新增節點' : '編輯節點'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '節點名稱'),
              ),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'segment', child: Text('受眾分群')),
                  DropdownMenuItem(value: 'auto_campaign', child: Text('自動派發')),
                  DropdownMenuItem(value: 'lottery', child: Text('抽獎活動')),
                  DropdownMenuItem(value: 'notify', child: Text('推播通知')),
                ],
                onChanged: (v) => type = v ?? 'segment',
                decoration: const InputDecoration(labelText: '節點類型'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final node = {
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'type': type,
                'x': existing?['x'] ?? Random().nextDouble() * 400,
                'y': existing?['y'] ?? Random().nextDouble() * 300,
                'id': existing?['id'],
              };
              Navigator.pop(context);
              _saveNode(node);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  IconData _iconByType(String type) {
    switch (type) {
      case 'segment':
        return Icons.people;
      case 'auto_campaign':
        return Icons.campaign;
      case 'lottery':
        return Icons.emoji_events;
      case 'notify':
        return Icons.notifications_active;
      default:
        return Icons.extension;
    }
  }

  Color _colorByType(String type) {
    switch (type) {
      case 'segment':
        return Colors.teal;
      case 'auto_campaign':
        return Colors.blueAccent;
      case 'lottery':
        return Colors.orange;
      case 'notify':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// =====================================================
// 自訂連線繪圖
// =====================================================
class _FlowLinkPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> links;

  _FlowLinkPainter(this.nodes, this.links);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 2;

    for (final l in links) {
      final from = nodes.firstWhere((n) => n['id'] == l['from'], orElse: () => {});
      final to = nodes.firstWhere((n) => n['id'] == l['to'], orElse: () => {});
      if (from.isEmpty || to.isEmpty) continue;
      final p1 = Offset((from['x'] ?? 0) + 80, (from['y'] ?? 0) + 40);
      final p2 = Offset((to['x'] ?? 0) + 80, (to['y'] ?? 0) + 40);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
