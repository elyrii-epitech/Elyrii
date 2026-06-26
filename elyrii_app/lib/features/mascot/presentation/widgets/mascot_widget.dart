import 'package:flutter/material.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/widgets/mascot_3d_viewer.dart';

class MascotThemePreview extends StatelessWidget {
  final MascotTheme theme;
  final double size;

  const MascotThemePreview({
    super.key,
    required this.theme,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Mascot3DViewer(
      config: const Mascot3DConfig(
        autoRotate: false,
        interactionEnabled: false,
        showLoadingIndicator: true,
      ),
      width: size,
      height: size,
      colorMatrix: theme.id == 'nature' ? null : theme.colorMatrix,
    );
  }
}
