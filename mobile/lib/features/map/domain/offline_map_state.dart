enum OfflineMapPhase { notDownloaded, downloading, ready, failed }

class OfflineMapState {
  const OfflineMapState({
    required this.phase,
    this.progress = 0,
    this.completedBytes = 0,
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

  const OfflineMapState.ready({required int completedBytes})
    : this(
        phase: OfflineMapPhase.ready,
        progress: 1,
        completedBytes: completedBytes,
      );

  const OfflineMapState.failed(String message)
    : this(phase: OfflineMapPhase.failed, message: message);

  final OfflineMapPhase phase;
  final double progress;
  final int completedBytes;
  final String? message;

  bool get isReady => phase == OfflineMapPhase.ready;
  bool get isDownloading => phase == OfflineMapPhase.downloading;
}

String formatOfflineBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}
