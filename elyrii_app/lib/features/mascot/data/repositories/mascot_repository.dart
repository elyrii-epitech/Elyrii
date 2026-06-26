import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../models/mascot_model.dart';

class MascotRepository {
  final ApiClient _client;

  MascotRepository({required ApiClient client}) : _client = client;

  Future<MascotModel> getMascot() async {
    final response =
        await _client.get(ApiConfig.userMascotUrl) as Map<String, dynamic>;
    return _fromBackend(response);
  }

  Future<MascotModel> updateMascot(MascotModel mascot) async {
    final response =
        await _client.put(
              ApiConfig.userMascotUrl,
              body: {
                'appearance': mascot.themeId,
                'themeId': mascot.themeId,
                'equippedCosmetics': mascot.equippedCosmetics,
                'personality': {
                  'equippedCosmetics': mascot.equippedCosmetics,
                },
              },
            )
            as Map<String, dynamic>;
    return _fromBackend(response);
  }

  MascotModel _fromBackend(Map<String, dynamic> json) {
    final personality = Map<String, dynamic>.from(
      json['personality'] as Map? ?? const <String, dynamic>{},
    );
    final rawTheme = json['appearance'] as String? ??
        personality['themeId'] as String? ??
        'nature';
    final cosmetics = (json['equippedCosmetics'] as List<dynamic>?) ??
        (personality['equippedCosmetics'] as List<dynamic>?) ??
        const <dynamic>[];

    return MascotModel.defaultMascot().copyWith(
      themeId: rawTheme == 'default' ? 'nature' : rawTheme,
      equippedCosmetics: cosmetics.map((item) => item.toString()).toList(),
    );
  }
}
