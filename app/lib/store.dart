import 'package:flutter/foundation.dart';

import 'api.dart';

class HubStore extends ChangeNotifier {
  HubStore({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  List<HubTask> tasks = [];
  List<Proposal> proposals = [];
  List<HubNotice> notices = [];
  Map<String, dynamic> config = {};
  Map<String, dynamic>? user;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await api.trackView('catalog');
      final results = await Future.wait([
        api.tasks(),
        api.proposals(),
        api.notifications('business'),
        api.config(),
      ]);
      tasks = results[0] as List<HubTask>;
      proposals = results[1] as List<Proposal>;
      notices = results[2] as List<HubNotice>;
      config = results[3] as Map<String, dynamic>;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();
  Future<void> authenticate(String mode, Map<String, dynamic> values) async {
    user = await api.authenticate(mode, values);
    await load();
  }
  Future<void> updateProfile(Map<String, dynamic> values) async {
    user = await api.updateProfile(values);
    notifyListeners();
  }
  Future<void> changePassword(Map<String, dynamic> values) async {
    user = await api.changePassword(values);
    notifyListeners();
  }
  void logout() {
    api.accessToken = null;
    user = null;
    tasks = [];
    proposals = [];
    notices = [];
    error = null;
    notifyListeners();
  }
  Future<void> publish(Map<String, dynamic> fields) async {
    await api.createTask(fields);
    await load();
  }
  Future<Map<String, dynamic>> apply(String taskId, Map<String, dynamic> fields) async {
    final result = await api.createResponse(taskId, fields);
    await load();
    return result;
  }
  Future<void> choose(Proposal proposal, String status) async {
    await api.decide(proposal.id, status);
    await load();
  }
}
