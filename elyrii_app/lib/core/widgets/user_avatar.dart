import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/avatar_options.dart';

/// Widget d'avatar utilisateur reutilisable.
///
/// Affiche la mascotte Elyrii par defaut (si [pfp] est null, vide ou
/// le marqueur mascotte), sinon affiche l'image (reseau ou fichier local).
class UserAvatar extends StatelessWidget {
  final String? pfp;
  final double size;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.pfp,
    this.size = 48,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useMascot = isMascotAvatar(pfp);
    final isLocalFile = pfp != null && isLocalAvatarPath(pfp!);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: showBorder
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.secondary.withValues(alpha: 0.3),
                ],
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(showBorder ? 2.0 : 0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          ),
          child: ClipOval(
            child: useMascot
                ? Image.asset('assets/mascotte.png', fit: BoxFit.cover)
                : isLocalFile
                ? Image.file(
                    File(localAvatarFilePath(pfp!)),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Image.asset('assets/mascotte.png', fit: BoxFit.cover),
                  )
                : Image.network(
                    pfp!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: size * 0.3,
                          height: size * 0.3,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/mascotte.png',
                        fit: BoxFit.cover,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
