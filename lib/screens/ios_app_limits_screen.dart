import 'package:flutter/material.dart';

import '../models/ios_app_limit_group.dart';
import '../services/ios_limits_service.dart';
import '../services/usage/source.dart' show PermissionStatus;
import '../widgets/app_background.dart';
import '../widgets/usage/ios_limit_group_card.dart';
import '../widgets/usage/usage_message.dart';
import 'ios_app_limit_group_detail_screen.dart';

/// iOS equivalent of [UsageScreen] + [AppUsageScreen] combined: there's no
/// per-app usage list to drill into (iOS never reveals app identity to
/// third-party code), so the unit here is a user-named "limit group" picked
/// through Apple's own app picker.
class IosAppLimitsScreen extends StatefulWidget {
  const IosAppLimitsScreen({super.key});

  @override
  State<IosAppLimitsScreen> createState() => _IosAppLimitsScreenState();
}

class _IosAppLimitsScreenState extends State<IosAppLimitsScreen>
    with WidgetsBindingObserver {
  final _service = IosLimitsService();

  PermissionStatus? _authStatus;
  List<IosAppLimitGroup> _groups = const [];
  Map<String, int> _usageMsByGroupId = const {};
  bool _loadingGroups = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAuthorization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Authorization can only be granted from the system prompt/Settings, so
    // re-check it whenever the user comes back to the app.
    if (state == AppLifecycleState.resumed) {
      _refreshAuthorization();
    }
  }

  Future<void> _refreshAuthorization() async {
    final status = await _service.checkAuthorization();
    if (!mounted) return;
    setState(() => _authStatus = status);
    if (status == PermissionStatus.granted) {
      await _refreshGroups();
    }
  }

  Future<void> _refreshGroups() async {
    setState(() => _loadingGroups = true);
    final groups = await _service.getGroups();
    final usages = await Future.wait(groups.map((g) => _service.getUsageMs(g.id)));
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _usageMsByGroupId = {
        for (var i = 0; i < groups.length; i++) groups[i].id: usages[i],
      };
      _loadingGroups = false;
    });
  }

  Future<void> _createGroup() async {
    final nickname = await _promptNickname();
    if (nickname == null || nickname.trim().isEmpty) return;
    final id = await _service.createGroup(nickname.trim());
    if (id.isEmpty) return;
    await _service.pickApps(id);
    await _refreshGroups();
  }

  Future<String?> _promptNickname() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nom du groupe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ex. Réseaux sociaux'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(IosAppLimitGroup group) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IosAppLimitGroupDetailScreen(group: group),
      ),
    );
    await _refreshGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(child: SafeArea(child: _buildBody())),
      floatingActionButton: _authStatus == PermissionStatus.granted
          ? FloatingActionButton(
              onPressed: _createGroup,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final status = _authStatus;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (status != PermissionStatus.granted) {
      return UsageMessage(
        icon: Icons.lock_outline,
        text: 'StayFocus a besoin de l\'autorisation "Temps d\'écran" pour '
            'limiter l\'utilisation de certaines applis.',
        action: FilledButton(
          onPressed: () async {
            await _service.requestAuthorization();
            await _refreshAuthorization();
          },
          child: const Text('Autoriser'),
        ),
      );
    }
    if (_loadingGroups && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_groups.isEmpty) {
      return UsageMessage(
        icon: Icons.hourglass_empty,
        text: 'Aucun groupe d\'applis limité pour l\'instant.',
        action: FilledButton(
          onPressed: _createGroup,
          child: const Text('Créer un groupe'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshGroups,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: _groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final group = _groups[index];
          return IosLimitGroupCard(
            group: group,
            usageMs: _usageMsByGroupId[group.id] ?? 0,
            onTap: () => _openDetail(group),
          );
        },
      ),
    );
  }
}
