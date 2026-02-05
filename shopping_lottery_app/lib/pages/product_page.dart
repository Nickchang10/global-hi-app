// lib/pages/product_page.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../widgets/floating_chatbot.dart';
import 'checkout_page.dart';

class ProductPage extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late VideoPlayerController _videoController;
  late FlutterTts _tts;
  late stt.SpeechToText _speech;
  bool _showChatPrompt = false;
  bool _isListening = false;
  String _lastWords = "";

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(
      widget.product["videoUrl"] ?? 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    )..initialize().then((_) => setState(() {}))
     ..addListener(_onVideoChange);
    _tts = FlutterTts()..setLanguage("zh-TW")..setSpeechRate(0.45)..setPitch(1.0);
    _speech = stt.SpeechToText();
  }

  void _onVideoChange() {
    if (_videoController.value.isInitialized &&
        _videoController.value.position >= _videoController.value.duration) {
      _tts.speak("影片介紹結束，是否要我幫您加入購物車呢？");
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  void _addToCart() {
    // 若有 CartService 可呼用，範例改為 UI 提示
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${widget.product['name']} 已加入購物車")));
    _tts.speak("已加入購物車");
  }

  void _onBuyNow() {
    // 直接呼叫 CheckoutPage；apiBase: '' -> 使用 mock
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CheckoutPage(product: widget.product, qty: 1, apiBase: ''),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(p['name'] ?? '商品')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (_videoController.value.isInitialized)
            AspectRatio(aspectRatio: _videoController.value.aspectRatio, child: VideoPlayer(_videoController))
          else
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 12),
          Text(p['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("NT\$ ${p['price'] ?? 0}", style: const TextStyle(fontSize: 18, color: Colors.redAccent)),
          const SizedBox(height: 12),
          Text(p['description'] ?? ''),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _addToCart, icon: const Icon(Icons.add_shopping_cart), label: const Text('加入購物車')),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _onBuyNow, icon: const Icon(Icons.flash_on), label: const Text('立即購買'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
          const SizedBox(height: 12),
        ]),
      ),
      floatingActionButton: const FloatingChatBot(),
    );
  }
}
