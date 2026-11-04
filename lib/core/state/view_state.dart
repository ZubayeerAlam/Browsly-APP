import '../errors/app_failure.dart';

enum ViewStatus { initial, loading, success, empty, error }

/// The state a screen provider exposes to its widgets.
class ViewState<T> {
  const ViewState.initial() : this._(ViewStatus.initial);

  /// Keeps [data] so a screen can still show old content while refreshing.
  const ViewState.loading({T? data}) : this._(ViewStatus.loading, data: data);

  const ViewState.success(T data) : this._(ViewStatus.success, data: data);

  const ViewState.empty() : this._(ViewStatus.empty);

  const ViewState.error(AppFailure failure, {T? data})
    : this._(ViewStatus.error, data: data, failure: failure);

  const ViewState._(this.status, {this.data, this.failure});

  final ViewStatus status;
  final T? data;
  final AppFailure? failure;
}
