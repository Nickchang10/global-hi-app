// lib/services/social_service.dart
//
// ✅ SocialService（正式版｜完整版｜可直接編譯）
// ----------------------------------------------------
// ✅ SocialService.instance
// ✅ friends / activities / loading / error / init() / refresh()
// ✅ likeActivity()（toggle like / unlike）
// ✅ joinActivity()（toggle join / unjoin）
// ✅ SocialActivity：startAt / endAt / coverUrl / description / likes / participants
// ✅ Firestore paths:
//    - friends：users/{uid}/friends
//    - activities：users/{uid}/activities（fallback: users/{uid}/social_activities）
// ----------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// -----------------------------
// Models
// -----------------------------

class SocialFriend {
  final String uid;
  final Map<String, dynamic> data;

  SocialFriend({required this.uid, required Map<String, dynamic> data})
    : data = Map<String, dynamic>.from(data);

  dynamic operator [](String key) => data[key];

  String get displayName =>
      (data['displayName'] ?? data['name'] ?? data['nickname'] ?? '好友')
          .toString();

  String get name => displayName;

  String? get photoUrl => _asStringOrNull(
    data['photoUrl'] ?? data['avatarUrl'] ?? data['imageUrl'],
  );
  String? get avatarUrl => photoUrl;

  bool get hasStory => data['hasStory'] == true;

  DateTime? get storyUpdatedAt => _asDateTime(data['storyUpdatedAt']);

  Map<String, dynamic> toMap() => {'uid': uid, ...data};

  static String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _asDateTime(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }
}

class SocialActivity {
  final String id;
  final Map<String, dynamic> data;

  SocialActivity({required this.id, required Map<String, dynamic> data})
    : data = Map<String, dynamic>.from(data);

  dynamic operator [](String key) => data[key];

  String get title =>
      (data['title'] ?? data['name'] ?? data['subject'] ?? '活動').toString();

  /// ✅ social_activity_center_page 用到：description
  String get description =>
      (data['description'] ??
              data['desc'] ??
              data['body'] ??
              data['content'] ??
              data['detail'] ??
              '')
          .toString();

  String get body => description;

  String get type => (data['type'] ?? data['category'] ?? 'social').toString();

  bool get unread => data['read'] == true ? false : (data['unread'] == true);

  DateTime? get createdAt =>
      _asDateTime(data['createdAt'] ?? data['time'] ?? data['timestamp']);

  DateTime? get startAt => _asDateTime(
    data['startAt'] ??
        data['start_at'] ??
        data['startTime'] ??
        data['start_time'] ??
        data['start'] ??
        data['beginAt'] ??
        data['begin_at'],
  );

  DateTime? get endAt => _asDateTime(
    data['endAt'] ??
        data['end_at'] ??
        data['endTime'] ??
        data['end_time'] ??
        data['end'] ??
        data['finishAt'] ??
        data['finish_at'],
  );

  String? get imageUrl => _asStringOrNull(
    data['imageUrl'] ??
        data['image_url'] ??
        data['photoUrl'] ??
        data['photo_url'],
  );

  String? get coverUrl => _asStringOrNull(
    data['coverUrl'] ??
        data['cover_url'] ??
        data['bannerUrl'] ??
        data['banner_url'] ??
        data['imageUrl'] ??
        data['image_url'] ??
        data['photoUrl'] ??
        data['photo_url'],
  );

  String? get avatarUrl => _asStringOrNull(
    data['avatarUrl'] ??
        data['avatar_url'] ??
        data['photoUrl'] ??
        data['photo_url'],
  );

  /// ✅ social_activity_center_page 用到：likes
  int get likes => _asInt(
    data['likes'] ??
        data['likeCount'] ??
        data['like_count'] ??
        data['hearts'] ??
        data['heartCount'] ??
        data['heart_count'] ??
        data['likedUsers'] ??
        data['liked_users'],
  );

  /// ✅ social_activity_center_page 用到：participants
  int get participants => _asInt(
    data['participants'] ??
        data['participantCount'] ??
        data['participant_count'] ??
        data['joinCount'] ??
        data['join_count'] ??
        data['joinedCount'] ??
        data['joined_count'] ??
        data['participantUids'] ??
        data['participant_uids'] ??
        data['participantsList'] ??
        data['participants_list'] ??
        data['joinedUsers'] ??
        data['joined_users'],
  );

  List<String> get likedUsers {
    final v = data['likedUsers'] ?? data['liked_users'];
    if (v is List) return v.map((e) => e.toString()).toList(growable: false);
    return const [];
  }

  List<String> get joinedUsers {
    final v =
        data['joinedUsers'] ??
        data['joined_users'] ??
        data['participantUids'] ??
        data['participant_uids'] ??
        data['participantsList'] ??
        data['participants_list'];
    if (v is List) return v.map((e) => e.toString()).toList(growable: false);
    return const [];
  }

  Map<String, dynamic> toMap() => {'id': id, ...data};

  static DateTime? _asDateTime(dynamic v) {
    try {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
    } catch (_) {}
    return null;
  }

  static String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int _asInt(dynamic v) {
    try {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      if (v is List) return v.length;
      if (v is Map) return v.length;
    } catch (_) {}
    return 0;
  }
}

// -----------------------------
// Service
// -----------------------------

class SocialService extends ChangeNotifier {
  SocialService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  static final SocialService instance = SocialService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activitiesSub;

  bool _started = false;

  bool _loadingFriends = false;
  bool _loadingActivities = false;

  String? _error;
  String? get error => _error;

  bool get loading => _loadingFriends || _loadingActivities;

  List<SocialFriend> _friends = const [];
  List<SocialFriend> get friends => List.unmodifiable(_friends);

  List<SocialActivity> _activities = const [];
  List<SocialActivity> get activities => List.unmodifiable(_activities);

  List<Map<String, dynamic>> get activitiesRaw =>
      List.unmodifiable(_activities.map((e) => e.toMap()));

  void init() => start();

  void start() {
    if (_started) return;
    _started = true;

    _handleUser(_auth.currentUser);

    _authSub?.cancel();
    _authSub = _auth.userChanges().listen(_handleUser);
  }

  void _handleUser(User? user) {
    if (user == null) {
      _cancelFriendsSub();
      _cancelActivitiesSub();
      _setFriends(const []);
      _setActivities(const []);
      _setLoadingFriends(false);
      _setLoadingActivities(false);
      _setError(null);
      return;
    }

    _listenFriends(user.uid);
    _listenActivities(user.uid);
  }

  // -----------------------------
  // Friends (stream)
  // -----------------------------
  void _listenFriends(String uid) {
    _cancelFriendsSub();
    _setLoadingFriends(true);
    _setError(null);

    final q = _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .orderBy('storyUpdatedAt', descending: true);

    _friendsSub = q.snapshots().listen(
      (snap) {
        final list = snap.docs
            .map(
              (d) => SocialFriend(uid: d.id, data: {'uid': d.id, ...d.data()}),
            )
            .toList(growable: false);

        _setFriends(list);
        _setLoadingFriends(false);
      },
      onError: (e) async {
        try {
          final q2 = _db.collection('users').doc(uid).collection('friends');
          _friendsSub = q2.snapshots().listen(
            (snap) {
              final list = snap.docs
                  .map(
                    (d) => SocialFriend(
                      uid: d.id,
                      data: {'uid': d.id, ...d.data()},
                    ),
                  )
                  .toList(growable: false);

              _setFriends(list);
              _setLoadingFriends(false);
            },
            onError: (e2) {
              _setFriends(const []);
              _setError(_asErrorMessage(e2));
              _setLoadingFriends(false);
            },
          );
        } catch (e3) {
          _setFriends(const []);
          _setError(_asErrorMessage(e3));
          _setLoadingFriends(false);
        }
      },
    );
  }

  // -----------------------------
  // Activities (stream)
  // -----------------------------
  void _listenActivities(String uid) {
    _cancelActivitiesSub();
    _setLoadingActivities(true);
    _setError(null);

    final q = _db
        .collection('users')
        .doc(uid)
        .collection('activities')
        .orderBy('createdAt', descending: true);

    _activitiesSub = q.snapshots().listen(
      (snap) {
        final list = snap.docs
            .map(
              (d) => SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
            )
            .toList(growable: false);

        _setActivities(list);
        _setLoadingActivities(false);
      },
      onError: (_) async {
        try {
          final q2 = _db
              .collection('users')
              .doc(uid)
              .collection('social_activities')
              .orderBy('createdAt', descending: true);

          _activitiesSub = q2.snapshots().listen((snap) {
            final list = snap.docs
                .map(
                  (d) =>
                      SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
                )
                .toList(growable: false);

            _setActivities(list);
            _setLoadingActivities(false);
          }, onError: (_) => _listenActivitiesNoOrder(uid));
        } catch (_) {
          _listenActivitiesNoOrder(uid);
        }
      },
    );
  }

  void _listenActivitiesNoOrder(String uid) {
    _cancelActivitiesSub();

    try {
      final q = _db.collection('users').doc(uid).collection('activities');
      _activitiesSub = q.snapshots().listen(
        (snap) {
          final list = snap.docs
              .map(
                (d) =>
                    SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
              )
              .toList(growable: false);

          _setActivities(list);
          _setLoadingActivities(false);
        },
        onError: (_) {
          try {
            final q2 = _db
                .collection('users')
                .doc(uid)
                .collection('social_activities');
            _activitiesSub = q2.snapshots().listen(
              (snap) {
                final list = snap.docs
                    .map(
                      (d) => SocialActivity(
                        id: d.id,
                        data: {'id': d.id, ...d.data()},
                      ),
                    )
                    .toList(growable: false);

                _setActivities(list);
                _setLoadingActivities(false);
              },
              onError: (e2) {
                _setActivities(const []);
                _setError(_asErrorMessage(e2));
                _setLoadingActivities(false);
              },
            );
          } catch (e3) {
            _setActivities(const []);
            _setError(_asErrorMessage(e3));
            _setLoadingActivities(false);
          }
        },
      );
    } catch (e) {
      _setActivities(const []);
      _setError(_asErrorMessage(e));
      _setLoadingActivities(false);
    }
  }

  // -----------------------------
  // Manual refresh
  // -----------------------------
  Future<void> refresh() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _setFriends(const []);
      _setActivities(const []);
      _setError(null);
      return;
    }

    _setError(null);
    _setLoadingFriends(true);
    _setLoadingActivities(true);

    // friends
    try {
      try {
        final f = await _db
            .collection('users')
            .doc(uid)
            .collection('friends')
            .orderBy('storyUpdatedAt', descending: true)
            .get();
        _setFriends(
          f.docs
              .map(
                (d) =>
                    SocialFriend(uid: d.id, data: {'uid': d.id, ...d.data()}),
              )
              .toList(),
        );
      } catch (_) {
        final f = await _db
            .collection('users')
            .doc(uid)
            .collection('friends')
            .get();
        _setFriends(
          f.docs
              .map(
                (d) =>
                    SocialFriend(uid: d.id, data: {'uid': d.id, ...d.data()}),
              )
              .toList(),
        );
      }
    } catch (e) {
      _setFriends(const []);
      _setError(_asErrorMessage(e));
    } finally {
      _setLoadingFriends(false);
    }

    // activities
    try {
      try {
        final a = await _db
            .collection('users')
            .doc(uid)
            .collection('activities')
            .orderBy('createdAt', descending: true)
            .get();

        _setActivities(
          a.docs
              .map(
                (d) =>
                    SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
              )
              .toList(),
        );
      } catch (_) {
        final a2 = await _db
            .collection('users')
            .doc(uid)
            .collection('social_activities')
            .orderBy('createdAt', descending: true)
            .get();

        _setActivities(
          a2.docs
              .map(
                (d) =>
                    SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
              )
              .toList(),
        );
      }
    } catch (e) {
      try {
        final a = await _db
            .collection('users')
            .doc(uid)
            .collection('activities')
            .get();
        _setActivities(
          a.docs
              .map(
                (d) =>
                    SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
              )
              .toList(),
        );
      } catch (_) {
        try {
          final a2 = await _db
              .collection('users')
              .doc(uid)
              .collection('social_activities')
              .get();
          _setActivities(
            a2.docs
                .map(
                  (d) =>
                      SocialActivity(id: d.id, data: {'id': d.id, ...d.data()}),
                )
                .toList(),
          );
        } catch (e2) {
          _setActivities(const []);
          _setError(_asErrorMessage(e2));
        }
      }
    } finally {
      _setLoadingActivities(false);
    }
  }

  // -----------------------------
  // ✅ likeActivity（toggle like / unlike）
  // -----------------------------
  Future<void> likeActivity(dynamic activityOrId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final activityId = (activityOrId is SocialActivity)
        ? activityOrId.id
        : activityOrId.toString().trim();
    if (activityId.isEmpty) return;

    // ✅ 修正：區域識別字不可以用底線開頭（no_leading_underscores_for_local_identifiers）
    Future<bool> toggleOnRef(
      DocumentReference<Map<String, dynamic>> ref,
    ) async {
      return _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Activity not found: ${ref.path}');
        final data = (snap.data() ?? <String, dynamic>{});

        final likedUsersRaw = data['likedUsers'] ?? data['liked_users'];
        final likedUsers = <String>[
          if (likedUsersRaw is List) ...likedUsersRaw.map((e) => e.toString()),
        ];

        final alreadyLiked = likedUsers.contains(uid);

        int likesNow = SocialActivity._asInt(
          data['likes'] ??
              data['likeCount'] ??
              data['like_count'] ??
              likedUsers.length,
        );

        if (alreadyLiked) {
          likedUsers.removeWhere((e) => e == uid);
          likesNow = likesNow - 1;
          if (likesNow < 0) likesNow = 0;
        } else {
          likedUsers.add(uid);
          likesNow = likesNow + 1;
        }

        tx.update(ref, {
          'likedUsers': likedUsers,
          'likes': likesNow,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return !alreadyLiked; // likedNow
      });
    }

    final primary = _db
        .collection('users')
        .doc(uid)
        .collection('activities')
        .doc(activityId);
    final fallback = _db
        .collection('users')
        .doc(uid)
        .collection('social_activities')
        .doc(activityId);

    bool? likedNow;
    try {
      likedNow = await toggleOnRef(primary);
    } catch (_) {
      try {
        likedNow = await toggleOnRef(fallback);
      } catch (_) {}
    }

    if (likedNow != null) {
      _activities = _activities
          .map((a) {
            if (a.id != activityId) return a;

            final m = Map<String, dynamic>.from(a.data);
            final raw = m['likedUsers'] ?? m['liked_users'];
            final list = <String>[
              if (raw is List) ...raw.map((e) => e.toString()),
            ];

            int likes = SocialActivity._asInt(
              m['likes'] ?? m['likeCount'] ?? m['like_count'] ?? list.length,
            );

            if (likedNow == true) {
              if (!list.contains(uid)) list.add(uid);
              likes = likes + 1;
            } else {
              list.removeWhere((e) => e == uid);
              likes = likes - 1;
              if (likes < 0) likes = 0;
            }

            m['likedUsers'] = list;
            m['likes'] = likes;
            return SocialActivity(id: a.id, data: m);
          })
          .toList(growable: false);

      notifyListeners();
    }
  }

  // -----------------------------
  // ✅ joinActivity（toggle join / unjoin）
  // -----------------------------
  Future<void> joinActivity(dynamic activityOrId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final activityId = (activityOrId is SocialActivity)
        ? activityOrId.id
        : activityOrId.toString().trim();
    if (activityId.isEmpty) return;

    // ✅ 修正：區域識別字不可以用底線開頭
    Future<bool> toggleOnRef(
      DocumentReference<Map<String, dynamic>> ref,
    ) async {
      return _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Activity not found: ${ref.path}');
        final data = (snap.data() ?? <String, dynamic>{});

        // 支援多種欄位名稱
        final joinedRaw =
            data['joinedUsers'] ??
            data['joined_users'] ??
            data['participantUids'] ??
            data['participant_uids'] ??
            data['participantsList'] ??
            data['participants_list'];

        final joinedUsers = <String>[
          if (joinedRaw is List) ...joinedRaw.map((e) => e.toString()),
        ];

        final alreadyJoined = joinedUsers.contains(uid);

        int participantsNow = SocialActivity._asInt(
          data['participants'] ??
              data['participantCount'] ??
              data['participant_count'] ??
              data['joinCount'] ??
              data['join_count'] ??
              data['joinedCount'] ??
              data['joined_count'] ??
              joinedUsers.length,
        );

        if (alreadyJoined) {
          joinedUsers.removeWhere((e) => e == uid);
          participantsNow = participantsNow - 1;
          if (participantsNow < 0) participantsNow = 0;
        } else {
          joinedUsers.add(uid);
          participantsNow = participantsNow + 1;
        }

        tx.update(ref, {
          // 統一寫回 joinedUsers + participants
          'joinedUsers': joinedUsers,
          'participants': participantsNow,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return !alreadyJoined; // joinedNow
      });
    }

    final primary = _db
        .collection('users')
        .doc(uid)
        .collection('activities')
        .doc(activityId);
    final fallback = _db
        .collection('users')
        .doc(uid)
        .collection('social_activities')
        .doc(activityId);

    bool? joinedNow;
    try {
      joinedNow = await toggleOnRef(primary);
    } catch (_) {
      try {
        joinedNow = await toggleOnRef(fallback);
      } catch (_) {}
    }

    // 本地同步，讓 UI 立即更新
    if (joinedNow != null) {
      _activities = _activities
          .map((a) {
            if (a.id != activityId) return a;

            final m = Map<String, dynamic>.from(a.data);

            final raw =
                m['joinedUsers'] ??
                m['joined_users'] ??
                m['participantUids'] ??
                m['participant_uids'] ??
                m['participantsList'] ??
                m['participants_list'];

            final list = <String>[
              if (raw is List) ...raw.map((e) => e.toString()),
            ];

            int participants = SocialActivity._asInt(
              m['participants'] ??
                  m['participantCount'] ??
                  m['participant_count'] ??
                  m['joinCount'] ??
                  m['join_count'] ??
                  m['joinedCount'] ??
                  m['joined_count'] ??
                  list.length,
            );

            if (joinedNow == true) {
              if (!list.contains(uid)) list.add(uid);
              participants = participants + 1;
            } else {
              list.removeWhere((e) => e == uid);
              participants = participants - 1;
              if (participants < 0) participants = 0;
            }

            m['joinedUsers'] = list;
            m['participants'] = participants;
            return SocialActivity(id: a.id, data: m);
          })
          .toList(growable: false);

      notifyListeners();
    }
  }

  // -----------------------------
  // Internals
  // -----------------------------
  void _setFriends(List<SocialFriend> list) {
    _friends = list;
    notifyListeners();
  }

  void _setActivities(List<SocialActivity> list) {
    _activities = list;
    notifyListeners();
  }

  void _setLoadingFriends(bool v) {
    if (_loadingFriends == v) return;
    _loadingFriends = v;
    notifyListeners();
  }

  void _setLoadingActivities(bool v) {
    if (_loadingActivities == v) return;
    _loadingActivities = v;
    notifyListeners();
  }

  void _setError(String? v) {
    if (_error == v) return;
    _error = v;
    notifyListeners();
  }

  String _asErrorMessage(Object e) {
    final s = e.toString();
    return s.length > 240 ? s.substring(0, 240) : s;
  }

  void _cancelFriendsSub() {
    _friendsSub?.cancel();
    _friendsSub = null;
  }

  void _cancelActivitiesSub() {
    _activitiesSub?.cancel();
    _activitiesSub = null;
  }

  void stop() {
    _authSub?.cancel();
    _authSub = null;
    _cancelFriendsSub();
    _cancelActivitiesSub();
    _started = false;
    _setLoadingFriends(false);
    _setLoadingActivities(false);
    _setError(null);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
