enum OfflineMapPhase { notDownloaded, downloading, ready, failed }

enum OfflineMapFailure { download, removal }

class OfflineMapState {
  const OfflineMapState({
    required this.phase,
    this.progress = 0,
    this.completedBytes = 0,
    this.downloadedAt,
    this.failure,
    this.message,
  });

  const OfflineMapState.notDownloaded({
    double progress = 0,
    int completedBytes = 0,
  }) : this(
         phase: OfflineMapPhase.notDownloaded,
         progress: progress,
         completedBytes: completedBytes,
       );

  const OfflineMapState.downloading({
    required double progress,
    required int completedBytes,
  }) : this(
         phase: OfflineMapPhase.downloading,
         progress: progress,
         completedBytes: completedBytes,
       );

  const OfflineMapState.ready({
    required int completedBytes,
    DateTime? downloadedAt,
  }) : this(
         phase: OfflineMapPhase.ready,
         progress: 1,
         completedBytes: completedBytes,
         downloadedAt: downloadedAt,
       );

  const OfflineMapState.failed(
    String message, {
    required OfflineMapFailure failure,
    double progress = 0,
    int completedBytes = 0,
    DateTime? downloadedAt,
  }) : this(
         phase: OfflineMapPhase.failed,
         progress: progress,
         completedBytes: completedBytes,
         downloadedAt: downloadedAt,
         failure: failure,
         message: message,
       );

  final OfflineMapPhase phase;
  final double progress;
  final int completedBytes;
  final DateTime? downloadedAt;
  final OfflineMapFailure? failure;
  final String? message;

  bool get isReady => phase == OfflineMapPhase.ready;
  bool get isDownloading => phase == OfflineMapPhase.downloading;
  bool get isFailed => phase == OfflineMapPhase.failed;
}

String formatOfflineBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}
