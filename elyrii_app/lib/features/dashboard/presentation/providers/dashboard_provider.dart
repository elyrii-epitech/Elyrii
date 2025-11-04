import 'package:flutter/material.dart';

class DashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  // Stats
  int _pendingDeliveries = 12;
  int _completedDeliveries = 48;
  int _scheduledDeliveries = 8;
  int _problemDeliveries = 2;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingDeliveries => _pendingDeliveries;
  int get completedDeliveries => _completedDeliveries;
  int get scheduledDeliveries => _scheduledDeliveries;
  int get problemDeliveries => _problemDeliveries;

  /// Charge les données du dashboard
  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Appeler l'API pour récupérer les vraies données
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulation de données
      _pendingDeliveries = 12;
      _completedDeliveries = 48;
      _scheduledDeliveries = 8;
      _problemDeliveries = 2;
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Rafraîchit les données
  Future<void> refresh() async {
    await loadDashboardData();
  }
}
