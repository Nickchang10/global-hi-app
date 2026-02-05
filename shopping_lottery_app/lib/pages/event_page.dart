// lib/pages/event_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class EventTab extends StatefulWidget {
  const EventTab({super.key});

  @override
  State<EventTab> createState() => _EventTabState();
}

class _EventTabState extends State<EventTab> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));

  int _currentBanner = 0;
  String _selectedCategory = '全部';
  bool _signedToday = false;
  double _todayProgress = 0.6;

  final List<Map<String, dynamic>> _banners = [
    {
      'image':
          'https://images.unsplash.com/photo-1571019613918-721f6a26c9f8?auto=format&fit=crop&w=1400&q=80',
      'title': '運動挑戰週',
      'desc': '完成五天打卡，解鎖專屬徽章！'
    },
    {
      'image':
          'https://images.unsplash.com/photo-1507537297725-24a1c029d3ca?auto=format&fit=crop&w=1400&q=80',
      'title': '親子運動日',
      'desc': '與孩子一起跑步、快樂健康成長！'
    },
    {
      'image':
          'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=1400&q=80',
      'title': '限時任務挑戰賽',
      'desc': '限時 7 天，看看誰最活躍！'
    },
  ];

  final List<Map<String, dynamic>> _events = [
    {
      'category': '健康挑戰',
      'title': 'Osmile 健走活動',
      'desc': '12/20 - 12/31 完成每日 5,000 步可抽好禮！',
      'image':
          'https://images.unsplash.com/photo-1599058917212-d750089bc07f?auto=format&fit=crop&w=1400&q=80',
      'joined': false,
      'progress': 0.2,
    },
    {
      'category': '親子互動',
      'title': '親子運動任務',
      'desc': '與孩子一起完成 3 次親子任務即可得獎章！',
      'image':
          'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?auto=format&fit=crop&w=1400&q=80',
      'joined': true,
      'progress': 0.7,
    },
    {
      'category': '限時任務',
      'title': 'SOS 互助挑戰賽',
      'desc': '學會使用求救功能，完成教學即可得分！',
      'image':
          'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=1400&q=80',
      'joined': false,
      'progress': 0.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _currentBanner = (_currentBanner + 1) % _banners.length);
      _pageController.animateToPage(
        _currentBanner,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _showConfetti() => _confetti.play();

  void _showEventDetail(Map<String, dynamic> e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text(e['desc'], style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: e['progress'],
              backgroundColor: Colors.grey.shade200,
              color: Colors.orangeAccent,
              minHeight: 6,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flag_rounded),
                label: Text(e['joined'] ? '打卡' : '立即報名'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: e['joined'] ? Colors.blueAccent : Colors.orangeAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showConfetti();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e['joined'] ? '已打卡成功！' : '報名成功，任務開始！'),
                    ),
                  );
                  setState(() {
                    e['joined'] = true;
                    e['progress'] = (e['progress'] + 0.3).clamp(0.0, 1.0);
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCategory == '全部'
        ? _events
        : _events.where((e) => e['category'] == _selectedCategory).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 今日任務卡
            _buildDailyMissionCard(),

            const SizedBox(height: 20),

            // Banner 輪播
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _banners.length,
                onPageChanged: (i) => setState(() => _currentBanner = i),
                itemBuilder: (_, i) => _buildBannerCard(_banners[i]),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentBanner
                          ? Colors.orangeAccent
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 類別 Chips
            Wrap(
              spacing: 10,
              children: ['全部', '健康挑戰', '親子互動', '限時任務']
                  .map((t) => ChoiceChip(
                        label: Text(t),
                        selected: _selectedCategory == t,
                        onSelected: (_) => setState(() => _selectedCategory = t),
                        selectedColor: Colors.orangeAccent,
                        labelStyle: TextStyle(
                          color: _selectedCategory == t ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // 活動清單
            ...filtered.map(_buildEventCard),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 20,
            colors: const [Colors.orange, Colors.blueAccent, Colors.greenAccent],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> b) {
    return GestureDetector(
      onTap: () => _showEventDetail(b),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(
            image: NetworkImage(b['image']),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['title'],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(b['desc'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(e['image'], height: 160, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(e['desc'], style: TextStyle(color: Colors.grey.shade600, height: 1.3)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: e['progress'],
                    backgroundColor: Colors.grey.shade200,
                    color: e['joined'] ? Colors.blueAccent : Colors.orangeAccent,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.flag_rounded),
                      label: Text(e['joined'] ? '打卡' : '立即報名'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            e['joined'] ? Colors.blueAccent : Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _showConfetti();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(e['joined'] ? '已打卡成功！' : '報名成功，任務開始！'),
                          ),
                        );
                        setState(() {
                          e['joined'] = true;
                          e['progress'] = (e['progress'] + 0.3).clamp(0.0, 1.0);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMissionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 今日任務', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _signedToday
                ? '已簽到並完成 ${(_todayProgress * 100).toInt()}% 進度'
                : '每日簽到可獲得積分與徽章',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _todayProgress,
            backgroundColor: Colors.grey.shade200,
            color: Colors.orangeAccent,
            minHeight: 6,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _signedToday = true;
                  _todayProgress = 1.0;
                });
                _showConfetti();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('簽到成功，積分 +50！')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _signedToday ? Colors.grey : Colors.orangeAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: Text(_signedToday ? '已簽到' : '立即簽到'),
            ),
          ),
        ],
      ),
    );
  }
}
