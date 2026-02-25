import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHomeCarousel extends StatefulWidget {
  const AdminHomeCarousel({super.key});

  @override
  State<AdminHomeCarousel> createState() => _AdminHomeCarouselState();
}

class _AdminHomeCarouselState extends State<AdminHomeCarousel> {
  int _index = 0;
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final query = FirebaseFirestore.instance
        .collection('news')
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(5);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 140,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox(
            height: 140,
            child: Center(child: Text('目前沒有公告')),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 140,
              child: PageView.builder(
                controller: _pc,
                itemCount: docs.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString();
                  final desc = (data['desc'] ?? '').toString();
                  final img = (data['imageUrl'] ?? '').toString();

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        img.isNotEmpty
                            ? Image.network(img, fit: BoxFit.cover)
                            : Container(
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.30,
                                ),
                              ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.10),
                                Colors.black.withValues(alpha: 0.60),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Spacer(),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(docs.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
