class UpstreamEtaSample {
  const UpstreamEtaSample({required this.stopIndex, required this.eta});

  final int stopIndex;
  final DateTime? eta;
}

class UpstreamEtaNotice {
  const UpstreamEtaNotice({
    required this.currentIndex,
    required this.stopIndex,
    required this.eta,
    required this.remainingStops,
  });

  final int currentIndex;
  final int stopIndex;
  final DateTime eta;
  final int remainingStops;
}

/// Walks from the currently viewed stop towards the origin and finds the first
/// place where the upstream ETA jumps sharply later than the downstream ETA.
///
/// [upstream] must be ordered from the stop immediately before the current one
/// towards the origin. Each item should contain the first ETA for that stop.
/// A missing ETA stops the scan.
UpstreamEtaNotice? findUpstreamEtaNotice({
  required int currentIndex,
  required DateTime? currentEta,
  required Iterable<UpstreamEtaSample> upstream,
  required DateTime now,
  int jumpMinutes = 5,
}) {
  DateTime? downstreamEta = currentEta;
  int downstreamIndex = currentIndex;

  for (final UpstreamEtaSample sample in upstream) {
    final DateTime? eta = sample.eta;
    if (eta == null) return null;
    if (downstreamEta != null) {
      final int upstreamMinutes = eta.difference(now).inMinutes;
      final int downstreamMinutes = downstreamEta.difference(now).inMinutes;
      if (upstreamMinutes > downstreamMinutes + jumpMinutes) {
        return UpstreamEtaNotice(
          currentIndex: currentIndex,
          stopIndex: downstreamIndex,
          eta: downstreamEta,
          remainingStops: currentIndex - downstreamIndex + 1,
        );
      }
    }
    downstreamEta = eta;
    downstreamIndex = sample.stopIndex;
  }
  return null;
}
