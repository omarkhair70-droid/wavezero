import '../catalog/catalog_track_manifest.dart';

class CuratedDemoTrackPick {
  const CuratedDemoTrackPick({
    required this.trackId,
    required this.mood,
    required this.shelfLabel,
  });

  final String trackId;
  final String mood;
  final String shelfLabel;
}

class ResolvedCuratedDemoPick {
  const ResolvedCuratedDemoPick({
    required this.pick,
    required this.track,
  });

  final CuratedDemoTrackPick pick;
  final CatalogTrackSummary track;
}

class CuratedDemoShelf {
  const CuratedDemoShelf({
    required this.title,
    required this.subtitle,
    required this.picks,
  });

  final String title;
  final String subtitle;
  final List<CuratedDemoTrackPick> picks;

  List<ResolvedCuratedDemoPick> resolve(Map<String, CatalogTrackSummary> tracksById) {
    final resolved = <ResolvedCuratedDemoPick>[];
    final seen = <String>{};
    for (final pick in picks) {
      if (!seen.add(pick.trackId)) continue;
      final track = _resolveCatalogTrack(tracksById, pick.trackId);
      if (track == null) continue;
      resolved.add(ResolvedCuratedDemoPick(pick: pick, track: track));
    }
    return resolved;
  }
}


CatalogTrackSummary? _resolveCatalogTrack(Map<String, CatalogTrackSummary> tracksById, String pickId) {
  final direct = tracksById[pickId];
  if (direct != null) return direct;

  final officialId = _officialFmaTrackId(pickId);
  if (officialId != null) {
    final official = tracksById[officialId];
    if (official != null) return official;
  }

  final legacyId = _legacyFmaTrackId(pickId);
  if (legacyId != null) return tracksById[legacyId];
  return null;
}

String? _officialFmaTrackId(String trackId) {
  final legacyMatch = RegExp(r'^fma-(\d+)$').firstMatch(trackId);
  if (legacyMatch != null) {
    return 'track-fma-${legacyMatch.group(1)!.padLeft(6, '0')}';
  }

  final generatedMatch = RegExp(r'^track-fma-(\d+)$').firstMatch(trackId);
  if (generatedMatch != null) {
    return 'track-fma-${generatedMatch.group(1)!.padLeft(6, '0')}';
  }

  return null;
}

String? _legacyFmaTrackId(String trackId) {
  final generatedMatch = RegExp(r'^track-fma-(\d+)$').firstMatch(trackId);
  if (generatedMatch == null) return null;
  final parsed = int.tryParse(generatedMatch.group(1)!);
  if (parsed == null) return null;
  return 'fma-$parsed';
}

class ResolvedCuratedDemoShelf {
  const ResolvedCuratedDemoShelf({
    required this.shelf,
    required this.picks,
  });

  final CuratedDemoShelf shelf;
  final List<ResolvedCuratedDemoPick> picks;
}

class CuratedDemoPicks {
  const CuratedDemoPicks._();

  static const consumerCopy = 'Demo picks from legally reviewable FMA metadata.';
  static const artworkCopy = 'Artwork shown here is WaveZero-generated visual treatment unless a verified artwork URL is present.';

  static const shelves = <CuratedDemoShelf>[
    CuratedDemoShelf(
      title: 'WaveZero Picks',
      subtitle: 'A curated first listen from the local demo library.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-042377', mood: 'Bright electronic', shelfLabel: 'Night drive'),
        CuratedDemoTrackPick(trackId: 'track-fma-069170', mood: 'Dream pulse', shelfLabel: 'Signature pick'),
        CuratedDemoTrackPick(trackId: 'track-fma-058341', mood: 'Beat tape', shelfLabel: 'Instant groove'),
        CuratedDemoTrackPick(trackId: 'track-fma-127265', mood: 'Indie calm', shelfLabel: 'Vocal warmth'),
        CuratedDemoTrackPick(trackId: 'track-fma-062445', mood: 'Sunlit indie', shelfLabel: 'Fresh listen'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Start Here',
      subtitle: 'Accessible picks that show the range of the demo catalog.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-042377', mood: 'Electronic', shelfLabel: 'Opener'),
        CuratedDemoTrackPick(trackId: 'track-fma-042372', mood: 'Instrumental', shelfLabel: 'Clean focus'),
        CuratedDemoTrackPick(trackId: 'track-fma-039605', mood: 'Disco energy', shelfLabel: 'Lift'),
        CuratedDemoTrackPick(trackId: 'track-fma-072076', mood: 'Synth pop', shelfLabel: 'Glow'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Electronic Pulse',
      subtitle: 'Rhythm-forward electronic and synth-leaning cuts.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-069170', mood: 'Electronic pulse', shelfLabel: 'Pulse'),
        CuratedDemoTrackPick(trackId: 'track-fma-072076', mood: 'Neon synth', shelfLabel: 'Stargaze'),
        CuratedDemoTrackPick(trackId: 'track-fma-039605', mood: 'Disco', shelfLabel: 'High color'),
        CuratedDemoTrackPick(trackId: 'track-fma-064626', mood: 'Glitch pop', shelfLabel: 'Jangle'),
        CuratedDemoTrackPick(trackId: 'track-fma-064625', mood: 'Reprise', shelfLabel: 'Afterglow'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Focus / Instrumental',
      subtitle: 'Lower-distraction instrumentals for work and reading.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-042372', mood: 'Instrumental', shelfLabel: 'Focus'),
        CuratedDemoTrackPick(trackId: 'track-fma-050952', mood: 'Acoustic calm', shelfLabel: 'Soft texture'),
        CuratedDemoTrackPick(trackId: 'track-fma-127996', mood: 'Ambient', shelfLabel: 'Deep focus'),
        CuratedDemoTrackPick(trackId: 'track-fma-124873', mood: 'Ambient', shelfLabel: 'Crystal'),
        CuratedDemoTrackPick(trackId: 'track-fma-051006', mood: 'Motion', shelfLabel: 'Light movement'),
        CuratedDemoTrackPick(trackId: 'track-fma-132310', mood: 'Instrumental', shelfLabel: 'Gentle'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Indie / Folk Calm',
      subtitle: 'Warm, human-scale tracks for a softer first listen.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-127265', mood: 'Indie folk', shelfLabel: 'Warm'),
        CuratedDemoTrackPick(trackId: 'track-fma-106502', mood: 'Folk calm', shelfLabel: 'Breathe'),
        CuratedDemoTrackPick(trackId: 'track-fma-141144', mood: 'Acoustic', shelfLabel: 'Easy pace'),
        CuratedDemoTrackPick(trackId: 'track-fma-014653', mood: 'Indie rock', shelfLabel: 'Classic demo'),
        CuratedDemoTrackPick(trackId: 'track-fma-062445', mood: 'Indie', shelfLabel: 'Light mood'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Hip-Hop Beats',
      subtitle: 'Beat-led entries with immediate rhythm and texture.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-058341', mood: 'Beat tape', shelfLabel: 'Bounce'),
        CuratedDemoTrackPick(trackId: 'track-fma-024425', mood: 'Hip-hop', shelfLabel: 'Low end'),
        CuratedDemoTrackPick(trackId: 'track-fma-010697', mood: 'Beat sketch', shelfLabel: 'Raw loop'),
        CuratedDemoTrackPick(trackId: 'track-fma-024431', mood: 'Hip-hop', shelfLabel: 'Five piece'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Long Session / Deep Cuts',
      subtitle: 'A deeper run for when you want to settle in.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-061011', mood: 'Cinematic', shelfLabel: 'Wide screen'),
        CuratedDemoTrackPick(trackId: 'track-fma-127996', mood: 'Ambient', shelfLabel: 'Deep listen'),
        CuratedDemoTrackPick(trackId: 'track-fma-124873', mood: 'Ambient', shelfLabel: 'Slow shimmer'),
        CuratedDemoTrackPick(trackId: 'track-fma-015488', mood: 'Classical', shelfLabel: 'Tradition'),
        CuratedDemoTrackPick(trackId: 'track-fma-061492', mood: 'Experimental', shelfLabel: 'Late night'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Fresh from the Demo Library',
      subtitle: 'Catalog-aware suggestions that stay local to the demo dataset.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'track-fma-072076', mood: 'Synth', shelfLabel: 'New light'),
        CuratedDemoTrackPick(trackId: 'track-fma-106502', mood: 'Calm', shelfLabel: 'Seasonal'),
        CuratedDemoTrackPick(trackId: 'track-fma-132310', mood: 'Instrumental', shelfLabel: 'Tiny sparkle'),
        CuratedDemoTrackPick(trackId: 'track-fma-141144', mood: 'Acoustic', shelfLabel: 'Fresh calm'),
        CuratedDemoTrackPick(trackId: 'track-fma-064626', mood: 'Indie electronic', shelfLabel: 'Bright edge'),
      ],
    ),
  ];

  static List<ResolvedCuratedDemoShelf> resolveShelves(List<CatalogTrackSummary> catalogTracks) {
    if (catalogTracks.isEmpty) return const <ResolvedCuratedDemoShelf>[];
    final byId = <String, CatalogTrackSummary>{for (final track in catalogTracks) track.trackId: track};
    return shelves
        .map((shelf) => ResolvedCuratedDemoShelf(shelf: shelf, picks: shelf.resolve(byId)))
        .where((shelf) => shelf.picks.isNotEmpty)
        .toList(growable: false);
  }

  static List<ResolvedCuratedDemoPick> resolveFeatured(List<CatalogTrackSummary> catalogTracks, {int limit = 12}) {
    final shelves = resolveShelves(catalogTracks);
    final featured = <ResolvedCuratedDemoPick>[];
    final seen = <String>{};
    for (final shelf in shelves) {
      for (final pick in shelf.picks) {
        if (!seen.add(pick.track.trackId)) continue;
        featured.add(pick);
        if (featured.length >= limit) return featured;
      }
    }
    return featured;
  }
}
