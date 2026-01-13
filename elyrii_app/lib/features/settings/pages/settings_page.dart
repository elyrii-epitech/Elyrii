import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../core/services/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass_kit.dart';
import '../../../core/services/glass_performance_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _haptics = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Stack(
        children: [
          // Contenu scrollable
          CustomScrollView(
            slivers: [
              // Espace pour l'AppBar
              SliverToBoxAdapter(
                child: SizedBox(height: topPadding + 70),
              ),
              // Section Apparence
              SliverToBoxAdapter(
                child: _buildSection(
                  context,
                  title: 'Apparence',
                  isDark: isDark,
                  children: [
                    LiquidGlassListTile(
                      title: 'Mode sombre',
                      subtitle: 'Activer le thème sombre',
                      leadingIcon: Icons.dark_mode_rounded,
                      showChevron: false,
                      trailing: LiquidGlassSwitch(
                        value: isDark,
                        onChanged: (value) {
                          themeProvider.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Section Notifications
              SliverToBoxAdapter(
                child: _buildSection(
                  context,
                  title: 'Notifications',
                  isDark: isDark,
                  children: [
                    LiquidGlassListTile(
                      title: 'Notifications push',
                      subtitle: 'Rappels et mises à jour',
                      leadingIcon: Icons.notifications_rounded,
                      showChevron: false,
                      trailing: LiquidGlassSwitch(
                        value: _notifications,
                        onChanged: (value) {
                          setState(() => _notifications = value);
                        },
                      ),
                    ),
                    _buildDivider(isDark),
                    LiquidGlassListTile(
                      title: 'Retour haptique',
                      subtitle: 'Vibrations lors des interactions',
                      leadingIcon: Icons.vibration_rounded,
                      showChevron: false,
                      trailing: LiquidGlassSwitch(
                        value: _haptics,
                        onChanged: (value) {
                          setState(() => _haptics = value);
                          if (value) {
                            HapticFeedback.mediumImpact();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Section Compte
              SliverToBoxAdapter(
                child: _buildSection(
                  context,
                  title: 'Compte',
                  isDark: isDark,
                  children: [
                    LiquidGlassListTile(
                      title: 'Profil',
                      subtitle: 'Gérer vos informations',
                      leadingIcon: Icons.person_rounded,
                      onTap: () {
                        // TODO: Navigate to profile
                      },
                    ),
                    _buildDivider(isDark),
                    LiquidGlassListTile(
                      title: 'Confidentialité',
                      subtitle: 'Paramètres de vie privée',
                      leadingIcon: Icons.lock_rounded,
                      onTap: () {
                        // TODO: Navigate to privacy settings
                      },
                    ),
                    _buildDivider(isDark),
                    LiquidGlassListTile(
                      title: 'Données et stockage',
                      subtitle: 'Gérer vos données',
                      leadingIcon: Icons.storage_rounded,
                      onTap: () {
                        // TODO: Navigate to data settings
                      },
                    ),
                  ],
                ),
              ),
              // Section À propos
              SliverToBoxAdapter(
                child: _buildSection(
                  context,
                  title: 'À propos',
                  isDark: isDark,
                  children: [
                    const LiquidGlassListTile(
                      title: 'Version',
                      subtitle: '1.0.0 (Build 1)',
                      leadingIcon: Icons.info_rounded,
                      showChevron: false,
                    ),
                    _buildDivider(isDark),
                    LiquidGlassListTile(
                      title: 'Conditions d\'utilisation',
                      leadingIcon: Icons.description_rounded,
                      onTap: () {
                        // TODO: Open terms
                      },
                    ),
                    _buildDivider(isDark),
                    LiquidGlassListTile(
                      title: 'Politique de confidentialité',
                      leadingIcon: Icons.privacy_tip_rounded,
                      onTap: () {
                        // TODO: Open privacy policy
                      },
                    ),
                  ],
                ),
              ),
              // Section Déconnexion
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: LiquidGlassButton(
                    label: 'Se déconnecter',
                    icon: Icons.logout_rounded,
                    style: LiquidGlassButtonStyle.gray,
                    isExpanded: true,
                    onPressed: () {
                      showLiquidGlassDialog(
                        context: context,
                        title: 'Se déconnecter',
                        child: const Text(
                            'Êtes-vous sûr de vouloir vous déconnecter ?'),
                        actions: [
                          LiquidGlassDialogAction(
                            label: 'Annuler',
                            onPressed: () => Navigator.pop(context),
                          ),
                          LiquidGlassDialogAction(
                            label: 'Déconnecter',
                            isDestructive: true,
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: Implement logout
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // Espace en bas
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          // Bouton retour en bulle Liquid Glass + Titre
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _LiquidGlassBackButton(
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    'Paramètres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 44), // Balance pour le bouton
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 0.5,
      indent: 60,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08),
    );
  }
}

/// Bouton retour en style bulle Liquid Glass
class _LiquidGlassBackButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _LiquidGlassBackButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_LiquidGlassBackButton> createState() => _LiquidGlassBackButtonState();
}

class _LiquidGlassBackButtonState extends State<_LiquidGlassBackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isDark
                        ? [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.08),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.75),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
