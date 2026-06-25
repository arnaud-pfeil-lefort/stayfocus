import 'package:flutter/material.dart';

import '../models/ios_app_limit_group.dart';
import '../services/ios_limits_service.dart';
import '../utils/duration_format.dart';
import '../widgets/app_background.dart';
import '../widgets/usage/usage_card.dart';

// iOS's DeviceActivity event thresholds must be a multiple of 15 minutes —
// coarser than Android's 5-minute granularity (see AppLimitCard).
const _warningOptions = [15, 30, 45, 60, 90, 120];
const _dailyLimitOptions = [15, 30, 45, 60, 90, 120, 150, 180, 240];

/// Lets the user re-pick a group's apps and configure its warning interval
/// and daily limit. Mirrors [AppLimitCard]'s toggle+slider pattern, plus an
/// "choose apps" step that has no Android equivalent (Android already knows
/// every app's identity from the usage list; iOS never does).
class IosAppLimitGroupDetailScreen extends StatefulWidget {
  const IosAppLimitGroupDetailScreen({super.key, required this.group});

  final IosAppLimitGroup group;

  @override
  State<IosAppLimitGroupDetailScreen> createState() =>
      _IosAppLimitGroupDetailScreenState();
}

class _IosAppLimitGroupDetailScreenState
    extends State<IosAppLimitGroupDetailScreen> {
  final _service = IosLimitsService();

  late IosAppLimitGroup _group = widget.group;
  bool _warningEnabled = false;
  bool _dailyLimitEnabled = false;
  int _warningIndex = 1;
  int _dailyLimitIndex = 1;

  @override
  void initState() {
    super.initState();
    final warningMinutes = _group.warningIntervalMinutes;
    if (warningMinutes != null) {
      _warningEnabled = true;
      _warningIndex = _closestIndex(_warningOptions, warningMinutes);
    }
    final dailyLimitMinutes = _group.dailyLimitMinutes;
    if (dailyLimitMinutes != null) {
      _dailyLimitEnabled = true;
      _dailyLimitIndex = _closestIndex(_dailyLimitOptions, dailyLimitMinutes);
    }
  }

  static int _closestIndex(List<int> options, int value) {
    var bestIndex = 0;
    var bestDiff = (options[0] - value).abs();
    for (var i = 1; i < options.length; i++) {
      final diff = (options[i] - value).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<void> _save() async {
    final updated = _group.copyWith(
      warningIntervalMinutes: _warningEnabled ? _warningOptions[_warningIndex] : null,
      clearWarning: !_warningEnabled,
      dailyLimitMinutes:
          _dailyLimitEnabled ? _dailyLimitOptions[_dailyLimitIndex] : null,
      clearDailyLimit: !_dailyLimitEnabled,
    );
    final groups = await _service.saveGroup(updated);
    if (!mounted) return;
    setState(() {
      _group = groups.firstWhere((g) => g.id == _group.id, orElse: () => updated);
    });
  }

  Future<void> _onWarningToggled(bool enabled) async {
    if (enabled) {
      final granted = await _service.requestNotificationPermission();
      if (!granted) {
        _showPermissionSnackBar('les notifications');
        return;
      }
    }
    setState(() => _warningEnabled = enabled);
    await _save();
  }

  Future<void> _onDailyLimitToggled(bool enabled) async {
    setState(() => _dailyLimitEnabled = enabled);
    await _save();
  }

  void _showPermissionSnackBar(String permissionLabel) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'StayFocus a besoin de la permission pour $permissionLabel '
          'pour activer cette option.',
        ),
      ),
    );
  }

  Future<void> _pickApps() async {
    final picked = await _service.pickApps(_group.id);
    if (!mounted || !picked) return;
    setState(() => _group = _group.copyWith(hasSelection: true));
  }

  Future<void> _delete() async {
    await _service.removeGroup(_group.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.nickname),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer ce groupe',
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UsageCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _group.hasSelection
                            ? 'Applis sélectionnées'
                            : 'Aucune appli sélectionnée',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _pickApps,
                        child: Text(
                          _group.hasSelection
                              ? 'Modifier la sélection'
                              : 'Choisir des applis',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                UsageCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Limites d\'utilisation',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Avertissement périodique'),
                        subtitle: Text(
                          _warningEnabled
                              ? 'Toutes les '
                                  '${formatDuration(Duration(minutes: _warningOptions[_warningIndex]))}'
                              : 'Désactivé',
                        ),
                        value: _warningEnabled,
                        onChanged: _onWarningToggled,
                      ),
                      if (_warningEnabled)
                        Slider(
                          value: _warningIndex.toDouble(),
                          min: 0,
                          max: (_warningOptions.length - 1).toDouble(),
                          divisions: _warningOptions.length - 1,
                          label: formatDuration(
                            Duration(minutes: _warningOptions[_warningIndex]),
                          ),
                          onChanged: (value) =>
                              setState(() => _warningIndex = value.round()),
                          onChangeEnd: (_) => _save(),
                        ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Blocage quotidien'),
                        subtitle: Text(
                          _dailyLimitEnabled
                              ? 'Bloquée après '
                                  '${formatDuration(Duration(minutes: _dailyLimitOptions[_dailyLimitIndex]))}'
                                  ' par jour'
                              : 'Désactivé',
                        ),
                        value: _dailyLimitEnabled,
                        onChanged: _onDailyLimitToggled,
                      ),
                      if (_dailyLimitEnabled)
                        Slider(
                          value: _dailyLimitIndex.toDouble(),
                          min: 0,
                          max: (_dailyLimitOptions.length - 1).toDouble(),
                          divisions: _dailyLimitOptions.length - 1,
                          label: formatDuration(
                            Duration(minutes: _dailyLimitOptions[_dailyLimitIndex]),
                          ),
                          onChanged: (value) =>
                              setState(() => _dailyLimitIndex = value.round()),
                          onChangeEnd: (_) => _save(),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Les seuils iOS doivent être des multiples de 15 minutes.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
