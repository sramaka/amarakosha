// lib/data/repositories/static_data.dart
// Loads amarakosha_v3.json  (Kanda → Varga → Section → Pada model)

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/entities.dart';

// ── In-memory cache ──────────────────────────────────────────────────────────
List<Kanda>? _cache;

Future<List<Kanda>> loadKandas() async {
  if (_cache != null) return _cache!;
  final raw  = await rootBundle.loadString('assets/data/amarakosha_v3.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  _cache = (data['kandas'] as List)
      .map((k) => Kanda.fromJson(k as Map<String, dynamic>))
      .toList();
  return _cache!;
}

// ── Fast lookups ──────────────────────────────────────────────────────────────
Future<Pada?> getPadaById(String padaId) async {
  final kandas = await loadKandas();
  for (final k in kandas)
    for (final v in k.vargas)
      for (final s in v.sections)
        for (final p in s.padas)
          if (p.id == padaId) return p;
  return null;
}

// ── Synchronous constants (used before async load completes) ─────────────────
const kTotalPadas    = 2865;
const kTotalSections = 63;
const kTotalVargas   = 25;

// Minimal bootstrap data for immediate screen render
const kBootstrapPada = Pada(
  id: '1.1.11', legacyId: '1.1.6.1', audioKey: '1-1-6-1',
  seq: 1, shlokaId: '1.1.6', padaNum: 1,
  textDev:  'स्वरव्ययं स्वर्गनाकत्रिदिवत्रिदशालयाः',
  textIast: 'svaravyayaṃ svarganākatridivatridaśālayāḥ',
  words: [
    AWord(w:'स्वर्',    m:'heaven',        gender:'अव्य.', vibhakti:'0', vacana:'avyaya', stem:'svar',          note:'avyaya',   formIast:'svar',      caseEn:'avyaya'),
    AWord(w:'स्वर्ग',   m:'heaven',        gender:'पुं.',  vibhakti:'1', vacana:'pl',     stem:'svarga',         note:'nom.pl.m', formIast:'svargāḥ',   caseEn:'nominative plural masculine'),
    AWord(w:'नाक',      m:'heaven',        gender:'पुं.',  vibhakti:'1', vacana:'pl',     stem:'nāka',           note:'nom.pl.m', formIast:'nākāḥ',     caseEn:'nominative plural masculine'),
    AWord(w:'त्रिदिव',  m:'triple heaven', gender:'पुं.',  vibhakti:'1', vacana:'pl',     stem:'tridiva',        note:'nom.pl.m', formIast:'tridivāḥ',  caseEn:'nominative plural masculine'),
    AWord(w:'त्रिदशालय',m:'abode of gods', gender:'पुं.',  vibhakti:'1', vacana:'pl',     stem:'tridaśālaya',    note:'nom.pl.m', formIast:'tridaśālayāḥ', caseEn:'nominative plural masculine'),
  ],
);

const kBootstrapSection = Section(
  id: '1.1.1', seq: 1, titleEn: 'Heaven',
  padas: [kBootstrapPada],
);

const kBootstrapVarga = Varga(
  id: '1.1', seq: 1, name: 'स्वर्गवर्गः',
  sections: [kBootstrapSection],
);

const kBootstrapKanda = Kanda(
  num: 1, name: 'स्वर्गादिकाण्डः', nameEn: 'Svargādi Kāṇḍa',
  vargas: [kBootstrapVarga],
);

final kBootstrapKandas = <Kanda>[kBootstrapKanda];

// Legacy aliases used by home/browse screens before async data arrives
final kKandas = kBootstrapKandas;
