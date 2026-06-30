import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import '../../models/app_limit.dart';
import '../../services/limits_service.dart';
import '../../utils/duration_format.dart';
import 'usage_card.dart';

const _warningOptions = [5, 10, 15, 20, 30, 45, 60];
const _dailyLimitOptions = [5, 10, 15, 30, 45, 60, 90, 120, 150, 180, 240, 300];

/// Lets the user configure a periodic usage warning and a daily usage block
/// for a single app. Persists through [LimitsService], which also starts or
/// stops the native service that actually polls usage and enforces this.
class AppLimitCard extends StatefulWidget {
  const AppLimitCard({super.key, required this.packageName});

  final String packageName;

  @override
  State<AppLimitCard> createState() => _AppLimitCardState();
}

class _AppLimitCardState extends State<AppLimitCard> {
  final _limitsService = LimitsService();

  bool _loading = true;
  bool _warningEnabled = false;
  bool _dailyLimitEnabled = false;
  bool _isSelf = false;
  int _warningIndex = 3;
  int _dailyLimitIndex = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ownPackageName = await _limitsService.getOwnPackageName();
      if (ownPackageName == widget.packageName) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _isSelf = true;
        });
        return;
      }
      final limits = await _limitsService.getLimits();
      AppLimit? existing;
      for (final limit in limits) {
        if (limit.packageName == widget.packageName) {
          existing = limit;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        final warningMinutes = existing?.warningIntervalMinutes;
        if (warningMinutes != null) {
          _warningEnabled = true;
          _warningIndex = _closestIndex(_warningOptions, warningMinutes);
        }
        final dailyLimitMinutes = existing?.dailyLimitMinutes;
        if (dailyLimitMinutes != null) {
          _dailyLimitEnabled = true;
          _dailyLimitIndex = _closestIndex(_dailyLimitOptions, dailyLimitMinutes);
        }
      });
    } on MissingPluginException {
      // The native side isn't wired up in the currently running build (a
      // stale install from before this channel existed, most commonly) —
      // fail closed rather than leaving the card stuck invisible forever.
      if (!mounted) return;
      setState(() => _loading = false);
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

  Future<void> _save() => _limitsService.setLimit(
        AppLimit(
          packageName: widget.packageName,
          warningIntervalMinutes:
              _warningEnabled ? _warningOptions[_warningIndex] : null,
          dailyLimitMinutes:
              _dailyLimitEnabled ? _dailyLimitOptions[_dailyLimitIndex] : null,
        ),
      );

  Future<void> _onWarningToggled(bool enabled) async {
    if (enabled) {
      final granted = await _limitsService.requestNotificationPermission();
      if (!granted) {
        _showPermissionSnackBar('les notifications');
        return;
      }
    }
    setState(() => _warningEnabled = enabled);
    await _save();
  }

  Future<void> _onDailyLimitToggled(bool enabled) async {
    if (enabled) {
      final granted = await _limitsService.requestOverlayPermission();
      if (!granted) {
        _showPermissionSnackBar(
          'l\'affichage par-dessus les autres applications',
        );
        return;
      }
      // Not a runtime permission, so it can't be requested through a
      // dialog: send the user to Settings and have them flip the switch
      // again once StayFocus's accessibility service is enabled there.
      // Without it, the block still works but can lag a few seconds when
      // switching back to the app from Recents/Home.
      final hasAccessibility = await _limitsService.hasAccessibilityPermission();
      if (!hasAccessibility) {
        await _limitsService.openAccessibilitySettings();
        _showAccessibilitySnackBar();
        return;
      }
    }
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

  void _showAccessibilitySnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Active "StayFocus" dans Réglages > Accessibilité pour un '
          'blocage instantané, puis réessaie.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_limitsService.isSupported || _loading || _isSelf) {
      return const SizedBox.shrink();
    }
    return UsageCard(
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
        ],
      ),
    );
  }
}
