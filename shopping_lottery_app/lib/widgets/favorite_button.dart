// lib/widgets/favorite_button.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ✅ FavoriteButton（收藏按鈕｜可編譯｜已修正 use_build_context_synchronously + control_flow_in_finally）
/// ------------------------------------------------------------------
/// Firestore 結構（預設）：
/// users/{uid}/favorites/{itemId}
///   - itemId: String
///   - createdAt: serverTimestamp
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.itemId,
    this.size = 22,
    this.activeColor,
    this.inactiveColor,
    this.initialIsFavorite,
    this.onChanged,
    this.collectionName = 'favorites',
  });

  final String itemId;
  final double size;

  final Color? activeColor;
  final Color? inactiveColor;

  final bool? initialIsFavorite;
  final ValueChanged<bool>? onChanged;

  /// users/{uid}/{collectionName}/{itemId}
  final String collectionName;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _loading = false;
  bool _fav = false;
  bool _inited = false;

  User? get _user => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _favDoc(String uid) {
    return _fs
        .collection('users')
        .doc(uid)
        .collection(widget.collectionName)
        .doc(widget.itemId);
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialIsFavorite != null) {
      _fav = widget.initialIsFavorite!;
      _inited = true;
    } else {
      _loadInitial();
    }
  }

  Future<void> _loadInitial() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _fav = false;
        _inited = true;
      });
      return;
    }

    try {
      final snap = await _favDoc(user.uid).get();
      if (!mounted) return;
      setState(() {
        _fav = snap.exists;
        _inited = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fav = false;
        _inited = true;
      });
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;

    // ✅ async 前先取出，避免 await 後再用 context
    final messenger = ScaffoldMessenger.of(context);

    final user = _user;
    if (user == null) {
      messenger.showSnackBar(const SnackBar(content: Text('請先登入才能使用收藏功能')));
      return;
    }

    setState(() => _loading = true);

    final docRef = _favDoc(user.uid);
    bool nextFav = _fav;

    try {
      await _fs.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) {
          tx.delete(docRef);
          nextFav = false;
        } else {
          tx.set(docRef, {
            'itemId': widget.itemId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          nextFav = true;
        }
      });

      if (!mounted) return;

      setState(() => _fav = nextFav);
      widget.onChanged?.call(nextFav);

      messenger.showSnackBar(
        SnackBar(content: Text(nextFav ? '已加入收藏' : '已取消收藏')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('收藏操作失敗：$e')));
    } finally {
      // ✅ finally 裡不要 return（避免 control_flow_in_finally）
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeColor ?? Colors.redAccent;
    final inactive = widget.inactiveColor ?? Colors.grey;

    if (!_inited) {
      return SizedBox(
        width: widget.size + 18,
        height: widget.size + 18,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: _fav ? '取消收藏' : '加入收藏',
      onPressed: _loading ? null : _toggle,
      iconSize: widget.size,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          _fav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey<bool>(_fav),
          color: _fav ? active : inactive,
        ),
      ),
    );
  }
}
