import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'store.dart';

const ink = Color(0xFF242320);
const muted = Color(0xFF85847F);
const paper = Color(0xFFFFFEFC);
const canvas = Color(0xFFF7F6F2);
const line = Color(0xFFEAE8E2);
const violet = Color(0xFF6855E8);
const violetPale = Color(0xFFF0EDFF);
const lime = Color(0xFFDFF681);
const green = Color(0xFF277454);

void main() {
  runApp(ChangeNotifierProvider(create: (_) => HubStore(), child: const SanaApp()));
}

class SanaApp extends StatelessWidget {
  const SanaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AI Sana Challenge Hub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          colorScheme: ColorScheme.fromSeed(seedColor: violet, surface: paper, primary: violet),
          fontFamily: 'Arial',
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontSize: 38, height: 1.12, letterSpacing: -1.6, fontWeight: FontWeight.w800, color: ink),
            headlineMedium: TextStyle(fontSize: 29, height: 1.16, letterSpacing: -1, fontWeight: FontWeight.w800, color: ink),
            titleLarge: TextStyle(fontSize: 20, letterSpacing: -.45, fontWeight: FontWeight.w700, color: ink),
            titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
            bodyLarge: TextStyle(fontSize: 15, height: 1.58, color: ink),
            bodyMedium: TextStyle(fontSize: 13, height: 1.55, color: muted),
            labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: paper,
            hintStyle: const TextStyle(color: Color(0xFFAAA9A3), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: violet, width: 1.4)),
          ),
          cardTheme: CardThemeData(color: paper, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line))),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: violet, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
          outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), side: const BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
        ),
        home: const HubShell(),
      );
}

class _AuthView extends StatefulWidget {
  const _AuthView();
  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registering = false;
  bool working = false;
  bool privacyConsent = false;
  String role = 'student';
  String? error;
  String? notice;

  @override
  void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    setState(() { working = true; error = null; notice = null; });
    try {
      final values = <String, dynamic>{'email': email.text.trim(), 'password': password.text};
      if (registering) {
        if (!privacyConsent) throw Exception('Подтвердите согласие на обработку данных.');
        values['name'] = name.text.trim(); values['role'] = role; values['privacy_consent'] = true;
        final result = await context.read<HubStore>().api.register(values);
        setState(() => notice = '${result['message'] ?? 'Проверьте почту.'}${result['local_link_in_server_log'] == true ? ' Ссылка напечатана в терминале сервера.' : ' Проверьте входящие и папку «Спам».'}');
      } else {
        await context.read<HubStore>().authenticate('login', values);
      }
    } catch (e) { setState(() => error = e.toString()); }
    if (mounted) setState(() => working = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440), child: Card(child: Padding(
        padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: violet, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 21)), const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AI Sana', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), Text('CHALLENGE HUB', style: TextStyle(fontSize: 9, letterSpacing: 1, color: muted))])]),
          const SizedBox(height: 27), Text(registering ? 'Создайте аккаунт' : 'С возвращением', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), Text(registering ? 'Бизнес публикует задачи, студенты предлагают решения.' : 'Войдите, чтобы открыть задачи и отклики.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18), SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Войти')), ButtonSegment(value: true, label: Text('Регистрация'))], selected: {registering}, onSelectionChanged: (value) => setState(() { registering = value.first; error = null; notice = null; privacyConsent = false; })),
          if (registering) ...[const SizedBox(height: 13), TextField(controller: name, decoration: const InputDecoration(labelText: 'Ваше имя или команда'))],
          const SizedBox(height: 13), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Электронная почта')),
          const SizedBox(height: 13), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль (от 8 символов)')),
          if (registering) ...[const SizedBox(height: 13), DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'Роль'), items: const [DropdownMenuItem(value: 'student', child: Text('Студент / команда')), DropdownMenuItem(value: 'business', child: Text('Представитель бизнеса'))], onChanged: (value) => setState(() => role = value ?? 'student')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: privacyConsent, onChanged: (value) => setState(() => privacyConsent = value ?? false), title: const Text('Согласен(на) на обработку данных', style: TextStyle(fontSize: 12))),
            TextButton(onPressed: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => const Padding(padding: EdgeInsets.all(22), child: SingleChildScrollView(child: Text('AI Sana Hub сохраняет имя или название команды, почту, выбранную роль, хэш пароля и дату/версию согласия для работы аккаунта, подтверждения почты и взаимодействия по задачам. Карточки и отклики видны в рабочем процессе участникам соответствующих ролей. База и почтовый провайдер задаются владельцем сервиса. Контакт оператора и срок хранения должны быть заполнены организаторами в политике проекта до публичного запуска.', style: TextStyle(height: 1.5))))), child: const Text('Прочитать соглашение и политику'))],
          if (notice != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(notice!, style: const TextStyle(color: green, fontSize: 12))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 16), FilledButton(onPressed: working ? null : submit, child: Text(working ? 'Подождите…' : registering ? 'Создать аккаунт' : 'Войти')),
          const SizedBox(height: 10), const Text('Профиль сохраняется в базе проекта.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11)),
        ]),
      )),
    ))),
  );
}

enum HubPage { catalog, create, inbox, proposals, profile, detail }

class HubShell extends StatefulWidget {
  const HubShell({super.key});
  @override
  State<HubShell> createState() => _HubShellState();
}

class _HubShellState extends State<HubShell> {
  HubPage page = HubPage.catalog;
  String? taskId;

  void go(HubPage next) => setState(() => page = next);
  void openTask(HubTask task) => setState(() { taskId = task.id; page = HubPage.detail; });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HubStore>();
    if (store.user == null) return const _AuthView();
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;
    final compact = width < 700;
    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          if (desktop) _Sidebar(page: page, onSelect: go),
          Expanded(child: Column(children: [
            _Topbar(page: page, onRefresh: () => context.read<HubStore>().reload()),
            Expanded(child: _pageBody()),
          ])),
        ]),
      ),
      bottomNavigationBar: compact ? NavigationBar(
        selectedIndex: _navIndex(page),
        onDestinationSelected: (index) => go(_pageAt(index)),
        backgroundColor: paper,
        indicatorColor: violetPale,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Задачи'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Создать'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: 'Входящие'),
          NavigationDestination(icon: Icon(Icons.send_outlined), label: 'Отклики'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Профиль'),
        ],
      ) : null,
    );
  }

  Widget _pageBody() {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1200 ? 46.0 : width >= 700 ? 30.0 : 17.0;
    final child = switch (page) {
      HubPage.catalog => CatalogView(onOpen: openTask, onCreate: () => go(HubPage.create)),
      HubPage.create => WizardView(onPublished: () => go(HubPage.catalog)),
      HubPage.inbox => InboxView(onOpen: (id) { final t = context.read<HubStore>().tasks.where((e) => e.id == id).firstOrNull; if (t != null) openTask(t); }),
      HubPage.proposals => ProposalsView(),
      HubPage.profile => const ProfileView(),
      HubPage.detail => TaskDetailView(taskId: taskId ?? '', onBack: () => go(HubPage.catalog)),
    };
    return Align(alignment: Alignment.topCenter, child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1280),
      child: Padding(padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 34), child: child),
    ));
  }

  int _navIndex(HubPage p) => switch (p) { HubPage.create => 1, HubPage.inbox => 2, HubPage.proposals => 3, HubPage.profile => 4, _ => 0 };
  HubPage _pageAt(int index) => switch (index) { 1 => HubPage.create, 2 => HubPage.inbox, 3 => HubPage.proposals, 4 => HubPage.profile, _ => HubPage.catalog };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.page, required this.onSelect});
  final HubPage page;
  final ValueChanged<HubPage> onSelect;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<HubStore>();
    return Container(width: 244, decoration: const BoxDecoration(color: paper, border: Border(right: BorderSide(color: line))), padding: const EdgeInsets.fromLTRB(18, 22, 14, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 35, height: 35, decoration: BoxDecoration(color: violet, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19)), const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AI Sana', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink)), Text('CHALLENGE HUB', style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: muted, fontWeight: FontWeight.w700))])]),
      const SizedBox(height: 34),
      const Padding(padding: EdgeInsets.only(left: 11, bottom: 9), child: Text('РАБОЧЕЕ ПРОСТРАНСТВО', style: TextStyle(fontSize: 9, letterSpacing: 1, color: muted, fontWeight: FontWeight.w700))),
      _NavButton(icon: Icons.grid_view_rounded, label: 'Каталог задач', active: page == HubPage.catalog || page == HubPage.detail, onTap: () => onSelect(HubPage.catalog)),
      _NavButton(icon: Icons.add_box_outlined, label: 'Создать задачу', active: page == HubPage.create, onTap: () => onSelect(HubPage.create)),
      _NavButton(icon: Icons.notifications_none_rounded, label: 'Входящие', active: page == HubPage.inbox, count: store.notices.length, onTap: () => onSelect(HubPage.inbox)),
      _NavButton(icon: Icons.send_outlined, label: 'Предложения команд', active: page == HubPage.proposals, onTap: () => onSelect(HubPage.proposals)),
      _NavButton(icon: Icons.person_outline_rounded, label: 'Мой профиль', active: page == HubPage.profile, onTap: () => onSelect(HubPage.profile)),
      const Spacer(),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(store.config['ai_enabled'] == true ? Icons.key_rounded : Icons.auto_awesome_outlined, size: 15, color: store.config['ai_enabled'] == true ? green : violet), const SizedBox(width: 6), Text(store.config['ai_enabled'] == true ? 'API-ключ настроен' : 'AI демо-режим', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: ink))]),
        const SizedBox(height: 7), Text('Хорошая задача начинается с ясного брифа.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.4)),
      ])),
      const SizedBox(height: 13),
      const Row(children: [CircleAvatar(radius: 16, backgroundColor: violetPale, child: Text('AS', style: TextStyle(fontSize: 10, color: violet, fontWeight: FontWeight.w800))), SizedBox(width: 9), Expanded(child: Text('Команда AI Sana\nМНВО · образовательные проекты', style: TextStyle(fontSize: 10, height: 1.45, color: muted)))]),
    ]));
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.active, required this.onTap, this.count = 0});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Material(color: active ? violetPale : Colors.transparent, borderRadius: BorderRadius.circular(10), child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11), child: Row(children: [Icon(icon, size: 18, color: active ? violet : muted), const SizedBox(width: 10), Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? violet : ink))), if (count > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: active ? Colors.white : canvas, borderRadius: BorderRadius.circular(12)), child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: violet)))])))));
}

class _Topbar extends StatelessWidget {
  const _Topbar({required this.page, required this.onRefresh});
  final HubPage page;
  final VoidCallback onRefresh;
  String get label => switch (page) { HubPage.catalog => 'ПРОСТРАНСТВО ПРОЕКТОВ', HubPage.create => 'НОВЫЙ БИЗНЕС-БРИФ', HubPage.inbox => 'УВЕДОМЛЕНИЯ', HubPage.proposals => 'КОМАНДЫ И ПРЕДЛОЖЕНИЯ', HubPage.profile => 'МОЙ ПРОФИЛЬ', HubPage.detail => 'КАРТОЧКА ЗАДАЧИ' };
  @override
  Widget build(BuildContext context) => Container(height: 62, decoration: const BoxDecoration(color: paper, border: Border(bottom: BorderSide(color: line))), padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [Text(label, style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w700, fontSize: 9, color: muted)), const Spacer(), IconButton(tooltip: 'Обновить данные', onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, size: 19, color: muted)), IconButton(tooltip: 'Выйти', onPressed: () => context.read<HubStore>().logout(), icon: const Icon(Icons.logout_rounded, size: 18, color: muted))]));
}

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _profileCurrent = TextEditingController();
  final _passwordCurrent = TextEditingController();
  final _passwordNew = TextEditingController();
  final _passwordRepeat = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _profileError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final user = context.read<HubStore>().user ?? {};
    _name = TextEditingController(text: user['name']?.toString() ?? '');
    _email = TextEditingController(text: user['email']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _profileCurrent.dispose();
    _passwordCurrent.dispose(); _passwordNew.dispose(); _passwordRepeat.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    setState(() { _savingProfile = true; _profileError = null; });
    try {
      await context.read<HubStore>().updateProfile({
        'name': _name.text.trim(), 'email': _email.text.trim(),
        'current_password': _profileCurrent.text,
      });
      _profileCurrent.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль сохранён.')));
    } catch (error) {
      if (mounted) setState(() => _profileError = error.toString());
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    if (_passwordNew.text != _passwordRepeat.text) {
      setState(() => _passwordError = 'Новые пароли не совпадают.');
      return;
    }
    setState(() { _savingPassword = true; _passwordError = null; });
    try {
      await context.read<HubStore>().changePassword({
        'current_password': _passwordCurrent.text,
        'new_password': _passwordNew.text,
      });
      _passwordCurrent.clear(); _passwordNew.clear(); _passwordRepeat.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль изменён.')));
    } catch (error) {
      if (mounted) setState(() => _passwordError = error.toString());
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Widget _message(String? text) => text == null ? const SizedBox.shrink() : Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(text, style: const TextStyle(color: Colors.red, fontSize: 12)),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<HubStore>().user ?? {};
    final name = user['name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Мой профиль', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text('Меняйте имя, почту и пароль своего аккаунта.', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        CircleAvatar(radius: 25, backgroundColor: violetPale, child: Text(name.isEmpty ? 'AI' : name.substring(0, 1).toUpperCase(), style: const TextStyle(color: violet, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), Text(email, style: const TextStyle(color: muted, fontSize: 12))])),
      ]))),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Form(key: _profileKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Имя и почта', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(controller: _name, maxLength: 80, decoration: const InputDecoration(labelText: 'Имя или никнейм'), validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Введите минимум 2 символа.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Электронная почта'), validator: (value) => !(value ?? '').contains('@') || !(value ?? '').split('@').last.contains('.') ? 'Введите корректную почту.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _profileCurrent, obscureText: true, decoration: const InputDecoration(labelText: 'Текущий пароль для подтверждения'), validator: (value) => (value?.length ?? 0) < 8 ? 'Пароль должен содержать минимум 8 символов.' : null),
        const SizedBox(height: 8),
        Text('Новая почта действует сразу. Подтверждение письмом сейчас отключено.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        _message(_profileError),
        const SizedBox(height: 8),
        FilledButton(onPressed: _savingProfile ? null : _saveProfile, child: Text(_savingProfile ? 'Сохраняем…' : 'Сохранить изменения')),
      ])))),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Form(key: _passwordKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Смена пароля', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(controller: _passwordCurrent, obscureText: true, decoration: const InputDecoration(labelText: 'Текущий пароль'), validator: (value) => (value?.length ?? 0) < 8 ? 'Введите текущий пароль.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _passwordNew, obscureText: true, decoration: const InputDecoration(labelText: 'Новый пароль'), validator: (value) => (value?.length ?? 0) < 8 ? 'Нужно минимум 8 символов.' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _passwordRepeat, obscureText: true, decoration: const InputDecoration(labelText: 'Повторите новый пароль'), validator: (value) => (value?.length ?? 0) < 8 ? 'Повторите новый пароль.' : null),
        _message(_passwordError),
        const SizedBox(height: 8),
        FilledButton(onPressed: _savingPassword ? null : _savePassword, child: Text(_savingPassword ? 'Меняем пароль…' : 'Изменить пароль')),
      ])))),
    ]));
  }
}

class CatalogView extends StatefulWidget {
  const CatalogView({required this.onOpen, required this.onCreate, super.key});
  final ValueChanged<HubTask> onOpen;
  final VoidCallback onCreate;
  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  String query = '';
  String topic = 'Все темы';
  @override
  Widget build(BuildContext context) {
    final store = context.watch<HubStore>();
    if (store.loading && store.tasks.isEmpty) return const Center(child: CircularProgressIndicator(color: violet));
    if (store.error != null && store.tasks.isEmpty) return _OfflineState(error: store.error!, onRetry: store.reload);
    final choices = ['Все темы', ...store.tasks.map((t) => t.topic).toSet()];
    final visible = store.tasks.where((t) => (topic == 'Все темы' || t.topic == topic) && '${t.title} ${t.company} ${t.context}'.toLowerCase().contains(query.toLowerCase())).toList()..sort((a, b) => b.score.compareTo(a.score));
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1150 ? 3 : width > 790 ? 2 : 1;
    return RefreshIndicator(color: violet, onRefresh: store.reload, child: ListView(children: [
      _HeroPanel(taskCount: store.tasks.length, onCreate: widget.onCreate),
      const SizedBox(height: 25),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Eyebrow('ЖИВЫЕ ОБРАЗОВАТЕЛЬНЫЕ ЗАДАЧИ'), const SizedBox(height: 7), Text('Найдите задачу\nсвоей команды', style: Theme.of(context).textTheme.headlineMedium)])),
        if (width >= 600) _TinyMetric(icon: Icons.work_outline_rounded, value: '${store.tasks.length}', label: 'задач в каталоге'),
      ]),
      const SizedBox(height: 17),
      Wrap(spacing: 9, runSpacing: 9, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: width < 680 ? width - 35 : 280, child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded, size: 19), hintText: 'Поиск по задачам', contentPadding: EdgeInsets.symmetric(vertical: 11)), onChanged: (v) => setState(() => query = v))),
        ...choices.take(width < 600 ? 3 : 6).map((choice) => ChoiceChip(label: Text(choice), selected: topic == choice, onSelected: (_) => setState(() => topic = choice), showCheckmark: false, selectedColor: violetPale, backgroundColor: paper, side: BorderSide(color: topic == choice ? violet.withValues(alpha: .2) : line), labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: topic == choice ? violet : muted))),
      ]),
      const SizedBox(height: 14),
      if (visible.isEmpty) const _EmptyBlock(title: 'Подходящих задач пока нет', detail: 'Измените поиск или выберите другую тему.'),
      _AdaptiveGrid(columns: columns, children: visible.map((task) => TaskCard(task: task, onTap: () => widget.onOpen(task))).toList()),
      const SizedBox(height: 22),
      const _ClarityStrip(),
      const SizedBox(height: 28),
      const Row(children: [Eyebrow('ПРОСТОЙ ПУТЬ ОТ ВОПРОСА К ПРОЕКТУ')]),
      const SizedBox(height: 12),
      const _StepsRow(),
    ]));
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.taskCount, required this.onCreate});
  final int taskCount;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF312A6E), Color(0xFF6755DC), Color(0xFF8979EF)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Stack(children: [
      Positioned(right: -40, top: -86, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .08), width: 35)))),
      Padding(padding: EdgeInsets.all(width < 600 ? 20 : 30), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.auto_awesome_rounded, size: 14, color: lime), const SizedBox(width: 7), Text('МНВО  /  AI SANA', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1))]),
          const SizedBox(height: 13),
          Text('Большие идеи\nначинаются с ясной\nзадачи.', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontSize: width < 600 ? 27 : 35, height: 1.05)),
          const SizedBox(height: 11),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 470), child: Text('Превратите реальную потребность бизнеса в понятный проект для студенческой команды.', style: TextStyle(color: Colors.white.withValues(alpha: .78), height: 1.55, fontSize: 13))),
          const SizedBox(height: 17),
          FilledButton.icon(onPressed: onCreate, style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)), icon: const Icon(Icons.add_rounded, size: 17), label: const Text('Сформулировать задачу')),
        ])),
        if (width >= 790) const SizedBox(width: 10),
        if (width >= 790) _HeroBriefCard(taskCount: taskCount),
      ])),
    ]));
  }
}

class _HeroBriefCard extends StatelessWidget {
  const _HeroBriefCard({required this.taskCount});
  final int taskCount;
  @override
  Widget build(BuildContext context) => Container(width: 246, padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .11), border: Border.all(color: Colors.white.withValues(alpha: .18)), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Icon(Icons.bubble_chart_outlined, color: lime, size: 17), const SizedBox(width: 7), Text('ПАСПОРТ ЯСНОСТИ', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 9, letterSpacing: .8, fontWeight: FontWeight.w800))]),
    const SizedBox(height: 14), const Text('Задача готова к старту?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
    const SizedBox(height: 12), _miniLine('Цель и потребность', true), _miniLine('Данные и ограничения', true), _miniLine('Результат и критерии', false),
    const SizedBox(height: 14), Row(children: [Text('$taskCount', style: const TextStyle(color: lime, fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -1)), const SizedBox(width: 7), Text('открытых задач\nдля команд', style: TextStyle(color: Colors.white.withValues(alpha: .73), fontSize: 10, height: 1.35))]),
  ]));
  Widget _miniLine(String text, bool checked) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 13, color: checked ? lime : Colors.white70), const SizedBox(width: 7), Text(text, style: const TextStyle(fontSize: 10, color: Colors.white))]));
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.icon, required this.value, required this.label});
  final IconData icon; final String value; final String label;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: violetPale, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: violet)), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ink)), Text(label, style: const TextStyle(color: muted, fontSize: 9))])]);
}

class TaskCard extends StatelessWidget {
  const TaskCard({required this.task, required this.onTap, super.key});
  final HubTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = task.score >= 70 ? green : const Color(0xFF9A6B25);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: _Pill(task.topic, color: violet, bg: violetPale)), const SizedBox(width: 7), Icon(Icons.north_east_rounded, size: 17, color: muted)]),
      const SizedBox(height: 15),
      Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17, height: 1.25)),
      const SizedBox(height: 6), Text(task.company, style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 11), Text(task.need.isNotEmpty ? task.need : task.context, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.48, color: Color(0xFF686761))),
      const SizedBox(height: 16),
      Row(children: [Text('ЯСНОСТЬ БРИФА', style: TextStyle(fontSize: 9, letterSpacing: .7, color: muted, fontWeight: FontWeight.w800)), const Spacer(), Text('${task.score}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)), const Text(' / 100', style: TextStyle(color: muted, fontSize: 10))]),
      const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: task.score / 100, minHeight: 5, backgroundColor: const Color(0xFFF0EFEA), color: color)),
      const SizedBox(height: 13), Row(children: [const Icon(Icons.forum_outlined, size: 14, color: muted), const SizedBox(width: 5), Text('${task.responseCount} предложений', style: const TextStyle(fontSize: 10, color: muted)), const Spacer(), Text(task.level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)), const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, size: 16, color: muted)]),
    ]))));
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.bg = violetPale, this.color = violet});
  final String text; final Color bg; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis));
}

class _AdaptiveGrid extends StatelessWidget {
  const _AdaptiveGrid({required this.children, required this.columns});
  final List<Widget> children; final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    if (children.isEmpty) return const SizedBox.shrink();
    final ratio = columns == 3 ? 1.12 : columns == 2 ? 1.28 : (constraints.maxWidth / 285).clamp(1.0, 2.3).toDouble();
    return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: ratio, children: children);
  });
}

class _ClarityStrip extends StatelessWidget {
  const _ClarityStrip();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: LayoutBuilder(builder: (context, c) {
    final isNarrow = c.maxWidth < 650;
    final content = const [
      _ClarityPoint(icon: Icons.auto_awesome_outlined, title: 'Вопросы по делу', text: 'Уточняем то, чего не хватает в брифе.'),
      _ClarityPoint(icon: Icons.stacked_bar_chart_rounded, title: 'Ясность в цифрах', text: 'Видно, что уже описано, а что пока неизвестно.'),
      _ClarityPoint(icon: Icons.pan_tool_alt_outlined, title: 'Решение за людьми', text: 'Команду выбирает представитель бизнеса.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Eyebrow('ЧТО ДЕЛАЕТ HUB ОСОБЕННЫМ'), const SizedBox(height: 13), isNarrow ? Column(children: content.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList()) : Row(children: content.map((e) => Expanded(child: e)).toList())]);
  })));
}

class _ClarityPoint extends StatelessWidget {
  const _ClarityPoint({required this.icon, required this.title, required this.text});
  final IconData icon; final String title, text;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 31, height: 31, decoration: BoxDecoration(color: violetPale, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: violet)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ink)), const SizedBox(height: 3), Text(text, style: const TextStyle(fontSize: 10, height: 1.4, color: muted))]))]);
}

class _StepsRow extends StatelessWidget {
  const _StepsRow();
  @override
  Widget build(BuildContext context) => const Wrap(spacing: 8, runSpacing: 8, children: [
    _StepChip('01', 'Черновик'), Icon(Icons.arrow_forward_rounded, size: 16, color: muted),
    _StepChip('02', 'Уточнение'), Icon(Icons.arrow_forward_rounded, size: 16, color: muted),
    _StepChip('03', 'Ясный бриф'), Icon(Icons.arrow_forward_rounded, size: 16, color: muted),
    _StepChip('04', 'Отклики команд'), Icon(Icons.arrow_forward_rounded, size: 16, color: muted),
    _StepChip('05', 'Выбор бизнеса'),
  ]);
}

class _StepChip extends StatelessWidget {
  const _StepChip(this.number, this.label);
  final String number, label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(11), border: Border.all(color: line)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(number, style: const TextStyle(color: violet, fontSize: 9, fontWeight: FontWeight.w800)), const SizedBox(width: 7), Text(label, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w700))]));
}

class WizardView extends StatefulWidget {
  const WizardView({required this.onPublished, super.key});
  final VoidCallback onPublished;
  @override
  State<WizardView> createState() => _WizardViewState();
}

class _WizardViewState extends State<WizardView> {
  final draftController = TextEditingController();
  final Map<String, TextEditingController> answerControllers = {};
  final Map<String, TextEditingController> cardControllers = {};
  List<Map<String, dynamic>> questions = [];
  int step = 0;
  bool working = false;
  String mode = 'demo';
  String? localError;
  final fieldLabels = const <String, String>{
    'title': 'Название задачи', 'company': 'Компания или заказчик', 'topic': 'Тема', 'context': 'Контекст: что происходит сейчас?',
    'need': 'Потребность: что нужно изменить?', 'users': 'Для кого создаём решение?', 'data': 'Данные и материалы',
    'result': 'Ожидаемый результат', 'success': 'Как поймём, что получилось?', 'constraints': 'Сроки и ограничения', 'contact': 'Контакт и формат связи',
  };
  final weights = const <String, int>{'context': 10, 'need': 10, 'data': 20, 'result': 15, 'success': 15, 'constraints': 10, 'users': 10, 'contact': 10};
  int get score => weights.entries.fold(0, (sum, entry) => sum + ((cardControllers[entry.key]?.text.trim().length ?? 0) > 7 ? entry.value : 0));

  @override
  void dispose() { draftController.dispose(); for (final c in answerControllers.values) { c.dispose(); } for (final c in cardControllers.values) { c.dispose(); } super.dispose(); }

  Future<void> refine() async {
    final draft = draftController.text.trim();
    if (draft.length < 12) { setState(() => localError = 'Добавьте хотя бы одно предложение о проблеме.'); return; }
    setState(() { working = true; localError = null; });
    try {
      final result = await context.read<HubStore>().api.refine(draft);
      questions = (result['questions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      mode = result['mode']?.toString() ?? 'demo';
      for (final q in questions) { final key = q['field'].toString(); answerControllers.putIfAbsent(key, TextEditingController.new); }
      setState(() => step = 1);
    } catch (e) { setState(() => localError = e.toString()); }
    finally { if (mounted) setState(() => working = false); }
  }

  Future<void> organize() async {
    setState(() { working = true; localError = null; });
    try {
      final answers = {for (final e in answerControllers.entries) e.key: e.value.text.trim()};
      final result = await context.read<HubStore>().api.organize(draftController.text.trim(), answers);
      final fields = Map<String, dynamic>.from(result['card'] as Map);
      for (final key in fieldLabels.keys) { cardControllers.putIfAbsent(key, TextEditingController.new); cardControllers[key]!.text = fields[key]?.toString() ?? ''; }
      mode = result['mode']?.toString() ?? mode;
      setState(() => step = 2);
    } catch (e) { setState(() => localError = e.toString()); }
    finally { if (mounted) setState(() => working = false); }
  }

  Future<void> publish() async {
    if ((cardControllers['title']?.text.trim().length ?? 0) < 4 || (cardControllers['context']?.text.trim().length ?? 0) < 8) { setState(() => localError = 'Нужно заполнить название и контекст задачи.'); return; }
    setState(() { working = true; localError = null; });
    try {
      final fields = {for (final e in cardControllers.entries) e.key: e.value.text.trim()};
      await context.read<HubStore>().publish(fields);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Задача опубликована в каталоге.')));
      widget.onPublished();
    } catch (e) { setState(() => localError = e.toString()); }
    finally { if (mounted) setState(() => working = false); }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HubStore>();
    final width = MediaQuery.sizeOf(context).width;
    return ListView(children: [
      Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('РАБОЧИЙ ПРОЦЕСС ДЛЯ БИЗНЕСА'), SizedBox(height: 7), Text('Дадим задаче\nясную форму.', style: TextStyle(fontSize: 34, height: 1.08, letterSpacing: -1.2, fontWeight: FontWeight.w800, color: ink)), SizedBox(height: 8), Text('Начните с черновика. Вместе заполним только важное.', style: TextStyle(color: muted, fontSize: 13))])), const Icon(Icons.edit_note_rounded, size: 52, color: violetPale)]),
      const SizedBox(height: 20), _WizardProgress(step: step), const SizedBox(height: 15),
      LayoutBuilder(builder: (context, constraints) {
        final split = width > 1050;
        final editor = _wizardStep(context, store);
        if (!split) return Column(children: [editor, if (step == 2) Padding(padding: const EdgeInsets.only(top: 13), child: _ScoreCard(score: score, controllers: cardControllers, weights: weights))]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: editor), if (step == 2) const SizedBox(width: 14), if (step == 2) Expanded(flex: 3, child: _ScoreCard(score: score, controllers: cardControllers, weights: weights))]);
      }),
      const SizedBox(height: 18),
      const _PrivacyNote(text: 'AI помогает сформулировать и структурировать ответы. Представитель бизнеса проверяет карточку до публикации.'),
    ]);
  }

  Widget _wizardStep(BuildContext context, HubStore store) {
    if (step == 0) return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _StepHeading(number: '01', title: 'Что происходит сейчас?', subtitle: 'Напишите своими словами: проблема, кто с ней сталкивается и что хотели бы изменить.'),
      const SizedBox(height: 17), TextField(controller: draftController, maxLines: 7, maxLength: 5000, decoration: const InputDecoration(hintText: 'Например: кураторы поздно замечают, что студенты перестали справляться с учёбой. Хотим понимать, кому и когда может понадобиться поддержка.', alignLabelWithHint: true)),
      const SizedBox(height: 12), _MessageButton(working: working, icon: Icons.auto_awesome_rounded, label: 'Подобрать уточняющие вопросы', onPressed: refine),
      if (store.config['ai_enabled'] != true) const Padding(padding: EdgeInsets.only(top: 11), child: _InlineInfo(text: 'Пока включён демо-режим вопросов. Вставьте API-ключ в backend/.env, чтобы вызвать модель.')),
      if (localError != null) _InlineError(localError!),
    ]));
    if (step == 1) return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StepHeading(number: '02', title: 'Уточним, чего не хватает', subtitle: mode == 'ai' ? 'Вопросы созданы моделью из вашего черновика. Дополните ответы, которые знаете.' : mode == 'demo_fallback' ? 'AI временно недоступен, поэтому включены локальные вопросы. Сценарий можно пройти и повторить позже.' : 'Демо-режим: вопросы подобраны по словам в черновике. Необязательные ответы можно оставить пустыми.'),
      const SizedBox(height: 13), _Pill(mode == 'ai' ? 'AI ОТВЕТИЛ' : mode == 'demo_fallback' ? 'РЕЗЕРВНЫЙ ДЕМО-РЕЖИМ' : 'ДЕМО · БЕЗ ВЫЗОВА МОДЕЛИ', color: mode == 'ai' ? green : violet), const SizedBox(height: 11),
      ...questions.asMap().entries.map((entry) { final q = entry.value; final key = q['field'].toString(); return Padding(padding: const EdgeInsets.only(top: 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${(entry.key + 1).toString().padLeft(2, '0')}  ${q['question']}', style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w700, color: ink)), const SizedBox(height: 7), TextField(controller: answerControllers[key], maxLines: 2, decoration: InputDecoration(hintText: 'Ваш ответ (можно пропустить)', isDense: true))])); }),
      const SizedBox(height: 17), Row(children: [OutlinedButton(onPressed: () => setState(() => step = 0), child: const Text('Назад')), const SizedBox(width: 8), _MessageButton(working: working, icon: Icons.auto_awesome_rounded, label: 'Собрать карточку', onPressed: organize)]),
      if (localError != null) _InlineError(localError!),
    ]));
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _StepHeading(number: '03', title: 'Паспорт ясности', subtitle: 'Проверьте каждое поле. Пустое поле останется вопросом для бизнес-заказчика, AI не будет его додумывать.'),
      const SizedBox(height: 13), _Pill(mode == 'ai' ? 'ЧЕРНОВИК ОТ AI · НУЖНО ПОДТВЕРДИТЬ' : mode == 'demo_fallback' ? 'РЕЗЕРВНЫЙ ДЕМО-ЧЕРНОВИК · ПРОВЕРЬТЕ' : 'ЧЕРНОВИК · НУЖНО ПОДТВЕРДИТЬ'), const SizedBox(height: 8),
      ...fieldLabels.entries.map((entry) => Padding(padding: const EdgeInsets.only(top: 11), child: TextField(controller: cardControllers[entry.key], maxLines: entry.key == 'context' || entry.key == 'need' || entry.key == 'data' ? 3 : 2, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: entry.value, alignLabelWithHint: true, hintText: 'Можно уточнить или оставить незаполненным')))),
      const SizedBox(height: 17), Row(children: [OutlinedButton(onPressed: () => setState(() => step = 1), child: const Text('Назад к вопросам')), const SizedBox(width: 8), _MessageButton(working: working, icon: Icons.publish_rounded, label: 'Подтвердить и опубликовать', onPressed: publish)]),
      if (localError != null) _InlineError(localError!),
    ]));
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Row(children: List.generate(3, (i) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: i <= step ? 1 : 0, minHeight: 4, color: violet, backgroundColor: line)), const SizedBox(height: 6), Text(['Черновик', 'Уточнение', 'Карточка'][i], style: TextStyle(fontSize: 9, color: i == step ? violet : muted, fontWeight: i == step ? FontWeight.w800 : FontWeight.w500))]))));
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.controllers, required this.weights});
  final int score; final Map<String, TextEditingController> controllers; final Map<String, int> weights;
  String get level => score < 40 ? 'Черновик' : score < 70 ? 'Рабочая' : score < 90 ? 'Готовая' : 'Приоритетная';
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Eyebrow('ПРОЗРАЧНЫЙ ПОКАЗАТЕЛЬ'), const SizedBox(height: 8), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$score', style: const TextStyle(fontSize: 46, height: 1, letterSpacing: -2, fontWeight: FontWeight.w800, color: violet)), const Padding(padding: EdgeInsets.only(bottom: 5, left: 5), child: Text('/ 100', style: TextStyle(color: muted, fontSize: 12)))]),
    const SizedBox(height: 9), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: score / 100, color: violet, backgroundColor: violetPale, minHeight: 6)), const SizedBox(height: 8), _Pill(level, color: score >= 70 ? green : const Color(0xFF9A6B25)),
    const SizedBox(height: 14), const Divider(color: line),
    ...weights.entries.map((e) { final earned = (controllers[e.key]?.text.trim().length ?? 0) > 7 ? e.value : 0; return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(earned > 0 ? Icons.check_circle_rounded : Icons.circle_outlined, color: earned > 0 ? green : muted, size: 14), const SizedBox(width: 7), Expanded(child: Text(_labels[e.key]!, style: const TextStyle(fontSize: 10, color: ink))), Text('$earned/${e.value}', style: const TextStyle(fontSize: 9, color: muted, fontWeight: FontWeight.w700))])); }),
    const Divider(color: line, height: 24), const Text('Оценка показывает полноту брифа, а не ценность бизнеса или качество будущей команды. Даже черновик можно опубликовать.', style: TextStyle(fontSize: 10, height: 1.5, color: muted)),
  ])));
  static const _labels = {'context': 'Контекст проблемы', 'need': 'Потребность', 'data': 'Данные и материалы', 'result': 'Ожидаемый результат', 'success': 'Критерии успеха', 'constraints': 'Ограничения', 'users': 'Пользователи', 'contact': 'Связь с бизнесом'};
}

class TaskDetailView extends StatefulWidget {
  const TaskDetailView({required this.taskId, required this.onBack, super.key});
  final String taskId; final VoidCallback onBack;
  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  List<Proposal>? loadedProposals;
  bool loadingProposals = false;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<HubStore>();
    final found = store.tasks.where((e) => e.id == widget.taskId);
    if (found.isEmpty) return _EmptyBlock(title: 'Задача не найдена', detail: 'Вернитесь в каталог и выберите другую.', action: TextButton(onPressed: widget.onBack, child: const Text('В каталог')));
    final task = found.first;
    final width = MediaQuery.sizeOf(context).width;
    final proposals = loadedProposals ?? store.proposals.where((e) => e.taskId == task.id).toList();
    return ListView(children: [
      TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, size: 16), label: const Text('Все задачи'), style: TextButton.styleFrom(foregroundColor: muted, padding: EdgeInsets.zero)),
      const SizedBox(height: 11), _Pill(task.topic), const SizedBox(height: 11),
      Text(task.title, style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 7), Text('${task.company}  ·  Владелец кейса: МНВО — AI Sana', style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 18),
      Wrap(spacing: 9, runSpacing: 8, children: [_MetricChip(icon: Icons.auto_awesome_outlined, label: 'Ясность ${task.score}/100 · ${task.level}'), _MetricChip(icon: Icons.forum_outlined, label: '${task.responseCount} команд откликнулось'), _MetricChip(icon: Icons.visibility_outlined, label: 'Открыта для всех команд')]),
      const SizedBox(height: 17),
      width > 900 ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: _TaskBrief(task: task)), const SizedBox(width: 13), Expanded(flex: 3, child: _ProposalPanel(task: task, proposals: proposals, loading: loadingProposals, onApply: () => _showApply(context, task), onReload: _loadProposals))]) : Column(children: [_TaskBrief(task: task), const SizedBox(height: 12), _ProposalPanel(task: task, proposals: proposals, loading: loadingProposals, onApply: () => _showApply(context, task), onReload: _loadProposals)]),
      const SizedBox(height: 15),
      if (width <= 900) SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _showApply(context, task), icon: const Icon(Icons.lightbulb_outline_rounded), label: const Text('Отправить предложение'))),
    ]);
  }

  Future<void> _loadProposals() async {
    setState(() => loadingProposals = true);
    try { loadedProposals = await context.read<HubStore>().api.taskProposals(widget.taskId); }
    catch (_) {}
    if (mounted) setState(() => loadingProposals = false);
  }

  Future<void> _showApply(BuildContext context, HubTask task) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(23))),
      builder: (_) => _ApplySheet(task: task),
    );
    if (result == null || !mounted) return;
    try {
      final answer = await context.read<HubStore>().apply(task.id, result);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        backgroundColor: paper, icon: const Icon(Icons.mark_email_read_outlined, color: green, size: 38),
        title: const Text('Отклик отправлен'), content: Text(answer['acknowledgement']?.toString() ?? 'Бизнес получил уведомление в приложении.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Хорошо'))],
      ));
      if (mounted) setState(() => loadedProposals = null);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось отправить отклик: $e'))); }
  }
}

class _TaskBrief extends StatelessWidget {
  const _TaskBrief({required this.task});
  final HubTask task;
  @override
  Widget build(BuildContext context) {
    final sections = <(String, String, IconData)>[
      ('Что происходит', task.context, Icons.subject_rounded), ('Что нужно изменить', task.need, Icons.track_changes_rounded),
      ('Для кого', task.users, Icons.people_outline_rounded), ('Данные и материалы', task.data, Icons.dataset_outlined),
      ('Ожидаемый результат', task.result, Icons.flag_outlined), ('Как оценят успех', task.success, Icons.checklist_rounded),
      ('Ограничения', task.constraints, Icons.tune_rounded), ('Связь с заказчиком', task.contact, Icons.chat_bubble_outline_rounded),
    ];
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Eyebrow('ПАСПОРТ ЗАДАЧИ'), const SizedBox(height: 13), ...sections.map((s) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(s.$3, size: 16, color: violet), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 4), Text(s.$2.isEmpty ? 'Пока не указано' : s.$2, style: TextStyle(fontSize: 12, height: 1.55, color: s.$2.isEmpty ? muted : const Color(0xFF5C5B56)))]))])))]));
  }
}

class _ProposalPanel extends StatelessWidget {
  const _ProposalPanel({required this.task, required this.proposals, required this.loading, required this.onApply, required this.onReload});
  final HubTask task; final List<Proposal> proposals; final bool loading; final VoidCallback onApply; final VoidCallback onReload;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Отклики команд', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink))), IconButton(onPressed: onReload, tooltip: 'Обновить', icon: const Icon(Icons.refresh_rounded, size: 17, color: muted))]),
    const Text('Команда предлагает идею, план и срок. Выбор за заказчиком.', style: TextStyle(fontSize: 10, height: 1.4, color: muted)), const SizedBox(height: 10),
    if (loading) const LinearProgressIndicator(color: violet),
    if (proposals.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Пока нет предложений. Можно стать первой командой.', style: TextStyle(fontSize: 11, color: muted))),
    ...proposals.take(3).map((p) => Padding(padding: const EdgeInsets.only(top: 10), child: _ProposalMini(proposal: p))),
    const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onApply, icon: const Icon(Icons.add_rounded, size: 17), label: const Text('Предложить решение'))),
    const SizedBox(height: 7), const Text('Рейтинг ясности помогает оценить полноту брифа и не ограничивает отклик.', style: TextStyle(fontSize: 9, height: 1.4, color: muted)),
  ])));
}

class _ProposalMini extends StatelessWidget {
  const _ProposalMini({required this.proposal}); final Proposal proposal;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: canvas, border: Border.all(color: line), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(proposal.team, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 5), Text(proposal.idea, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.4, color: muted)), const SizedBox(height: 6), _StatusPill(status: proposal.status)]));
}

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.task}); final HubTask task;
  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final team = TextEditingController(); final idea = TextEditingController(); final plan = TextEditingController(); final timeline = TextEditingController(); final link = TextEditingController(); String? error;
  @override
  void dispose() { team.dispose(); idea.dispose(); plan.dispose(); timeline.dispose(); link.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: EdgeInsets.fromLTRB(20, 13, 20, MediaQuery.viewInsetsOf(context).bottom + 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Container(width: 35, height: 4, decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 18),
    const Eyebrow('ПРЕДЛОЖЕНИЕ КОМАНДЫ'), const SizedBox(height: 6), Text('Как вы решите эту задачу?', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5), Text(widget.task.title, style: const TextStyle(color: muted, fontSize: 11)),
    const SizedBox(height: 15), _TextFieldRow(controller: team, label: 'Название вашей команды', hint: 'Например, Qadam Lab'), const SizedBox(height: 10), _TextFieldRow(controller: idea, label: 'Идея решения', hint: 'Коротко: что вы хотите сделать?', maxLines: 3), const SizedBox(height: 10), _TextFieldRow(controller: plan, label: 'План команды', hint: 'Какие шаги предпримете?', maxLines: 3), const SizedBox(height: 10), _TextFieldRow(controller: timeline, label: 'Предполагаемый срок', hint: 'Например, 4 недели'), const SizedBox(height: 10), _TextFieldRow(controller: link, label: 'Ссылка на прототип', hint: 'Необязательно'),
    if (error != null) _InlineError(error!), const SizedBox(height: 13), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { if (team.text.trim().length < 2 || idea.text.trim().length < 10) { setState(() => error = 'Добавьте название команды и чуть подробнее опишите идею.'); return; } Navigator.pop(context, {'team': team.text.trim(), 'idea': idea.text.trim(), 'plan': plan.text.trim(), 'timeline': timeline.text.trim(), 'link': link.text.trim()}); }, icon: const Icon(Icons.send_rounded, size: 16), label: const Text('Отправить отклик'))),
    const SizedBox(height: 8), const Text('После отправки заказчик получит сообщение во «Входящих».', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: muted)),
  ]));
}

class ProposalsView extends StatelessWidget {
  const ProposalsView({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<HubStore>(); final pending = store.proposals.where((e) => e.status == 'pending').length;
    return ListView(children: [const Eyebrow('ВЫБИРАЙТЕ ВМЕСТЕ'), const SizedBox(height: 7), Text('Предложения\nстуденческих команд', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 8), Text('$pending ждут решения · у бизнеса есть полный контроль выбора', style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 19),
      if (store.proposals.isEmpty) const _EmptyBlock(title: 'Откликов пока нет', detail: 'Опубликованные предложения команд появятся здесь.'),
      ...store.proposals.map((proposal) => Padding(padding: const EdgeInsets.only(bottom: 11), child: _ProposalCard(proposal: proposal))),
    ]);
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal}); final Proposal proposal;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 7, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [_Pill(proposal.team), Text('на «${proposal.taskTitle}»', style: const TextStyle(fontSize: 11, color: muted)), _StatusPill(status: proposal.status)]),
    const SizedBox(height: 12), const Text('Идея решения', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(proposal.idea, style: const TextStyle(fontSize: 13, height: 1.5, color: ink)),
    if (proposal.plan.isNotEmpty) ...[const SizedBox(height: 10), const Text('План команды', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(proposal.plan, style: const TextStyle(fontSize: 11, height: 1.45, color: muted))],
    if (proposal.timeline.isNotEmpty) ...[const SizedBox(height: 8), Row(children: [const Icon(Icons.schedule_rounded, size: 14, color: muted), const SizedBox(width: 5), Text(proposal.timeline, style: const TextStyle(fontSize: 10, color: muted))])],
    if (proposal.status == 'pending') ...[const SizedBox(height: 13), Wrap(spacing: 8, children: [FilledButton.icon(onPressed: () => _decide(context, proposal, 'accepted'), icon: const Icon(Icons.check_rounded, size: 15), label: const Text('Выбрать')), OutlinedButton.icon(onPressed: () => _decide(context, proposal, 'rejected'), icon: const Icon(Icons.close_rounded, size: 15), label: const Text('Отклонить'))])],
  ])));
  Future<void> _decide(BuildContext context, Proposal proposal, String status) async {
    try { await context.read<HubStore>().choose(proposal, status); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'accepted' ? 'Команда выбрана. Она получила уведомление.' : 'Отклик отклонён. Команда получила уведомление.'))); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось обновить отклик: $e'))); }
  }
}

class InboxView extends StatelessWidget {
  const InboxView({required this.onOpen, super.key}); final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final notices = context.watch<HubStore>().notices;
    return ListView(children: [const Eyebrow('ЦЕНТР УВЕДОМЛЕНИЙ'), const SizedBox(height: 7), Text('Во входящих', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 6), const Text('После отклика сообщение появится здесь для заказчика.', style: TextStyle(fontSize: 12, color: muted)), const SizedBox(height: 18),
      if (notices.isEmpty) const _EmptyBlock(title: 'Пока спокойно', detail: 'Когда команда откликнется на задачу, здесь появится сообщение с названием команды и задачей.'),
      ...notices.map((notice) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () { final id = notice.raw['task_id']?.toString(); if (id != null) onOpen(id); }, borderRadius: BorderRadius.circular(15), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 37, height: 37, decoration: BoxDecoration(color: violetPale, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.mark_email_unread_outlined, size: 18, color: violet)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(notice.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 5), Text(notice.message, style: const TextStyle(fontSize: 11, height: 1.5, color: muted)), const SizedBox(height: 8), const Text('Открыть задачу  ↗', style: TextStyle(fontSize: 10, color: violet, fontWeight: FontWeight.w700))]))]))))),
    ]);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label}); final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: violet), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 10, color: ink, fontWeight: FontWeight.w600))]));
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status}); final String status;
  @override
  Widget build(BuildContext context) { final (text, color, bg) = switch (status) { 'accepted' => ('Выбрана', green, const Color(0xFFE9F5ED)), 'rejected' => ('Отклонена', const Color(0xFF9A6B25), const Color(0xFFFFF5E9)), _ => ('Ждёт решения', violet, violetPale) }; return _Pill(text, color: color, bg: bg); }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child}); final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(19), child: child));
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.number, required this.title, required this.subtitle}); final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: violetPale, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(number, style: const TextStyle(color: violet, fontSize: 10, fontWeight: FontWeight.w800))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 11, height: 1.48, color: muted))]))]);
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.working, required this.icon, required this.label, required this.onPressed}); final bool working; final IconData icon; final String label; final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(onPressed: working ? null : onPressed, icon: working ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon, size: 16), label: Text(working ? 'Подождите…' : label));
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({required this.controller, required this.label, required this.hint, this.maxLines = 1}); final TextEditingController controller; final String label, hint; final int maxLines;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: maxLines > 1));
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.text}); final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: violetPale.withValues(alpha: .62), borderRadius: BorderRadius.circular(12)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.verified_user_outlined, color: violet, size: 16), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF625A9A), fontSize: 10, height: 1.45)))]));
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.text}); final String text;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: violetPale, borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.info_outline_rounded, color: violet, size: 15), const SizedBox(width: 7), Expanded(child: Text(text, style: const TextStyle(fontSize: 10, height: 1.4, color: Color(0xFF625A9A))))]));
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.text); final String text;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFFFFEEEC), borderRadius: BorderRadius.circular(10)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFB63C36), size: 16), const SizedBox(width: 7), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF9E332E), fontSize: 11, height: 1.4)))]));
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.title, required this.detail, this.action}); final String title, detail; final Widget? action;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30), child: Center(child: Column(children: [const Icon(Icons.inbox_outlined, color: violet, size: 27), const SizedBox(height: 9), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 5), Text(detail, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: muted)), if (action != null) action!]))));
}

class _OfflineState extends StatelessWidget {
  const _OfflineState({required this.error, required this.onRetry}); final String error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, color: violet, size: 34), const SizedBox(height: 9), const Text('Не удаётся подключиться к серверу', style: TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 6), Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: muted)), const SizedBox(height: 13), FilledButton(onPressed: onRetry, child: const Text('Повторить'))]))));
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key}); final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 9, letterSpacing: 1.25, fontWeight: FontWeight.w800, color: violet));
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
