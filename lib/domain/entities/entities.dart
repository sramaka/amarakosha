// lib/domain/entities/entities.dart
//
// Data model from the design handoff README:
//   Kanda → Varga → [Section?] → Verse → Pada

// ─── Word (for grammar bottom sheet) ─────────────────────────────────────────
class AWord {
  final String w;         // Devanagari inflected form
  final String m;         // English meaning
  final String gender;    // पुंलिङ्ग | स्त्रीलिङ्ग | नपुंसकलिङ्ग
  final String vibhakti;  // case
  final String vacana;    // number
  final String stem;      // Devanagari stem (प्रातिपदिक)
  final String note;      // Etymological note

  const AWord({
    required this.w, required this.m, required this.gender,
    required this.vibhakti, required this.vacana,
    required this.stem, required this.note,
  });
}

// ─── Verse ────────────────────────────────────────────────────────────────────
class Verse {
  final int num;
  final String id;        // e.g. "1.1.6"
  final List<String> lines; // lines[0] = Pāda 1, lines[1] = Pāda 2
  final List<AWord> words;
  final String meaning;   // brief English summary

  const Verse({
    this.id = '',
    required this.num,
    required this.lines,
    required this.words,
    required this.meaning,
  });

  int get padaCount => lines.length;
}

// ─── Section (optional sub-grouping within a Varga) ──────────────────────────
class Section {
  final String name;       // Devanagari
  final String nameEn;     // Romanised
  final int fromVerse;
  final int toVerse;

  const Section({
    required this.name, required this.nameEn,
    required this.fromVerse, required this.toVerse,
  });
}

// ─── Varga ───────────────────────────────────────────────────────────────────
class Varga {
  final int num;
  final String id;          // e.g. "1.1"
  final String name;        // Devanagari
  final String nameEn;      // Romanised
  final int verses;         // total verse count
  final List<Verse> shlokaList;
  final List<Section>? sections;

  const Varga({
    required this.num,
    this.id = '',
    required this.name,
    this.nameEn = '',
    required this.verses,
    this.shlokaList = const [],
    this.sections,
  });
}

// ─── Kanda ───────────────────────────────────────────────────────────────────
class Kanda {
  final int num;
  final String id;          // e.g. "1"
  final String name;        // Devanagari
  final String nameEn;      // Romanised
  final String desc;        // English description
  final List<Varga> vargas;

  const Kanda({
    required this.num,
    this.id = '',
    required this.name,
    this.nameEn = '',
    this.desc = '',
    required this.vargas,
  });

  int get totalVerses => vargas.fold(0, (s, v) => s + v.verses);
}

// ─── Session (passed from Setup → Practice) ──────────────────────────────────
enum PracticeMode { listen, recite, guided }

class Session {
  final Kanda kanda;
  final Varga varga;
  final int verseFrom;
  final int verseTo;
  final PracticeMode mode;
  final int repeatN;

  const Session({
    required this.kanda, required this.varga,
    required this.verseFrom, required this.verseTo,
    required this.mode, required this.repeatN,
  });

  int get verseCount => verseTo - verseFrom + 1;
  int get totalRecitations => verseCount * repeatN;

  String get modeLabel => switch (mode) {
    PracticeMode.listen  => 'listen to',
    PracticeMode.recite  => 'recite',
    PracticeMode.guided  => 'work through',
  };

  Session copyWith({PracticeMode? mode}) => Session(
    kanda: kanda, varga: varga,
    verseFrom: verseFrom, verseTo: verseTo,
    mode: mode ?? this.mode, repeatN: repeatN,
  );
}

// ─── Audio / recording state ──────────────────────────────────────────────────

/// Which audio set is currently active in the player.
enum AudioSet { defaultSet, userRecordings }

/// Playback status.
enum PlayStatus { idle, loading, playing, paused }

/// Recording status for a single pāda.
enum RecStatus { unrecorded, recording, recorded, playing }

/// Keyed recording entry: key = "$kanda-$varga-$verse-$pada"
class RecordingEntry {
  final String key;       // e.g. "1-1-3-1"
  final String duration;  // formatted, e.g. "0:04"
  final String localPath;

  const RecordingEntry({
    required this.key, required this.duration, required this.localPath,
  });

  static String makeKey(int kanda, int varga, int verse, int pada) =>
      '$kanda-$varga-$verse-$pada';
}

// ─── Repeat loop config ───────────────────────────────────────────────────────
enum LoopMode { verse, padaRange, verseSet }

class LoopConfig {
  final bool enabled;
  final LoopMode mode;
  final int lineA;    // for padaRange: from-pada (1-based)
  final int lineB;    // for padaRange: to-pada
  final int repN;     // for verse/padaRange: repetitions
  final int setFrom;  // for verseSet: from-verse
  final int setTo;    // for verseSet: to-verse
  final int setRepN;  // for verseSet: repetitions

  const LoopConfig({
    this.enabled = false,
    this.mode = LoopMode.verse,
    this.lineA = 1,
    this.lineB = 2,
    this.repN = 3,
    this.setFrom = 1,
    this.setTo = 5,
    this.setRepN = 1,
  });

  LoopConfig copyWith({
    bool? enabled, LoopMode? mode,
    int? lineA, int? lineB, int? repN,
    int? setFrom, int? setTo, int? setRepN,
  }) => LoopConfig(
    enabled: enabled ?? this.enabled, mode: mode ?? this.mode,
    lineA: lineA ?? this.lineA, lineB: lineB ?? this.lineB,
    repN: repN ?? this.repN, setFrom: setFrom ?? this.setFrom,
    setTo: setTo ?? this.setTo, setRepN: setRepN ?? this.setRepN,
  );

  int get activeRepN => mode == LoopMode.verseSet ? setRepN : repN;
  int get setSize    => setTo - setFrom + 1;
}
