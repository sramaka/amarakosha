import sys, json
sys.stdout.reconfigure(encoding='utf-8')

data = json.load(open('c:/data/amarakosha/assets/data/amarakosha_v3.json', encoding='utf-8'))
k1 = data['kandas'][0]
total = sum(sum(len(s['padas']) for s in v['sections']) for v in k1['vargas'])
print(f'Kanda 1 total padas: {total}')
print(f'Vargas: {len(k1["vargas"])}')
for i, v in enumerate(k1['vargas']):
    padas = [p for s in v['sections'] for p in s['padas']]
    first_id = padas[0]['id'] if padas else 'N/A'
    last_id = padas[-1]['id'] if padas else 'N/A'
    vname = v.get('name_dev', v.get('name', ''))[:30]
    print(f'  Varga {i+1} ({vname}): {len(padas)} padas, ids {first_id}..{last_id}')
