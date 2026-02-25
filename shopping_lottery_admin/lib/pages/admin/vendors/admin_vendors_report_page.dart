import 'package:flutter/material.dart';

/// ✅ 必須存在，且名稱要完全相同：AdminVendorReportPage
/// main.dart 會呼叫：admin_vendors_report_page.AdminVendorReportPage(...)
class AdminVendorReportPage extends StatelessWidget {
  final String vendorId;
  final String vendorName;

  const AdminVendorReportPage({
    super.key,
    required this.vendorId,
    this.vendorName = '',
  });

  @override
  Widget build(BuildContext context) {
    final title = vendorName.trim().isEmpty ? '廠商報表' : '廠商報表：$vendorName';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '（占位頁｜可編譯）\n後續可接 Firestore 訂單統計、金額、Top 商品/分類、CSV 匯出。',
                  ),
                  const SizedBox(height: 12),
                  Text('vendorId: $vendorId'),
                  if (vendorName.trim().isNotEmpty)
                    Text('vendorName: $vendorName'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          '/admin_vendors',
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store_mall_directory_outlined),
                            SizedBox(width: 8),
                            Text('回廠商列表'),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          '/admin_vendors/dashboard',
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.dashboard_outlined),
                            SizedBox(width: 8),
                            Text('回廠商儀表板'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
