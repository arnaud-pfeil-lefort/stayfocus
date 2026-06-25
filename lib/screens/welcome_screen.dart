import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_background.dart';
import '../widgets/focus_logo.dart';
import '../widgets/theme_toggle_button.dart';
import 'usage_screen.dart';

/// The first screen shown on launch: a soft, airy intro with a single call to
/// action to enter the app.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.controller});

  final ThemeController controller;

  static const _features = [
    (icon: Icons.timelapse_rounded, label: 'Votre temps d\'écran, app par app'),
    (
      icon: Icons.bar_chart_rounded,
      label: 'Vos 7 derniers jours en un coup d\'œil',
    ),
    (
      icon: Icons.notifications_active_rounded,
      label: 'Une alerte quand une app prend trop de place',
    ),
  ];

  void _start(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => UsageScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: ThemeToggleButton(controller: controller),
                          ),
                          const Spacer(),
                          FocusLogo(size: 84, color: colors.accent),
                          const SizedBox(height: 36),
                          Text('Bienvenue sur', style: textTheme.titleMedium),
                          Text('StayFocus', style: textTheme.headlineSmall),
                          const SizedBox(height: 14),
                          Text(
                            'Reprenez la main sur votre temps d\'écran.',
                            style: textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 44),
                          for (final f in _features) ...[
                            _FeatureRow(icon: f.icon, label: f.label),
                            const SizedBox(height: 22),
                          ],
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => _start(context),
                              child: const Text('Commencer'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.accent, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
        ),
      ],
    );
  }
}
