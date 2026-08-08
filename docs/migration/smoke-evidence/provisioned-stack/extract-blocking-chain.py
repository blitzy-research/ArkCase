#!/usr/bin/env python3
# Extracts the causal spine of the object-creation failure from an ArkCase
# log4j2 JSON-lines error log.  Emits one record per line: logger, message and
# the flattened cause chain.  Deterministic: no timestamps of its own, and the
# records are emitted in the order the log holds them.
import json, sys, re

SPINE = (
    'com.armedia.acm.camelcontext.context.CamelContextManager',
    'com.armedia.acm.plugins.ecm.service.impl.EcmFileServiceImpl',
    'com.armedia.acm.plugins.complaint.web.api.CreateComplaintAPIController',
    'com.armedia.acm.web.api.AcmSpringMvcErrorManager',
)

def causes(t, out):
    while t:
        out.append(t.get('name', '?') + ': ' + (t.get('localizedMessage') or '').strip())
        for s in t.get('suppressed') or []:
            out.append('SUPPRESSED ' + s.get('name', '?') + ': ' + (s.get('localizedMessage') or '').strip())
        t = t.get('cause')

def norm(s):
    s = re.sub(r'Exchange\[[0-9A-Fa-f-]+\]', 'Exchange[<EXCHANGE-ID>]', s)
    return re.sub(r'\s+', ' ', s).strip()

lo, hi = int(sys.argv[2]), int(sys.argv[3])
for raw in open(sys.argv[1], errors='replace'):
    raw = raw.lstrip().lstrip(',').strip()
    if not raw.startswith('{'):
        continue
    try:
        r = json.loads(raw)
    except Exception:
        continue
    if r.get('level') != 'ERROR':
        continue
    if not (lo <= r.get('instant', {}).get('epochSecond', 0) <= hi):
        continue
    lg = r.get('loggerName', '')
    if lg not in SPINE:
        continue
    ch = []
    causes(r.get('thrown'), ch)
    print('LOGGER  ' + lg)
    print('MESSAGE ' + norm(r.get('message', '')))
    for i, c in enumerate(ch):
        print('  CAUSE[%d] %s' % (i, norm(c)))
    print('')
