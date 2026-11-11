#!/usr/bin/env python3
"""LOCAL fixture generation/negative controls; never calls development wrapper."""
import json,re,subprocess,hashlib
from pathlib import Path
root=Path(__file__).resolve().parent
source=(root/'kgb_zi_capacity_helper.sma').read_text()
templates=re.findall(r'server_print\("(\[ZICAP\][^"\n]+)"',source)
assert len(templates)==24,len(templates)
integers={'version_major':0,'version_minor':1,'version_patch':0,'test_only':1,'slot':1,'slot_a':1,'slot_b':2,'userid':42,'userid_a':42,'userid_b':43,'owned_test_double':1,'real_client':1,'team':2,'joining':0,'solid':3,'world_blocked':0,'round':1,'maximum_slots':12,'limit':11,'previously_owned':1,'accepted':0,'overlap_pairs':0}
positive=[]
for template in templates:
 def replace(m):
  key,fmt=m.groups()
  if fmt=='%d':v=str(integers.get(key,1))
  elif fmt=='%.2f':v='12.34'
  elif key.startswith('depth_'):v='1.250'
  else:v='-100.000' if key.endswith('x') or key=='x' else '36.000'
  return key+'='+v
 line=re.sub(r'([a-z_]+)=(%d|%\.2f|%\.3f)',replace,template)
 assert '%' not in line
 positive.append(line)
base='[ZICAP] event=participant slot=1 userid=42 owned_test_double=1 real_client=0 alive=1 team=2 joining=0 solid=3 spawns_this_round=1 world_blocked=0 round=1'
negative=[
 '', 'normal engine line', '[ZICAP] event=unknown slot=1',
 base+' name=ZombieQA',base+' auth=STEAM_0:1:12345',base+' email=private@example.invalid',
 base+' ip=192.0.2.7',base+' secret=123456', base+' round=2',
 base.replace('slot=1','slot=0'),base.replace('slot=1','slot=33'),base.replace('userid=42','userid=0'),
 base.replace('userid=42','userid=1234567890'),base.replace('slot=1','slot=01'),base.replace('slot=1','slot=-1'),
 base.replace('alive=1','alive=2'),base.replace('real_client=0','real_client=2'),base.replace('joining=0','joining=6'),
 base.replace('solid=3','solid=5'),base.replace('world_blocked=0','world_blocked=2'),base.replace('team=2','team=4'),
 base.replace(' round=1',''),base.replace('slot=1 userid=42','userid=42 slot=1'),base.replace('slot=1','slot=1.0'),
 base+'\x00',base+'\x1b[2J',base+'\r',base+'\n',base.replace('slot=1','slot=1\t'),
 '[ZICAP] event=refused code=0','[ZICAP] event=refused code=10','[ZICAP] event=refused code=7 slot=1',
 '[ZICAP] event=loaded version_major=0 version_minor=1 version_patch=0 test_only=0',
 '[ZICAP] event=loaded version_major=9 version_minor=1 version_patch=0 test_only=1',
 '[ZICAP] event=round_reset round=1 time=NaN', '[ZICAP] event=round_reset round=1 time=INF',
 '[ZICAP] event=round_reset round=1 time=1e3', '[ZICAP] event=round_reset round=1 time=-1.00',
 '[ZICAP] event=round_reset round=1 time=86400000.01', '[ZICAP] event=round_reset round=1 time=1.001',
 '[ZICAP] event=hull slot=1 x=1.000 y=2.000 z=3.000 min_x=4.000 min_y=5.000 min_z=6.000 max_x=7.000 max_y=8.000 max_z=32768.001',
 base+' '*4097, base.replace('slot=1','slot=１'), base.replace('slot=1','slot=1;quit'),
 base.replace('slot=1','slot="1"'), '[ZIQA] '+base,
]
summaries=['[ZICAP] event=counts maximum_slots=32 connected=32 joined=32 pending=0 alive=32 ct_alive=32 t_alive=0 round=2 time=12.34', '[ZICAP] event=ownership real_clients=1 owned_test_doubles=31 foreign_fake=0 unspawned_this_round=0 spawned_owned=31 spawned_real=1 round=2 time=12.34', '[ZICAP] event=collision overlap_pairs=0 world_blocked=0 round=2 time=12.34']
negative += ['[ZICAP] event=snapshot maximum_slots=32', summaries[0]+' real_clients=1', summaries[1].replace('real_clients=1','real_clients=33'), summaries[2].replace('overlap_pairs=0','overlap_pairs=497')]
# All actual source printf formats must fit AMXX server_print's 255-byte
# content budget at the strict extractor's maximum supported numeric bounds.
maxima={'version_major':0,'version_minor':1,'version_patch':0,'test_only':1,'slot':32,'slot_a':32,'slot_b':32,'userid':999999999,'userid_a':999999999,'userid_b':999999999,'owned_test_double':1,'real_client':1,'team':3,'joining':5,'solid':4,'world_blocked':32,'round':999999999,'maximum_slots':32,'limit':31,'previously_owned':1,'accepted':1,'overlap_pairs':496,'spawns_this_round':1000000,'requested':999999999,'created':31,'owned':31,'connected':32,'joined':32,'pending':32,'alive':32,'ct_alive':32,'t_alive':32,'real_clients':32,'owned_test_doubles':31,'foreign_fake':32,'unspawned_this_round':32,'spawned_owned':31,'spawned_real':32}
lengths=[]
for template in templates:
 def longest(m):
  key,fmt=m.groups()
  value=str(maxima[key]) if fmt=='%d' else ('86400000.00' if fmt=='%.2f' else ('256.000' if key.startswith('depth_') else '-32768.000'))
  return key+'='+value
 line=re.sub(r'([a-z_]+)=(%d|%\.2f|%\.3f)',longest,template)
 assert len(line.encode())<180,(len(line),line)
 lengths.append({'event':re.search(r'event=([a-z_]+)',line)[1],'worst_case_bytes':len(line.encode())})
assert 'dllfunc(DLLFunc_ClientConnect, id, alias, \"127.0.0.1\", reject, charsmax(reject))' in source
(root/'print-lengths.json').write_text(json.dumps(lengths,indent=2)+'\n')
(root/'extractor-fixtures.json').write_text(json.dumps({'positive':positive,'negative':negative,'summaries':summaries},indent=2)+'\n')
(root/'zicap-safe-logs-library.php').write_text((root/'extractor.php').read_text())
subprocess.run(['php','-l',str(root/'zicap-safe-logs-library.php')],check=True)
subprocess.run(['php',str(root/'test-extractor.php')],check=True)

# The public parser has no private framework/access adapter. The tested helper
# source is exactly frozen r3; this does not imply that live qualification passed.
assert hashlib.sha256(source.encode()).hexdigest()=='f8f86d7dfa6a72dfb4637407d2a27d46c2d6a0422dd954e5c5bd991e5e684f7a'
parser=(root/'extractor.php').read_text()
for forbidden in ('app()', 'DaemonServerRepository', 'http://', 'https://'):
 assert forbidden not in parser,forbidden
# Explicit TEST-ONLY stdin fixtures: reject identity fields and the whole long
# line, even when its trailing buffer chunk resembles a legitimate record.
stdin=positive[0]+'\r\n'+base+' name=TEST DOUBLE\n'+'x'*5000+positive[0]+'\n'+positive[0]
result=subprocess.run(['php',str(root/'extract.php')],input=stdin,text=True,capture_output=True,check=True)
assert result.stderr==''
records=[json.loads(line) for line in result.stdout.splitlines()]
assert len(records)==3,records
assert records[-1]=={'source':'ZICAP_extractor','event':'local_input_summary','kept_lines':2,'dropped_lines':2},records[-1]
assert all(record['event']=='loaded' for record in records[:-1])
print(json.dumps({'source_is_frozen_r3':True,'public_parser_has_no_private_adapter':True,'cli_fixture_cases':4,'maximum_source_print_bytes':max(v['worst_case_bytes'] for v in lengths),'remote_calls':0}))
