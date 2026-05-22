#!/usr/bin/env python3
"""Strip unused fields from amarakosha_v3.json.

Removes:
  - Root-level _meta object
  - Per-word fields: linga_en, pada, ref
"""
import json
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
JSON_PATH = os.path.join(SCRIPT_DIR, '..', 'assets', 'data', 'amarakosha_v3.json')
REMOVE_PADA_FIELDS = {'audio_key'}
REMOVE_WORD_FIELDS = {'linga_en', 'pada', 'ref'}

def main():
    before_size = os.path.getsize(JSON_PATH)

    with open(JSON_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    removed_meta = '_meta' in data
    data.pop('_meta', None)

    padas_modified = 0
    words_modified = 0
    for kanda in data.get('kandas', []):
        for varga in kanda.get('vargas', []):
            for section in varga.get('sections', []):
                for pada in section.get('padas', []):
                    had = any(k in pada for k in REMOVE_PADA_FIELDS)
                    for k in REMOVE_PADA_FIELDS:
                        pada.pop(k, None)
                    if had:
                        padas_modified += 1
                    for word in pada.get('words', []):
                        had = any(k in word for k in REMOVE_WORD_FIELDS)
                        for k in REMOVE_WORD_FIELDS:
                            word.pop(k, None)
                        if had:
                            words_modified += 1

    with open(JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

    after_size = os.path.getsize(JSON_PATH)
    saved = before_size - after_size

    print('Done.')
    print(f'  _meta removed:    {removed_meta}')
    print(f'  Padas modified:   {padas_modified}')
    print(f'  Words modified:   {words_modified}')
    print(f'  Size: {before_size:,} -> {after_size:,} bytes  (saved {saved:,} = {saved/before_size*100:.1f}%)')

if __name__ == '__main__':
    main()
