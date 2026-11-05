import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/seller_stats.dart';
import '../../domain/repositories/statistics_repository.dart';

/// The card on the Dashboard. It simply stays hidden for someone with no shop,
/// or if it can't load, because the marketplace is what the screen is for.
class SellerDashboardProvider extends ChangeNotifier {
  SellerDashboardProvider(this._repository);

  final StatisticsRepository _repository;
  SellerDashboard? _dashboard;
  bool _isDisposed = false;

  SellerDashboard? get dashboard => _dashboard;

  Future<void> load() async {
    try {
      _dashboard = await _repository.getDashboard();
    } on AppFailure {
      // Handled by the comment above. An old card stays until the next load.
    }
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
