import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/mascot_widget.dart';
import '../widgets/cosmetic_card.dart';

/// Page de personnalisation premium de la mascotte Elyrii en 3D.
/// Propose un habillage en verre poli (Glassmorphism), un éclairage d'ambiance
/// et un carousel de cartes cosmétiques.
class MascotCustomizationPage extends StatefulWidget {
  const MascotCustomizationPage({super.key});

  @override
  State<MascotCustomizationPage> createState() => _MascotCustomizationPageState();
}

class _MascotCustomizationPageState extends State<MascotCustomizationPage> {
  // Liste fictive des skins disponibles
  final List<Map<String, dynamic>> _skins = [
    {
      'id': 'classic',
      'name': 'Elyrii Classique',
      'price': '0',
      'isUnlocked': true,
      'assetThumbnail': 'assets/mascotte.png',
      'color': AppColors.primary,
    },
    {
      'id': 'christmas',
      'name': 'Chapeau de Noël',
      'price': '120',
      'isUnlocked': false,
      'assetThumbnail': 'assets/icon.png',
      'color': Colors.redAccent,
    },
    {
      'id': 'cyberpunk',
      'name': 'Lunettes Cyberpunk',
      'price': '250',
      'isUnlocked': false,
      'assetThumbnail': 'assets/icon_black_bg.png',
      'color': Colors.cyanAccent,
    },
    {
      'id': 'gold_crown',
      'name': 'Couronne Royale',
      'price': '500',
      'isUnlocked': false,
      'assetThumbnail': 'assets/mascotte.png',
      'color': const Color(0xFFFFD700),
    },
  ];

  String _equippedSkinId = 'classic';
  int _userCoins = 380; // Solde fictif de l'utilisateur pour la gamification

  void _handleSkinTap(int index) {
    final skin = _skins[index];
    final bool isUnlocked = skin['isUnlocked'];

    if (isUnlocked) {
      // Équiper le skin débloqué
      setState(() {
        _equippedSkinId = skin['id'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${skin['name']} est maintenant équipé ! 💜"),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Tenter d'acheter le skin verrouillé
      final int price = int.parse(skin['price']);
      if (_userCoins >= price) {
        _showPurchaseDialog(index, price);
      } else {
        _showInsufficientCoinsDialog(skin['name']);
      }
    }
  }

  void _showPurchaseDialog(int index, int price) {
    final skin = _skins[index];
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            "Acheter le skin ?",
            style: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Voulez-vous débloquer le skin '${skin['name']}' pour $price pièces 🪙 ?",
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _userCoins -= price;
                  _skins[index]['isUnlocked'] = true;
                  _equippedSkinId = skin['id'];
                });
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("${skin['name']} débloqué et équipé ! 🎉"),
                    backgroundColor: AppColors.accent,
                  ),
                );
              },
              child: const Text("Acheter", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showInsufficientCoinsDialog(String skinName) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            "Pièces insuffisantes",
            style: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Il vous manque des pièces pour acheter le skin '$skinName'. Relevez des défis de bien-être quotidiens pour en gagner ! 🧘‍♂️⚡",
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Compris !", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F0C20), const Color(0xFF15102A), const Color(0xFF0F0C20)]
                : [const Color(0xFFF9F7FC), const Color(0xFFF0EBF8), const Color(0xFFF9F7FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barre d'outils supérieure : Retour + Solde de pièces
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bouton retour stylisé (Glassmorphism)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),

                    // Badge de pièces (Monnaie virtuelle)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFD700).withValues(alpha: 0.2),
                            const Color(0xFFFFA500).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: Color(0xFFFFD700),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$_userCoins",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Titre de la page
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      "Garde-robe d'Elyrii",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Faites glisser pour faire tourner Elyrii et l'habiller",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Espace central : Rendu de la mascotte 3D
              // On utilise un seul Mascot3DWidget stable (sans ValueKey changeante)
              // pour éviter de recréer deux <model-viewer> lors du changement de skin.
              // Le skinId est passé directement et la mise à jour se fait via didUpdateWidget.
              Expanded(
                child: Center(
                  child: Mascot3DWidget(
                    width: 320,
                    height: 320,
                    skinId: _equippedSkinId,
                    autoRotate: _equippedSkinId == 'classic',
                    cameraControls: true,
                  ),
                ),
              ),

              // Espace inférieur : Carousel horizontal de skins
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "Variantes de skin",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 170,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _skins.length,
                        itemBuilder: (context, index) {
                          final skin = _skins[index];
                          return CosmeticCard(
                            name: skin['name'],
                            price: skin['price'],
                            isUnlocked: skin['isUnlocked'],
                            isEquipped: _equippedSkinId == skin['id'],
                            assetThumbnail: skin['assetThumbnail'],
                            baseColor: skin['color'],
                            onTap: () => _handleSkinTap(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
