enum ReportTarget { product, shop, review, message }

enum ReportReason {
  prohibited('Not allowed on Browsly'),
  fake('Fake or misleading'),
  offensive('Offensive or abusive'),
  spam('Spam'),
  other('Something else');

  const ReportReason(this.label);

  final String label;
}

abstract interface class ReportRepository {
  /// Reporting the same thing twice is not an error.
  Future<void> submit(
    ReportTarget target,
    String targetId,
    ReportReason reason, {
    String? details,
  });
}
