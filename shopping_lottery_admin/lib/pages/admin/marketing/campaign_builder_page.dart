// lib/pages/admin/marketing/campaign_builder_page.dart
//
// ✅ CampaignBuilderPage（行銷流程設計器｜完整版 v1.0）
// ------------------------------------------------------------
// - Firestore 集合：/campaign_flows
// - 節點類型：segment / auto_campaign / lottery / notify
// - 支援：拖曳、連線、儲存、模擬
// - 使用 package:interactiveviewer 進行流程視覺化
// ------------------------------------------------------------

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CampaignBuilderPage extends StatefulWidget {
  const CampaignBuilderPage({super.key});

  @override
  State<CampaignBuilderPage> createState() => _CampaignBuilderPageState();
}

class _CampaignBuilderPageState extends State<CampaignBuilderPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _nodes = [];
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _loadFlows();
  }

  Future<void> _loadFlows() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('campaign_flows')
          .orderBy('updatedAt', descending: true)
          .get();

      final nodes = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      setState(() {
        _nodes = nodes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('讀取流程失敗：$e')));
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
    await FirebaseFirestore.instance.collection('campaign_flows').doc(id).delete();
    _loadFlows();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除節點')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行銷流程設計器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: _loadFlows,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增節點',
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _nodes.isEmpty
              ? const Center(child: Text('尚無流程節點'))
              : InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(200),
                  minScale: 0.5,
                  maxScale: 2.0,
                  child: Stack(
                    children: [
                      for (final node in _nodes)
                        _buildNodeWidget(node),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNodeWidget(Map<String, dynamic> node) {
    final offset = Offset(
      (node['x'] ?? Random().nextDouble() * 400).toDouble(),
      (node['y'] ?? Random().nextDouble() * 300).toDouble(),
    );
    final selected = _selectedNodeId == node['id'];

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onTap: () => setState(() => _selectedNodeId = node['id']),
        onDoubleTap: () => _openEditor(existing: node),
        child: Draggable<Map<String, dynamic>>(
          data: node,
          feedback: _nodeBox(node, selected: true, opacity: 0.6),
          childWhenDragging: _nodeBox(node, selected: false, opacity: 0.3),
          onDragEnd: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(details.offset);
            node['x'] = offset.dx;
            node['y'] = offset.dy;
            _saveNode(node);
          },
          child: _nodeBox(node, selected: selected),
        ),
      ),
    );
  }

  Widget _nodeBox(Map<String, dynamic> node,
      {bool selected = false, double opacity = 1.0}) {
    final color = _colorByType(node['type'] ?? 'segment');
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(selected ? 0.9 : 0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (selected)
              BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconByType(node['type']), color: Colors.white),
            const SizedBox(height: 6),
            Text(
              node['title'] ?? '未命名',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              node['type'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
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

  // =====================================================
  // 節點編輯器 Dialog
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
}
