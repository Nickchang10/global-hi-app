import 'package:flutter/material.dart';

import 'shop_app_bar.dart';

class ShopScaffold extends StatelessWidget {
  const ShopScaffold({
    super.key,
    required this.body,
    this.title,
  });

  final Widget body;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShopAppBar(title: title),
      body: body,
    );
  }
}
