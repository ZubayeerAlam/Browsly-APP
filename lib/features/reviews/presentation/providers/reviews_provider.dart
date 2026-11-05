import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/state/view_state.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewsProvider extends ChangeNotifier {
  ReviewsProvider(this._repository, this.productId);

  final ReviewRepository _repository;
  final String productId;

  ViewState<List<Review>> _state = const ViewState.initial();
  ReviewCursor? _next;
  bool _isLoadingMore = false;
  bool _isDisposed = false;

  ViewState<List<Review>> get state => _state;

  Future<void> load() async {
    _state = const ViewState.loading();
    _notify();
    try {
      final page = await _repository.getReviews(productId);
      _next = page.next;
      _state = page.items.isEmpty
          ? const ViewState.empty()
          : ViewState.success(page.items);
    } on AppFailure catch (failure) {
      _state = ViewState.error(failure);
    }
    _notify();
  }

  Future<void> loadMore() async {
    final cursor = _next;
    final items = _state.data;
    if (cursor == null || items == null || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final page = await _repository.getReviews(productId, cursor: cursor);
      _next = page.next;
      _state = ViewState.success([...items, ...page.items]);
    } on AppFailure {
      // Scrolling again retries.
    }
    _isLoadingMore = false;
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
