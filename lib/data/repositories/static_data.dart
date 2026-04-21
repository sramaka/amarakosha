// lib/data/repositories/static_data.dart
//
// Loads Amarakosha data from assets/data/amarakosha.json
// JSON built from amara_pada.csv (UoH/aupasana) + amara_mula.utf8
//
// 1,436 shlokas total; 135 with pada_a/pada_b text (full Kanda 1)

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/entities.dart';

// ── In-memory cache ───────────────────────────────────────────────────────────
List<Kanda>? _kandaCache;

Future<List<Kanda>> loadKandas() async {
  if (_kandaCache != null) return _kandaCache!;
  final jsonStr = await rootBundle.loadString('assets/data/amarakosha.json');
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  _kandaCache = (data['kandas'] as List)
      .map((k) => _parseKanda(k as Map<String, dynamic>))
      .toList();
  return _kandaCache!;
}

// ── Parsers ───────────────────────────────────────────────────────────────────
Kanda _parseKanda(Map<String, dynamic> j) => Kanda(
      num:    j['num'] as int,
      name:   j['name_dev'] as String? ?? '',
      nameEn: j['name_en'] as String? ?? '',
      vargas: (j['vargas'] as List)
                  .map((v) => _parseVarga(v as Map<String, dynamic>))
                  .toList(),
    );

Varga _parseVarga(Map<String, dynamic> j) {
  final shlokaList = (j['shlokas'] as List)
      .map((s) => _parseShloka(s as Map<String, dynamic>))
      .toList();
  return Varga(
    num:        j['seq'] as int,
    id:         j['id'] as String? ?? '',
    name:       j['name_dev'] as String? ?? '',
    verses:     shlokaList.length,
    shlokaList: shlokaList,
  );
}

Verse _parseShloka(Map<String, dynamic> j) {
  final padaA = (j['pada_a'] as String? ?? '');
  final padaB = (j['pada_b'] as String? ?? '');
  final id    = j['id'] as String? ?? '';
  return Verse(
    num:     j['seq'] as int,
    id:      id,
    lines: [
      padaA.isNotEmpty ? padaA : '[पाद १ — $id]',
      padaB.isNotEmpty ? padaB : '[पाद २ — $id]',
    ],
    meaning: '',
    words: (j['words'] as List? ?? [])
               .map((w) => _parseWord(w as Map<String, dynamic>))
               .toList(),
  );
}

AWord _parseWord(Map<String, dynamic> j) => AWord(
      w:        j['w'] as String? ?? '',
      m:        j['artha'] as String? ?? '',
      gender:   j['linga'] as String? ?? '',
      vibhakti: '',
      vacana:   '',
      stem:     j['w'] as String? ?? '',
      note:     '',
    );

// ── Convenience lookups ───────────────────────────────────────────────────────

/// Get all Kandas (async, cached after first load)
Future<List<Kanda>> getKandas() => loadKandas();

/// Get a specific verse by dot-notation ID e.g. "1.1.6"
Future<Verse?> getVerseById(String id) async {
  final kandas = await loadKandas();
  final parts = id.split('.');
  if (parts.length != 3) return null;
  final kNum = int.tryParse(parts[0]);
  final vNum = int.tryParse(parts[1]);
  final sNum = int.tryParse(parts[2]);
  if (kNum == null || vNum == null || sNum == null) return null;
  for (final k in kandas) {
    if (k.num != kNum) continue;
    for (final v in k.vargas) {
      if (v.num != vNum) continue;
      for (final s in v.shlokaList) {
        if (s.num == sNum) return s;
      }
    }
  }
  return null;
}

// ── Legacy synchronous constants (used by screens before async data loads) ───
// These are static placeholder values used during initial render.
// Screens should switch to loadKandas() for real data.

const kSampleVerse = Verse(
  id:      '1.1.6',
  num:     6,
  lines: [
    'स्वरव्ययं स्वर्गनाकत्रिदिवत्रिदशालयाः',
    'सुरलोको द्योदिवौ द्वे स्त्रियां क्लीबे त्रिविष्टपम्',
  ],
  meaning: 'Names of Heaven (स्वर्ग)',
  words: [
    AWord(w:'स्वर्',   m:'heaven',              gender:'अव्य.',  vibhakti:'',vacana:'',stem:'स्वर्',   note:''),
    AWord(w:'स्वर्ग',  m:'heaven',              gender:'पुं.',   vibhakti:'',vacana:'',stem:'स्वर्ग',  note:''),
    AWord(w:'नाक',    m:'heaven (beyond sorrow)',gender:'पुं.',   vibhakti:'',vacana:'',stem:'नाक',    note:''),
    AWord(w:'त्रिदिव', m:'triple heaven',       gender:'पुं.',   vibhakti:'',vacana:'',stem:'त्रिदिव', note:''),
    AWord(w:'त्रिदशालय',m:'abode of the gods',  gender:'पुं.',   vibhakti:'',vacana:'',stem:'त्रिदशालय',note:''),
    AWord(w:'सुरलोक',  m:'world of gods',       gender:'पुं.',   vibhakti:'',vacana:'',stem:'सुरलोक',  note:''),
    AWord(w:'द्यो',    m:'sky / heaven',        gender:'स्त्री.',vibhakti:'',vacana:'',stem:'दिव्',    note:'fem.'),
    AWord(w:'दिव्',    m:'sky / heaven',        gender:'स्त्री.',vibhakti:'',vacana:'',stem:'दिव्',    note:'fem.'),
    AWord(w:'त्रिविष्टप',m:'the three worlds',  gender:'नपुं.',  vibhakti:'',vacana:'',stem:'त्रिविष्टप',note:'neut.'),
  ],
);

// Placeholder synchronous kanda list (1 entry) used by screens that
// haven't yet migrated to the async loadKandas() call.
final kKandas = <Kanda>[
  Kanda(
    num: 1,
    name: 'स्वर्गादिकाण्डः',
    nameEn: 'Svargādi Kāṇḍa',
    vargas: [
      Varga(
        num: 1,
        id: '1.1',
        name: 'स्वर्गवर्गः',
        verses: 66,
        shlokaList: [kSampleVerse],
      ),
    ],
  ),
];

const kTotalVerses = 1436;
const kTotalVargas = 25;
