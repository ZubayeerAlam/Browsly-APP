import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/seller_stats.dart';
import '../../domain/repositories/statistics_repository.dart';

/// What the chart shows. One at a time, because they have different scales.
enum StatsMeasure {
  views('Views'),
  clicks('Clicks'),
  orders('Orders'),
  sales('Sales');

  const StatsMeasure(this.label);

  final String label;
}

class StatisticsProvider extends ChangeNotifier {
  StatisticsProvider(this._repository);

  final StatisticsRepository _repository;

  int _days = 7;
  StatsMeasure _measure = StatsMeasure.views;
  ViewState<SellerStats> _state = const ViewState.initial();
  bool _isDisposed = false;

  /// Only the newest request may change the screen.
  int _request = 0;

  int get days => _days;
  StatsMeasure get measure => _measure;
  ViewState<SellerStats> get state => _state;

  Future<void> setDays(int days) {
    if (days == _days) return Future.value();
    _days = days;
    return load();
  }

  void setMeasure(StatsMeasure measure) {
    _measure = measure;
    _notify();
  }

  Future<void> load() async {
    final request = ++_request;
    _state = ViewState.loading(data: _state.data);
    _notify();
    try {
      final stats = await _repository.getStats(_days);
      if (request != _request) return;
      _state = stats == null
          ? const ViewState.empty()
          : ViewState.success(stats);
    } on AppFailure catch (failure) {
      if (request != _request) return;
      _state = ViewState.error(failure, data: _state.data);
    }
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
