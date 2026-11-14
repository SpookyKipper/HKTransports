class UpstreamEtaSample {
  const UpstreamEtaSample({
    required this.stopIndex,
    required this.eta,
    this.arrived = false,
  });

  final int stopIndex;
  final DateTime? eta;
  final bool arrived;
}

class UpstreamEtaNotice {
  const UpstreamEtaNotice({
    required this.currentIndex,
    required this.stopIndex,
    required this.eta,
    required this.remainingStops,
    required this.scheduled,
  });

  final int currentIndex;
  final int stopIndex;
  final DateTime eta;
  final int remainingStops;
  final bool scheduled;
}

/// Walks from the currently viewed stop towards the origin and finds the first
/// place where an upstream arrival time is later than the downstream one.
///
/// [upstream] must be ordered from the stop immediately before the current one
/// towards the origin. Each item should contain the first ETA for that stop.
/// A missing ETA stops the scan.
UpstreamEtaNotice? findUpstreamEtaNotice({
  required int currentIndex,
  required DateTime? currentEta,
  required bool currentArrived,
  required Iterable<UpstreamEtaSample> upstream,
  required DateTime now,
  required bool scheduled,
}) {
  final List<UpstreamEtaSample> samples = upstream.toList(growable: false);
  final Map<int, UpstreamEtaSample> byIndex = <int, UpstreamEtaSample>{
    for (final UpstreamEtaSample sample in samples) sample.stopIndex: sample,
  };
  DateTime? downstreamEta = currentEta;
  int downstreamIndex = currentIndex;

  for (final UpstreamEtaSample sample in samples) {
    final DateTime? eta = sample.eta;
    if (eta == null) return null;
    if (downstreamEta != null && eta.isAfter(downstreamEta)) {
      int targetIndex = downstreamIndex;
      DateTime? targetEta = downstreamEta;
      bool targetArrived = targetIndex == currentIndex
          ? currentArrived
          : (byIndex[targetIndex]?.arrived ?? false) || !targetEta.isAfter(now);
      while (targetIndex < currentIndex && targetArrived) {
        targetIndex++;
        targetEta = targetIndex == currentIndex
            ? currentEta
            : byIndex[targetIndex]?.eta;
        if (targetEta == null) return null;
        targetArrived = targetIndex == currentIndex
            ? currentArrived
            : (byIndex[targetIndex]?.arrived ?? false) ||
                  !targetEta.isAfter(now);
      }
      if (targetIndex > currentIndex || targetEta == null) return null;
      if (targetIndex == currentIndex &&
          (currentArrived || !targetEta.isAfter(now))) {
        return null;
      }
      return UpstreamEtaNotice(
        currentIndex: currentIndex,
        stopIndex: targetIndex,
        eta: targetEta,
        remainingStops: currentIndex - targetIndex,
        scheduled: scheduled,
      );
    }
    downstreamEta = eta;
    downstreamIndex = sample.stopIndex;
  }
  return null;
}
