// lib/domain/entities/entities.dart
// Data model v3: Kanda → Varga → Section → Pada → Word

// ─── AWord ───────────────────────────────────────────────────────────────────
class AWord {
  final String w;         // Devanagari form shown in chip
  final String m;         // meaning (artha)
  final String gender;    // linga dev string
  final String vibhakti;  // "1"–"8", "0"=avyaya
  final String vacana;    // sg | pl | du | avyaya
  final String stem;      // prātipadika (same as w for AK)
  final String note;      // form note e.g. "nom.pl.m"
  final String formIast;  // surface IAST form e.g. "devāḥ"
  final String caseEn;    // e.g. "nominative plural masculine"

  const AWord({
    required this.w,
    required this.m,
    required this.gender,
    required this.vibhakti,
    required this.vacana,
    required this.stem,
    required this.note,
    this.formIast = '',
    this.caseEn   = '',
  });

  factory AWord.fromJson(Map<String, dynamic> j) => AWord(
    w:        (j['w']         as String?) ?? '',
    m:        (j['artha']     as String?) ?? '',
    gender:   (j['linga']     as String?) ?? '',
    vibhakti: (j['vibhakti']  as String?) ?? '',
    vacana:   (j['vacana']    as String?) ?? '',
    stem:     (j['stem_iast'] as String?) ?? (j['w'] as String?) ?? '',
    note:     (j['form_note'] as String?) ?? '',
    formIast: (j['form_iast'] as String?) ?? '',
    caseEn:   (j['case_en']   as String?) ?? '',
  );
}

// ─── Pada ─────────────────────────────────────────────────────────────────────
// A single half-verse line (= one GRETIL line, e.g. 1.1.11)
class Pada {
  final String    id;        // PRIMARY: GRETIL reference e.g. "1.1.11"
  final String    legacyId;  // KEPT: k.v.csv_shloka.pada e.g. "1.1.6.1"
  final String    audioKey;  // audio file key e.g. "1-1-6-1"
  final int       seq;       // position within parent Section (1-based)
  final String    shlokaId;  // parent shloka e.g. "1.1.6"
  final int       padaNum;   // 1 (A) or 2 (B)
  final String    textDev;   // Devanagari
  final String    textIast;  // IAST
  final List<AWord> words;

  const Pada({
    required this.id,
    this.legacyId = '',
    this.audioKey = '',
    required this.seq,
    required this.shlokaId,
    required this.padaNum,
    required this.textDev,
    required this.textIast,
    required this.words,
  });

  factory Pada.fromJson(Map<String, dynamic> j) => Pada(
    id:        (j['id']         as String?) ?? '',
    legacyId:  (j['legacy_id']  as String?) ?? (j['id'] as String?) ?? '',
    audioKey:  (j['audio_key']  as String?) ?? '',
    seq:       (j['seq']        as int?)    ?? 0,
    shlokaId:  (j['shloka_id']  as String?) ?? '',
    padaNum:   (j['pada_num']   as int?)    ?? 1,
    textDev:   (j['text_dev']   as String?) ?? '',
    textIast:  (j['text_iast']  as String?) ?? '',
    words: (j['words'] as List? ?? [])
        .map((w) => AWord.fromJson(w as Map<String, dynamic>))
        .toList(),
  );

  /// True if this pada has real verse text (not a placeholder)
  bool get hasText =>
      textDev.isNotEmpty && !textDev.startsWith('[');

  String get label => 'Pāda ${padaNum == 1 ? 'A' : 'B'} · $id';
}

// ─── Section ─────────────────────────────────────────────────────────────────
// A semantic group of pādas within a Varga (from GRETIL ## ... ## markers)
class Section {
  final String     id;       // "k.v.seq" e.g. "1.1.2"
  final int        seq;      // 1-based within varga
  final String     titleEn;  // English section title from GRETIL
  final List<Pada> padas;

  const Section({
    required this.id,
    required this.seq,
    required this.titleEn,
    required this.padas,
  });

  factory Section.fromJson(Map<String, dynamic> j) => Section(
    id:      (j['id']       as String?) ?? '',
    seq:     (j['seq']      as int?)    ?? 0,
    titleEn: (j['title_en'] as String?) ?? '',
    padas: (j['padas'] as List? ?? [])
        .map((p) => Pada.fromJson(p as Map<String, dynamic>))
        .toList(),
  );

  int get padaCount   => padas.length;
  int get shlokaCount => (padas.length / 2).ceil();
  bool get hasText    => padas.any((p) => p.hasText);
}

// ─── Varga ───────────────────────────────────────────────────────────────────
class Varga {
  final String        id;       // "k.v" e.g. "1.1"
  final int           seq;
  final String        name;     // Devanagari
  final List<Section> sections;

  const Varga({
    required this.id,
    required this.seq,
    required this.name,
    required this.sections,
  });

  factory Varga.fromJson(Map<String, dynamic> j) => Varga(
    id:   (j['id']       as String?) ?? '',
    seq:  (j['seq']      as int?)    ?? 0,
    name: (j['name_dev'] as String?) ?? '',
    sections: (j['sections'] as List? ?? [])
        .map((s) => Section.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  int          get totalPadas   => sections.fold(0, (n, s) => n + s.padaCount);
  int          get totalShlokas => sections.fold(0, (n, s) => n + s.shlokaCount);
  List<Pada>   get allPadas     => [for (final s in sections) ...s.padas];
  List<Section> get allSections => sections;
}

// ─── Kanda ───────────────────────────────────────────────────────────────────
class Kanda {
  final int         num;
  final String      name;    // Devanagari
  final String      nameEn;
  final List<Varga> vargas;

  const Kanda({
    required this.num,
    required this.name,
    required this.nameEn,
    required this.vargas,
  });

  factory Kanda.fromJson(Map<String, dynamic> j) => Kanda(
    num:    (j['num']     as int?)    ?? 0,
    name:   (j['name_dev'] as String?) ?? '',
    nameEn: (j['name_en'] as String?) ?? '',
    vargas: (j['vargas'] as List? ?? [])
        .map((v) => Varga.fromJson(v as Map<String, dynamic>))
        .toList(),
  );

  int get totalPadas => vargas.fold(0, (n, v) => n + v.totalPadas);
}

// ─── Session ──────────────────────────────────────────────────────────────────
enum PracticeMode { listen, recite, guided }

class Session {
  final Kanda      kanda;
  final Varga      varga;
  final Section    section;   // active section when session started
  final PracticeMode mode;
  final int        repeatN;

  const Session({
    required this.kanda,
    required this.varga,
    required this.section,
    required this.mode,
    required this.repeatN,
  });

  Session copyWith({PracticeMode? mode}) => Session(
    kanda: kanda, varga: varga, section: section,
    mode: mode ?? this.mode, repeatN: repeatN,
  );
}

// ─── Audio / Recording ───────────────────────────────────────────────────────
enum AudioSet   { defaultSet, userRecordings }
enum PlayStatus { idle, loading, playing, paused }
enum RecStatus  { unrecorded, recording, recorded, playing }

// LoopMode: keep legacy values (verse, padaRange, verseSet) for grammar_sheet
// plus new v3 values (pada, section, custom)
enum LoopMode { pada, section, custom, verse, padaRange, verseSet }

class RecordingEntry {
  final String key;        // audio key e.g. "1-1-6-1"
  final String duration;
  final String localPath;
  const RecordingEntry({
    required this.key,
    required this.duration,
    required this.localPath,
  });
}

class LoopConfig {
  final bool     enabled;
  final LoopMode mode;
  final int      repN;
  // Legacy fields used by RepeatPanel in grammar_sheet.dart
  final int      lineA;
  final int      lineB;
  final int      setFrom;
  final int      setTo;
  final int      setRepN;

  const LoopConfig({
    this.enabled = false,
    this.mode    = LoopMode.pada,
    this.repN    = 3,
    this.lineA   = 1,
    this.lineB   = 2,
    this.setFrom = 1,
    this.setTo   = 5,
    this.setRepN = 1,
  });

  int get setSize => setTo - setFrom + 1;

  LoopConfig copyWith({
    bool? enabled, LoopMode? mode, int? repN,
    int? lineA, int? lineB,
    int? setFrom, int? setTo, int? setRepN,
  }) => LoopConfig(
    enabled: enabled ?? this.enabled,
    mode:    mode    ?? this.mode,
    repN:    repN    ?? this.repN,
    lineA:   lineA   ?? this.lineA,
    lineB:   lineB   ?? this.lineB,
    setFrom: setFrom ?? this.setFrom,
    setTo:   setTo   ?? this.setTo,
    setRepN: setRepN ?? this.setRepN,
  );
}
