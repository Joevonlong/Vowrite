#!/usr/bin/env python3
"""Check the static site against the pinned content/deployment baseline (stdlib only)."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import hashlib, json, re, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'docs'
BASE = json.loads((DOCS / 'website-assets/content-baseline.json').read_text())
FACTS = json.loads((DOCS / 'website-assets/fact-corrections.json').read_text())
CONSOLIDATION = json.loads((DOCS / 'website-assets/content-consolidation.json').read_text())
errors = []

def check(condition, message):
    if not condition: errors.append(message)

def norm(text):
    return re.sub(r'\s+', ' ', text).strip()

class Node:
    def __init__(self, tag='', attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []
    def all(self, tag=None):
        for child in self.children:
            if isinstance(child, Node):
                if tag is None or child.tag == tag: yield child
                yield from child.all(tag)
    def text(self):
        return ''.join(c.text() if isinstance(c, Node) else c for c in self.children)

class Document(HTMLParser):
    VOID = {'meta','link','img','br','hr','input','source','area','base','embed','wbr','col','param','track'}
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.root = Node(); self.stack = [self.root]; self.feed(source)
    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs); self.stack[-1].children.append(node)
        if tag not in self.VOID: self.stack.append(node)
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID: self.handle_endtag(tag)
    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1, 0, -1):
            if self.stack[i].tag == tag:
                self.stack = self.stack[:i]; break
    def handle_data(self, data): self.stack[-1].children.append(data)

def doc(path): return Document(path.read_text()).root

def spaced(node):
    return norm(" ".join(spaced(c) if isinstance(c, Node) else c for c in node.children))

def tables(page):
    return [[[spaced(c) for c in row.all() if c.tag in ['th','td']] for row in table.all('tr')] for table in page.all('table')]

def doc_fragment(text): return Document(text).root.text()

def tables_node(table):
    return [[spaced(c) for c in row.all() if c.tag in ['th','td']] for row in table.all('tr')]

actual_pages = {name:doc(DOCS / (name+'.html')) for name in [*BASE['pages'], 'demo']}
pages = {name:actual_pages[CONSOLIDATION['contentDestinations'][name]] for name in BASE['pages']}
report = {'baseline':BASE['commit'], 'consolidationBaseline':CONSOLIDATION['baselineCommit'], 'canonicalPages':CONSOLIDATION['canonicalPages'], 'pages':{}, 'redirects':[], 'protected':[], 'errors':errors}
for name, page in pages.items():
    nodes = list(page.all()); ids = [n.attrs['id'] for n in nodes if 'id' in n.attrs]
    check(len(ids) == len(set(ids)), f'{name}: duplicate IDs')
    check(sum(n.tag=='h1' for n in nodes) == 1, f'{name}: expected one h1')
    keys = {n.attrs['data-i18n']:n for n in nodes if 'data-i18n' in n.attrs}
    changes, merged = [], []
    for key, old in BASE['pages'][name]['keys'].items():
        destination = key if key in keys else FACTS.get('replacedComparisonKeys',{}).get(key)
        disposition = CONSOLIDATION['mergedKeys'].get(name+':'+key)
        if destination not in keys and disposition:
            target = urlsplit(disposition['target'])
            check(disposition['sourceText']==old,f'{name}: changed consolidation source {key}')
            check(bool(disposition['reason']),f'{name}: missing consolidation reason {key}')
            check(target.path=='index.html' and any(n.attrs.get('id')==target.fragment for n in actual_pages['index'].all()),f'{name}: missing canonical destination for {key}')
            merged.append({'key':key,**disposition})
            continue
        check(destination in keys, f'{name}: missing content key {key}')
        if destination not in keys: continue
        before = norm(doc_fragment(old)); after = norm(keys[destination].text())
        corrected = FACTS['copy'].get(destination)
        if corrected:
            check(after == norm(doc_fragment(corrected['en'])),f'{name}: incorrect fact {destination}')
            if before != after: changes.append({'key':key,'destination':destination,'before':before,'after':after})
        else:
            check(before == after,f'{name}: unreviewed content change {key}: {before!r} -> {after!r}')
    for command in BASE['pages'][name]['code']:
        check(any(n.text()==command for n in page.all('code')),f'{name}: missing or changed command {command!r}')
    for identifier in BASE['pages'][name]['ids']:
        mapped = CONSOLIDATION['legacyRoutes'].get(name,{}).get(identifier,identifier)
        check(mapped in ids, f'{name}: removed URL anchor #{identifier}')
    for n in nodes:
        for attr in ['href','src']:
            value = n.attrs.get(attr)
            if not value: continue
            parsed = urlsplit(value)
            if parsed.scheme or parsed.netloc: continue
            target = DOCS / unquote(parsed.path.lstrip('/')) if parsed.path else DOCS / (CONSOLIDATION['contentDestinations'][name]+'.html')
            if target == DOCS: target = DOCS / 'index.html'
            if not target.suffix: target = target.with_suffix('.html')
            check(target.is_file() and target.stat().st_size>0,f'{name}: missing link/asset {value}')
            if parsed.fragment and target.is_file() and target.suffix=='.html':
                check(any(x.attrs.get('id')==unquote(parsed.fragment) for x in doc(target).all()),f'{name}: broken fragment {value}')
    report['pages'][name]={'contentPage':CONSOLIDATION['contentDestinations'][name], 'originalKeys':len(BASE['pages'][name]['keys']), 'preservedOrCorrectedKeys':len(BASE['pages'][name]['keys'])-len(merged)-sum(x.startswith(name+': missing content key') for x in errors),'mergedDuplicateKeys':len(merged),'merges':merged,'reviewedChanges':changes,'tableRows':[len(t) for t in tables(page)]}
# Redirect pages contain only a compatibility entry, never another feature body.
home_ids={n.attrs.get('id') for n in actual_pages['index'].all()}
for identifier,target in CONSOLIDATION['homepageAliases'].items():
    check(identifier in home_ids and target in home_ids,f'index: missing compatibility anchor {identifier}')
for key,merged in CONSOLIDATION['mergedSupplementalLabels'].items():
    check(urlsplit(merged['target']).fragment in home_ids and bool(merged['reason']),f'index: missing supplemental merge target {key}')
for name,mapping in CONSOLIDATION['legacyRoutes'].items():
    page=actual_pages[name]
    redirect=next((n for n in page.all('script') if n.attrs.get('id')=='redirect-map'),None)
    check(redirect is not None and json.loads(redirect.text())==mapping,f'{name}: redirect map drift')
    check(all(destination in home_ids for destination in mapping.values()),f'{name}: missing redirect destination')
    check(not any('data-i18n' in n.attrs for n in page.all()),f'{name}: duplicate feature content in compatibility page')
    check(any(n.attrs.get('href')=='index.html#'+mapping[''] for n in page.all('a')),f'{name}: missing no-JavaScript fallback')
    report['redirects'].append({'route':name,'default':mapping[''],'anchors':len(mapping)-1})
for name in CONSOLIDATION['canonicalPages']:
    nav=next(n for n in actual_pages[name].all() if n.attrs.get('id')=='site-navigation')
    hrefs=[n.attrs.get('href') for n in nav.all('a')]
    check(hrefs==['index.html#features','index.html#platforms','pricing.html','index.html#download'],f'{name}: repeated subpage navigation')
# Exact historical pricing cells, row order and all columns, not merely row counts.
check(tables(pages['pricing']) == BASE['pages']['pricing']['tables'], 'pricing: historical table cell/order mismatch')
for name,prefix in [('index','comparison.app'),('translate','comparison.translate')]:
    table = [t for t in pages[name].all('table') if any(n.attrs.get('data-i18n','').startswith(prefix+'.') for n in t.all())][0]
    actual = tables_node(table)
    check(len(actual)==len(BASE['pages'][name]['tables'][0]),f'{name}: comparison row lost')
    check(all(len(row)==5 for row in actual),f'{name}: comparison column lost')
for name,digest in BASE['protected'].items():
    check(hashlib.sha256((DOCS/name).read_bytes()).hexdigest()==digest,f'protected asset changed: {name}')
    report['protected'].append(name)
# Original dictionaries keep every key and value except explicitly reviewed corrections.
source = (DOCS/'i18n.js').read_text().split('function siteHref',1)[0]
current = json.loads(subprocess.check_output(['node','-e',"const vm=require('vm'),fs=require('fs');process.stdout.write(vm.runInNewContext(fs.readFileSync(0,'utf8')+';JSON.stringify(i18n)'))"],input=source.encode()))
for lang,values in BASE['translations'].items():
    for key,value in values.items():
        expected = FACTS['copy'].get(key,{}).get(lang,value)
        check(current.get(lang,{}).get(key)==expected,f'{lang}: dictionary drift {key}')
for key,values in FACTS['copy'].items():
    for lang,value in values.items():check(current[lang].get(key)==value,f'{lang}: missing new copy {key}')
# Four original sentence pairs must remain byte-for-byte unchanged.
sample_source = (DOCS/'website-assets/translation-details.js').read_text()
for sample in BASE['samples']:
    for field in ['textIn','textOut']:check(sample[field] in sample_source,f'translation sample changed: {field}')
if '--json' in sys.argv:print(json.dumps(report,ensure_ascii=False,indent=2))
else:print(f"Website checks: {len(CONSOLIDATION['canonicalPages'])} canonical pages, {len(CONSOLIDATION['legacyRoutes'])} compatible routes, {sum(len(x['keys']) for x in BASE['pages'].values())} original content keys accounted for ({sum(p['mergedDuplicateKeys'] for p in report['pages'].values())} merged duplicates), 77 pricing rows, 4 translation examples, {len(BASE['protected'])} protected assets; {len(errors)} errors")
for error in errors:print('ERROR: '+error,file=sys.stderr)
sys.exit(bool(errors))
