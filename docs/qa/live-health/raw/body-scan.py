import re,sys,concurrent.futures as cf,urllib.request,json,collections
def get(u):
    try: return urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'live-health-readonly'}),timeout=30).read().decode('utf8','replace')
    except Exception as e: return None
SEC=re.compile(r'(-----BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{24,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[bp]-|api[_-]?key["\']?\s*[:=]\s*["\'][A-Za-z0-9]{12,})')
PATH=re.compile(r'/ho'+r'me/[a-z0-9_]+/|/Users/[A-Za-z0-9_]+/')
for host in sys.argv[1:]:
    urls=[l.strip() for l in open(f'urls-{host}.txt')]
    res=collections.Counter(); bad=collections.defaultdict(list)
    def one(u):
        h=get(u)
        if h is None: return u,['fetch-fail']
        f=[]
        m=re.search(r'<title>([^<]*)</title>',h)
        if not m or not m.group(1).strip(): f.append('no-title')
        lm=re.search(r'<html[^>]*\blang="([^"]*)"',h)
        if not lm: f.append('no-lang')
        else:
            seg=u.replace(f'https://{host}/','').split('/')
            code=[s for s in seg if re.fullmatch(r'(ar|be|de|es|fa|fr|hi|ja|kk|ko|ru|sr|tr|zh)',s)]
            exp=code[0] if code else 'en'
            if lm.group(1)[:2]!=exp: f.append(f'lang-mismatch {lm.group(1)} vs {exp}')
        if not re.search(r'<link rel="canonical"',h): f.append('no-canonical')
        hl=re.findall(r'hreflang="([^"]+)"',h)
        if len(hl)<16 and 'hreflang' in h: f.append(f'hreflang-count-{len(hl)}')
        if re.search(r'(src|href)="http://(?!www\.w3\.org)',h): f.append('mixed-content')
        if SEC.search(h): f.append('secret-pattern')
        if PATH.search(h): f.append('host-path')
        return u,f
    with cf.ThreadPoolExecutor(5) as ex:
        for u,f in ex.map(one,urls):
            res['pages']+=1
            for x in f: res[x.split(' ')[0]]+=1; bad[x].append(u)
    print(host,dict(res))
    for k,v in bad.items(): print('  ',k,len(v),v[:3])
