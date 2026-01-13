import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class EmergencyResourcesButton extends StatelessWidget {
  const EmergencyResourcesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEmergencyResources(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emergency_outlined,
                size: 16,
                color: Colors.red.shade300,
              ),
              const SizedBox(width: 6),
              Text(
                'Urgence',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyResources(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.favorite_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Tu n\'es pas seul(e)',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Des professionnels sont disponibles 24h/24',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildResourceTile(
              icon: Icons.phone_rounded,
              title: 'Fil Santé Jeunes',
              subtitle: '0 800 235 236 (gratuit)',
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 12),
            _buildResourceTile(
              icon: Icons.phone_rounded,
              title: 'SOS Amitié',
              subtitle: '09 72 39 40 50',
              color: const Color(0xFF2196F3),
            ),
            const SizedBox(height: 12),
            _buildResourceTile(
              icon: Icons.chat_rounded,
              title: 'En cas d\'urgence vitale',
              subtitle: 'Appelle le 15 ou le 112',
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Fermer',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.textTertiaryDark,
          ),
        ],
      ),
    );
  }
}
