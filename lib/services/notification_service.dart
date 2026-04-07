import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification_model.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'default_notification_channel_id',
    'Gatherly Notifications',
    description: 'Notifications from Gatherly',
    importance: Importance.high,
  );

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _notificationTriggerSub;
  String? _boundUserId;
  bool _isInitialized = false;
  bool _notificationsPrimed = false;
  final Set<String> _seenNotificationIds = <String>{};

  CollectionReference<Map<String, dynamic>> _userNotifications(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<List<AppNotificationModel>> streamNotifications(String uid,
      {int limit = 100}) {
    return _userNotifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(AppNotificationModel.fromDoc).toList();
    });
  }

  Stream<int> streamUnreadCount(String uid) {
    return _userNotifications(uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.length;
    });
  }

  Future<void> addNotificationToUser({
    required String userId,
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.general,
    String? eventId,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) return;

    await _userNotifications(userId).add({
      'userId': userId,
      'title': cleanTitle,
      'body': cleanBody,
      'type': type.value,
      'eventId': eventId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addNotificationToUsers({
    required Iterable<String> userIds,
    required String title,
    required String body,
    AppNotificationType type = AppNotificationType.general,
    String? eventId,
  }) async {
    final unique =
        userIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (unique.isEmpty) return;

    for (final uid in unique) {
      await addNotificationToUser(
        userId: uid,
        title: title,
        body: body,
        type: type,
        eventId: eventId,
      );
    }
  }

  Future<void> markAsRead(
      {required String uid, required String notificationId}) async {
    await _userNotifications(uid).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String uid) async {
    final unread = await _userNotifications(uid)
        .where('isRead', isEqualTo: false)
        .limit(400)
        .get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> configureForSignedInUser(User user) async {
    await initialize();

    final isSameUser = _boundUserId == user.uid;
    _boundUserId = user.uid;

    if (!isSameUser) {
      await _notificationTriggerSub?.cancel();
      _notificationTriggerSub = null;
      _notificationsPrimed = false;
      _seenNotificationIds.clear();
    }

    if (_notificationTriggerSub == null) {
      _startLocalTriggerFromFirestore(user.uid);
    }
  }

  Future<void> clearSession() async {
    _boundUserId = null;

    await _notificationTriggerSub?.cancel();
    _notificationTriggerSub = null;
    _notificationsPrimed = false;
    _seenNotificationIds.clear();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    final androidPermissions =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPermissions?.requestNotificationsPermission();

    final iosPermissions =
        _localNotifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPermissions?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macPermissions =
        _localNotifications.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    await macPermissions?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _startLocalTriggerFromFirestore(String uid) {
    _notificationTriggerSub = _userNotifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .listen((snapshot) {
      if (!_notificationsPrimed) {
        for (final doc in snapshot.docs) {
          _seenNotificationIds.add(doc.id);
        }
        _notificationsPrimed = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        if (_seenNotificationIds.contains(change.doc.id)) continue;
        _seenNotificationIds.add(change.doc.id);

        final data = change.doc.data();
        if (data == null) continue;

        final title = (data['title'] as String? ?? '').trim();
        final body = (data['body'] as String? ?? '').trim();

        if (title.isEmpty || body.isEmpty) continue;
        unawaited(_showLocalNotification(
          title: title,
          body: body,
          payload: change.doc.id,
        ));
      }
    }, onError: (error) {
      debugPrint('Notification trigger listener failed: $error');
    });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'default_notification_channel_id',
        'Gatherly Notifications',
        channelDescription: 'Notifications from Gatherly',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
