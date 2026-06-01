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
      final track = tracksById[pick.trackId];
      if (track == null) continue;
      resolved.add(ResolvedCuratedDemoPick(pick: pick, track: track));
    }
    return resolved;
  }
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
        CuratedDemoTrackPick(trackId: 'fma-42377', mood: 'Bright electronic', shelfLabel: 'Night drive'),
        CuratedDemoTrackPick(trackId: 'fma-69170', mood: 'Dream pulse', shelfLabel: 'Signature pick'),
        CuratedDemoTrackPick(trackId: 'fma-58341', mood: 'Beat tape', shelfLabel: 'Instant groove'),
        CuratedDemoTrackPick(trackId: 'fma-127265', mood: 'Indie calm', shelfLabel: 'Vocal warmth'),
        CuratedDemoTrackPick(trackId: 'fma-62445', mood: 'Sunlit indie', shelfLabel: 'Fresh listen'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Start Here',
      subtitle: 'Accessible picks that show the range of the demo catalog.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-42377', mood: 'Electronic', shelfLabel: 'Opener'),
        CuratedDemoTrackPick(trackId: 'fma-42372', mood: 'Instrumental', shelfLabel: 'Clean focus'),
        CuratedDemoTrackPick(trackId: 'fma-39605', mood: 'Disco energy', shelfLabel: 'Lift'),
        CuratedDemoTrackPick(trackId: 'fma-72076', mood: 'Synth pop', shelfLabel: 'Glow'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Electronic Pulse',
      subtitle: 'Rhythm-forward electronic and synth-leaning cuts.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-69170', mood: 'Electronic pulse', shelfLabel: 'Pulse'),
        CuratedDemoTrackPick(trackId: 'fma-72076', mood: 'Neon synth', shelfLabel: 'Stargaze'),
        CuratedDemoTrackPick(trackId: 'fma-39605', mood: 'Disco', shelfLabel: 'High color'),
        CuratedDemoTrackPick(trackId: 'fma-64626', mood: 'Glitch pop', shelfLabel: 'Jangle'),
        CuratedDemoTrackPick(trackId: 'fma-64625', mood: 'Reprise', shelfLabel: 'Afterglow'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Focus / Instrumental',
      subtitle: 'Lower-distraction instrumentals for work and reading.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-42372', mood: 'Instrumental', shelfLabel: 'Focus'),
        CuratedDemoTrackPick(trackId: 'fma-50952', mood: 'Acoustic calm', shelfLabel: 'Soft texture'),
        CuratedDemoTrackPick(trackId: 'fma-127996', mood: 'Ambient', shelfLabel: 'Deep focus'),
        CuratedDemoTrackPick(trackId: 'fma-124873', mood: 'Ambient', shelfLabel: 'Crystal'),
        CuratedDemoTrackPick(trackId: 'fma-51006', mood: 'Motion', shelfLabel: 'Light movement'),
        CuratedDemoTrackPick(trackId: 'fma-132310', mood: 'Instrumental', shelfLabel: 'Gentle'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Indie / Folk Calm',
      subtitle: 'Warm, human-scale tracks for a softer first listen.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-127265', mood: 'Indie folk', shelfLabel: 'Warm'),
        CuratedDemoTrackPick(trackId: 'fma-106502', mood: 'Folk calm', shelfLabel: 'Breathe'),
        CuratedDemoTrackPick(trackId: 'fma-141144', mood: 'Acoustic', shelfLabel: 'Easy pace'),
        CuratedDemoTrackPick(trackId: 'fma-14653', mood: 'Indie rock', shelfLabel: 'Classic demo'),
        CuratedDemoTrackPick(trackId: 'fma-62445', mood: 'Indie', shelfLabel: 'Light mood'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Hip-Hop Beats',
      subtitle: 'Beat-led entries with immediate rhythm and texture.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-58341', mood: 'Beat tape', shelfLabel: 'Bounce'),
        CuratedDemoTrackPick(trackId: 'fma-24425', mood: 'Hip-hop', shelfLabel: 'Low end'),
        CuratedDemoTrackPick(trackId: 'fma-10697', mood: 'Beat sketch', shelfLabel: 'Raw loop'),
        CuratedDemoTrackPick(trackId: 'fma-24431', mood: 'Hip-hop', shelfLabel: 'Five piece'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Long Session / Deep Cuts',
      subtitle: 'A deeper run for when you want to settle in.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-61011', mood: 'Cinematic', shelfLabel: 'Wide screen'),
        CuratedDemoTrackPick(trackId: 'fma-127996', mood: 'Ambient', shelfLabel: 'Deep listen'),
        CuratedDemoTrackPick(trackId: 'fma-124873', mood: 'Ambient', shelfLabel: 'Slow shimmer'),
        CuratedDemoTrackPick(trackId: 'fma-15488', mood: 'Classical', shelfLabel: 'Tradition'),
        CuratedDemoTrackPick(trackId: 'fma-61492', mood: 'Experimental', shelfLabel: 'Late night'),
      ],
    ),
    CuratedDemoShelf(
      title: 'Fresh from the Demo Library',
      subtitle: 'Catalog-aware suggestions that stay local to the demo dataset.',
      picks: <CuratedDemoTrackPick>[
        CuratedDemoTrackPick(trackId: 'fma-72076', mood: 'Synth', shelfLabel: 'New light'),
        CuratedDemoTrackPick(trackId: 'fma-106502', mood: 'Calm', shelfLabel: 'Seasonal'),
        CuratedDemoTrackPick(trackId: 'fma-132310', mood: 'Instrumental', shelfLabel: 'Tiny sparkle'),
        CuratedDemoTrackPick(trackId: 'fma-141144', mood: 'Acoustic', shelfLabel: 'Fresh calm'),
        CuratedDemoTrackPick(trackId: 'fma-64626', mood: 'Indie electronic', shelfLabel: 'Bright edge'),
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
