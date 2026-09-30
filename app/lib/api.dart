import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String get apiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000'; // Android emulator.
  return 'http://127.0.0.1:8000'; // Desktop and iOS simulator; physical devices need a LAN address.
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  static final math.Random _random = math.Random.secure();
  final http.Client _client;
  final String _viewerKey = List<int>.generate(16, (_) => _random.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  String? accessToken;
  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (accessToken != null) 'authorization': 'Bearer $accessToken',
      };

  Future<dynamic> _decode(http.Response response) async {
    final dynamic body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map ? body['detail'] : null;
      throw ApiException(detail?.toString() ?? 'Сервер вернул ошибку ${response.statusCode}');
    }
    return body;
  }

  Future<dynamic> get(String path) async => _decode(await _client.get(_uri(path), headers: _headers));
  Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _decode(await _client.post(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> patch(String path, Map<String, dynamic> body) async =>
      _decode(await _client.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<void> trackView(String page) async {
    try {
      await _client.post(_uri('/api/metrics/view'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'viewer_key': _viewerKey, 'page': page}));
    } catch (_) {
      // Analytics must never block the app if the counter endpoint is unavailable.
    }
  }

  Future<Map<String, dynamic>> authenticate(String mode, Map<String, dynamic> values) async {
    await trackView('login');
    final response = Map<String, dynamic>.from(await post('/api/auth/$mode', values) as Map);
    accessToken = response['access_token']?.toString();
    return Map<String, dynamic>.from(response['user'] as Map);
  }
  Future<Map<String, dynamic>> register(Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(await post('/api/auth/register', values) as Map);
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> values) async {
    final result = Map<String, dynamic>.from(await patch('/api/auth/profile', values) as Map);
    return Map<String, dynamic>.from(result['user'] as Map);
  }
  Future<Map<String, dynamic>> changePassword(Map<String, dynamic> values) async {
    final result = Map<String, dynamic>.from(await patch('/api/auth/password', values) as Map);
    accessToken = result['access_token']?.toString();
    return Map<String, dynamic>.from(result['user'] as Map);
  }

  Future<List<HubTask>> tasks() async => (await get('/api/tasks') as List)
      .map((e) => HubTask.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<List<Proposal>> proposals() async => (await get('/api/responses') as List)
      .map((e) => Proposal.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<List<HubNotice>> notifications(String audience) async => (await get('/api/notifications?audience=$audience') as List)
      .map((e) => HubNotice.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<Map<String, dynamic>> config() async => Map<String, dynamic>.from(await get('/api/config') as Map);
  Future<HubTask> task(String id) async {
    await trackView('task:$id');
    return HubTask.fromJson(Map<String, dynamic>.from(await get('/api/tasks/$id') as Map));
  }
  Future<List<Proposal>> taskProposals(String id) async => (await get('/api/tasks/$id/responses') as List)
      .map((e) => Proposal.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  Future<Map<String, dynamic>> refine(String draft) async => Map<String, dynamic>.from(await post('/api/ai/refine', {'draft': draft}) as Map);
  Future<Map<String, dynamic>> organize(String draft, Map<String, String> answers) async =>
      Map<String, dynamic>.from(await post('/api/ai/organize', {'draft': draft, 'answers': answers}) as Map);
  Future<HubTask> createTask(Map<String, dynamic> fields) async =>
      HubTask.fromJson(Map<String, dynamic>.from(await post('/api/tasks', fields) as Map));
  Future<Map<String, dynamic>> createResponse(String taskId, Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await post('/api/tasks/$taskId/responses', fields) as Map);
  Future<void> decide(String responseId, String status) async {
    await patch('/api/responses/$responseId/decision', {'status': status});
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HubTask {
  HubTask(this.raw);
  final Map<String, dynamic> raw;
  factory HubTask.fromJson(Map<String, dynamic> json) => HubTask(json);
  String get id => raw['id']?.toString() ?? '';
  String get title => raw['title']?.toString() ?? 'Новая задача';
  String get company => raw['company']?.toString() ?? 'Бизнес-партнёр';
  String get topic => raw['topic']?.toString() ?? 'Образование';
  String get context => raw['context']?.toString() ?? '';
  String get need => raw['need']?.toString() ?? '';
  String get users => raw['users']?.toString() ?? '';
  String get data => raw['data']?.toString() ?? '';
  String get result => raw['result']?.toString() ?? '';
  String get success => raw['success']?.toString() ?? '';
  String get constraints => raw['constraints']?.toString() ?? '';
  String get contact => raw['contact']?.toString() ?? '';
  int get score => ((raw['readiness'] as Map?)?['score'] as num?)?.toInt() ?? 0;
  String get level => (raw['readiness'] as Map?)?['level']?.toString() ?? 'Черновик';
  int get responseCount => (raw['response_count'] as num?)?.toInt() ?? 0;
}

class Proposal {
  Proposal(this.raw);
  final Map<String, dynamic> raw;
  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(json);
  String get id => raw['id']?.toString() ?? '';
  String get taskId => raw['task_id']?.toString() ?? '';
  String get taskTitle => raw['task_title']?.toString() ?? 'Задача';
  String get company => raw['company']?.toString() ?? 'Бизнес-партнёр';
  String get team => raw['team']?.toString() ?? 'Команда';
  String get idea => raw['idea']?.toString() ?? '';
  String get plan => raw['plan']?.toString() ?? '';
  String get timeline => raw['timeline']?.toString() ?? '';
  String get status => raw['status']?.toString() ?? 'pending';
}

class HubNotice {
  HubNotice(this.raw);
  final Map<String, dynamic> raw;
  factory HubNotice.fromJson(Map<String, dynamic> json) => HubNotice(json);
  String get title => raw['title']?.toString() ?? 'Уведомление';
  String get message => raw['message']?.toString() ?? '';
  String get audience => raw['audience']?.toString() ?? 'business';
  String get createdAt => raw['created_at']?.toString() ?? '';
}
