// lib/pages/site/site_pages.dart
//
// ✅ 網站內容管理模板合集（10頁）

import 'package:flutter/material.dart';

class CompanyAboutPage extends StatelessWidget {
  const CompanyAboutPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('公司簡介管理頁');
}

class VisionPage extends StatelessWidget {
  const VisionPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('願景與理念管理頁');
}

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('服務項目管理頁');
}

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('最新消息管理頁');
}

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('FAQ 管理頁');
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('下載區管理頁');
}

class GuestbookPage extends StatelessWidget {
  const GuestbookPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('留言板管理頁');
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('聯絡我們管理頁');
}

class SiteCustomHomePage extends StatelessWidget {
  const SiteCustomHomePage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('首頁中間自訂區塊');
}

class SiteTopbarPage extends StatelessWidget {
  const SiteTopbarPage({super.key});
  @override
  Widget build(BuildContext context) => _ScaffoldWrap('上方導覽列管理頁');
}

// 共用 scaffold
Widget _ScaffoldWrap(String title) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title（內容待實作）',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      ),
    );
