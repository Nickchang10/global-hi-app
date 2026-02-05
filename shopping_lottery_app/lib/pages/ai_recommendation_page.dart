import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_recommendation_service.dart';

/// 🧩 AI 智慧推薦中心
class AIRecommendationPage extends StatelessWidget {
  const AIRecommendationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ai = Provider.of<AIRecommendationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🧠 智慧推薦中心"),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "重新生成推薦",
            onPressed: ai.generateRecommendations,
          ),
        ],
      ),
      body: ai.recommendations.isEmpty
          ? Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text("產生個人化推薦"),
                onPressed: ai.generateRecommendations,
              ),
            )
          : ListView.builder(
              itemCount: ai.recommendations.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final r = ai.recommendations[i];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF007BFF).withOpacity(0.15),
                      child: const Icon(Icons.auto_awesome,
                          color: Color(0xFF007BFF)),
                    ),
                    title: Text(
                      r["name"],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(r["reason"]),
                    trailing: Text(
                      "${(r["score"] * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
