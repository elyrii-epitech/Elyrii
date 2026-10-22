import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../routes/app_routes.dart';

class MascotCustomizeCharm extends StatelessWidget {
  const MascotCustomizeCharm({super.key});

  @override
  Widget build(BuildContext context) => LiquidGlassIconButton(
    icon: Icons.palette_outlined,
    tooltip: 'Personnaliser la mascotte',
    size: 48,
    onPressed: () => context.push(AppRoutes.mascotCustomization),
  );
}
