import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'models.dart';
import 'session_store.dart';

/// Single source of truth for the notification badge and list.
///
/// Connects to the backend socket whenever a session token exists and falls
/// back to polling-free HTTP refreshes when the socket is reconnecting.
class NotificationHub extends ChangeNotifier {
  NotificationHub._();
  static final NotificationHub instance = NotificationHub._();

  static const _maxItems = 100;

  final List<MarketplaceNotification> _items = [];
  final StreamController<MarketplaceMessage> _messages =
      StreamController.broadcast();
  int _unreadCount = 0;
  bool _loading = false;
  bool _refreshing = false;
  Object? _error;
  bool _started = false;
  bool _connected = false;
  String? _socketToken;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  int _attempt = 0;

  List<MarketplaceNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  Object? get error => _error;
  bool get isConnected => _connected;

  /// Chat messages pushed over the same socket, in arrival order.
  Stream<MarketplaceMessage> get messageEvents => _messages.stream;

  void start() {
    if (_started) return;
    _started = true;
    SessionStore.instance.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  Future<void> refresh() async {
    if (!SessionStore.instance.isAuthenticated || _refreshing) return;
    _refreshing = true;
    if (_items.isEmpty && _unreadCount == 0) {
      _loading = true;
      notifyListeners();
    }
    try {
      final countFuture = api.unreadNotificationCount(silent: true);
      final page = await api.notifications(silent: true);
      final count = await countFuture;
      _items
        ..clear()
        ..addAll(page.items.take(_maxItems));
      _unreadCount = count;
      _error = null;
    } catch (error) {
      _error = error;
    } finally {
      _refreshing = false;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;
    final previous = _items[index];
    _items[index] = previous.withRead(true);
    _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    notifyListeners();
    try {
      await api.markNotificationRead(id, silent: true);
    } catch (_) {
      _replace(previous);
      _unreadCount += 1;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    if (_items.every((item) => item.isRead) && _unreadCount == 0) return;
    final snapshot = List<MarketplaceNotification>.of(_items);
    final previousCount = _unreadCount;
    for (var index = 0; index < _items.length; index++) {
      if (!_items[index].isRead) {
        _items[index] = _items[index].withRead(true);
      }
    }
    _unreadCount = 0;
    notifyListeners();
    try {
      await api.markAllNotificationsRead(silent: true);
    } catch (_) {
      _items
        ..clear()
        ..addAll(snapshot);
      _unreadCount = previousCount;
      notifyListeners();
      rethrow;
    }
  }

  void _replace(MarketplaceNotification item) {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) _items[index] = item;
  }

  void _onSessionChanged() {
    final session = SessionStore.instance;
    final token = session.token;
    if (session.isAuthenticated && token != null && token.isNotEmpty) {
      if (_socketToken != token) {
        _socketToken = token;
        _connect(token);
      }
      unawaited(refresh());
    } else {
      _socketToken = null;
      _reconnect?.cancel();
      _reconnect = null;
      _closeSocket();
      _reset();
    }
  }

  void _reset() {
    if (_items.isEmpty && _unreadCount == 0 && _error == null) return;
    _items.clear();
    _unreadCount = 0;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  void _connect(String token) {
    _closeSocket();
    final uri = _socketUri(token);
    if (uri == null) return;
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      unawaited(
        channel.ready.then((_) {
          if (_channel != channel) return;
          _attempt = 0;
          _connected = true;
          notifyListeners();
        }, onError: (Object _) => _scheduleReconnect(channel)),
      );
      _subscription = channel.stream.listen(
        _handleMessage,
        onDone: () => _scheduleReconnect(channel),
        onError: (Object _) => _scheduleReconnect(channel),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect([WebSocketChannel? source]) {
    // Ignore late events from a socket that has already been replaced.
    if (source != null && source != _channel) return;
    _closeSocket();
    if (!SessionStore.instance.isAuthenticated) return;
    if (_reconnect?.isActive == true) return;
    const delays = [1, 2, 5, 10, 20, 30];
    final seconds = delays[_attempt.clamp(0, delays.length - 1)];
    _attempt += 1;
    _reconnect = Timer(Duration(seconds: seconds), () {
      _reconnect = null;
      final token = SessionStore.instance.token;
      if (SessionStore.instance.isAuthenticated &&
          token != null &&
          token.isNotEmpty) {
        _connect(token);
      }
    });
  }

  void _closeSocket() {
    _connected = false;
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close());
  }

  Uri? _socketUri(String token) {
    final base = Uri.tryParse(api.baseUrl);
    if (base == null || base.host.isEmpty) return null;
    final segments = base.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    while (segments.isNotEmpty && segments.last == 'v1') {
      segments.removeLast();
    }
    while (segments.isNotEmpty && segments.last == 'api') {
      segments.removeLast();
    }
    segments.addAll(const ['ws', 'notifications']);
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/${segments.join('/')}',
      queryParameters: {'token': token},
    );
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final payload = Map<String, dynamic>.from(decoded);
    switch (payload['event']) {
      case 'connected':
        _connected = true;
        _attempt = 0;
        notifyListeners();
        unawaited(refresh());
      case 'notification.created':
        final data = payload['notification'];
        if (data is! Map) return;
        _insert(
          MarketplaceNotification.fromJson(Map<String, dynamic>.from(data)),
        );
        _unreadCount = _count(payload['unreadCount'], _unreadCount + 1);
        notifyListeners();
      case 'notification.read':
        final id = _id(payload['id']);
        if (id == null) return;
        _setRead(id);
        _unreadCount = _count(payload['unreadCount'], _unreadCount);
        notifyListeners();
      case 'notification.read-all':
        for (var index = 0; index < _items.length; index++) {
          if (!_items[index].isRead) {
            _items[index] = _items[index].withRead(true);
          }
        }
        _unreadCount = 0;
        notifyListeners();
      case 'message.created':
        final data = payload['message'];
        if (data is! Map) return;
        _messages.add(
          MarketplaceMessage.fromJson(Map<String, dynamic>.from(data)),
        );
    }
  }

  void _insert(MarketplaceNotification item) {
    _items.removeWhere((existing) => existing.id == item.id);
    _items.insert(0, item);
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
  }

  void _setRead(int id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0 && !_items[index].isRead) {
      _items[index] = _items[index].withRead(true);
    }
  }

  int? _id(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  int _count(Object? value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }
}
