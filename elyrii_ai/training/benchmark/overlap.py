"""Report exact/lexical near overlaps; never claim semantic decontamination.

Accept explicitly supplied JSON/JSONL training exports with text, prompt, or
messages fields. Tokenized Arrow datasets must first be decoded/exported by the
owner using the training tokenizer. No training corpus is downloaded implicitly.
"""
import argparse
import hashlib
import itertools
import json
import re
import unicodedata
from pathlib import Path

from .build import ROOT


def normalize(text):
    return ' '.join(re.findall(r'\w+',unicodedata.normalize('NFKC',text).casefold()))


def shingles(text, width=3):
    words=normalize(text).split()
    return {tuple(words[i:i+width]) for i in range(max(1,len(words)-width+1))}


def similarity(a,b):
    sa,sb=shingles(a),shingles(b)
    return len(sa & sb)/len(sa | sb) if sa | sb else 0.0


def read_training(path):
    if path.suffix not in {'.json','.jsonl'}:
        raise ValueError('Training input must be an explicit JSON or JSONL export')
    if path.suffix=='.jsonl':
        rows=[json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    else:
        rows=json.loads(path.read_text())
        if isinstance(rows,dict): rows=rows.get('data',rows.get('examples',rows.get('messages') and [rows]))
    if not isinstance(rows,list): raise ValueError('Training export must contain a record list')
    for index,row in enumerate(rows):
        if isinstance(row,str): texts=[row]
        elif isinstance(row,dict) and isinstance(row.get('messages'),list):
            texts=[m['content'] for m in row['messages'] if isinstance(m,dict) and isinstance(m.get('content'),str)]
            if len(texts)!=len(row['messages']): raise ValueError(f'Malformed messages at row {index}')
        elif isinstance(row,dict): texts=[row[k] for k in ('text','prompt') if isinstance(row.get(k),str)]
        else: texts=[]
        if not texts or not any(t.strip() for t in texts): raise ValueError(f'No usable training text at row {index}')
        for j,t in enumerate(texts):
            if t.strip(): yield f'{path.name}:{index}:{j}',t


def audit(cases, training_paths=(), threshold=0.75):
    if not 0<threshold<=1: raise ValueError('Threshold must be in (0,1]')
    # Include both complete fixed conversations and their final user turns.
    bench=[(c['id'],c['split'],variant,text) for c in cases for variant,text in [
        ('conversation','\n'.join(m['content'] for m in c['messages'])),
        ('final_user',c['messages'][-1]['content'])] if variant=='conversation' or len(c['messages'])>1]
    findings=[]
    for a,b in itertools.combinations(bench,2):
        if a[0]==b[0]: continue
        score=similarity(a[3],b[3])
        exact=normalize(a[3])==normalize(b[3])
        if exact or score>=threshold:
            findings.append({'left':a[0],'right':b[0],'left_variant':a[2],'right_variant':b[2], 'exact':exact,'similarity':round(score,4),'cross_split':a[1]!=b[1]})
    corpus=[]; overlaps=[]; total=0
    for path in training_paths:
        records=list(read_training(path)); total+=len(records)
        corpus.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'text_records':len(records)})
        for ref,text in records:
            for cid,split,variant,value in bench:
                score=similarity(text,value);exact=normalize(text)==normalize(value)
                if exact or score>=threshold:
                    overlaps.append({'case_id':cid,'variant':variant,'split':split,'training_record':ref,'exact':exact,'similarity':round(score,4)})
    return {'method':'NFKC/casefold word normalization; word-trigram Jaccard','threshold':threshold,
            'limitations':'Lexical candidate screening only; no semantic or cross-language guarantee. Entire long records may dilute substring overlaps. Human review required.',
            'training_status':'scanned_explicit_exports' if corpus else 'not_established_no_training_exports_supplied',
            'training_files':corpus,'training_text_records':total,'suite_findings':findings,'training_findings':overlaps}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite',type=Path,default=ROOT/'cases.json')
    parser.add_argument('--training',type=Path,action='append',default=[])
    parser.add_argument('--threshold',type=float,default=.75)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    report=audit(json.loads(args.suite.read_text())['cases'],args.training,args.threshold)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(f"Suite findings: {len(report['suite_findings'])}; training findings: {len(report['training_findings'])}; {report['training_status']}")

if __name__=='__main__': main()
