#!/usr/bin/env python3
"""
Separates genuine Jackson-version-attributable serialisation-order changes from JVM
reflection-order noise.

Reads N capture files per version. A class counts as a real version difference only when its
order is IDENTICAL across every run of version A, IDENTICAL across every run of version B, and
the two differ. A class whose order varies between runs of the SAME version is unstable at that
version and cannot be attributed to the upgrade.
"""
import sys
import glob
import collections


def load(path):
    out = {}
    with open(path) as fh:
        for line in fh:
            if line.startswith('#'):
                continue
            parts = line.rstrip('\n').split('\t')
            if len(parts) == 2:
                out[parts[0]] = parts[1]
    return out


def orders_per_class(pattern):
    runs = [load(p) for p in sorted(glob.glob(pattern))]
    assert runs, 'no capture files matched %s' % pattern
    acc = collections.defaultdict(set)
    for r in runs:
        for k, v in r.items():
            acc[k].add(v)
    return acc, len(runs)


a_pat, b_pat, a_label, b_label = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
a, na = orders_per_class(a_pat)
b, nb = orders_per_class(b_pat)

common = sorted(set(a) & set(b))
a_unstable = {k for k in common if len(a[k]) > 1}
b_unstable = {k for k in common if len(b[k]) > 1}
unstable = a_unstable | b_unstable

stable_diff = []
for k in common:
    if k in unstable:
        continue
    if next(iter(a[k])) != next(iter(b[k])):
        stable_diff.append(k)

print('runs: %s=%d  %s=%d' % (a_label, na, b_label, nb))
print('classes compared in both: %d' % len(common))
print('classes whose order is UNSTABLE run-to-run (reflection-order noise): %d'
      % len(unstable))
for k in sorted(unstable):
    print('    NOISE  %s  (%s:%d distinct, %s:%d distinct)'
          % (k, a_label, len(a[k]), b_label, len(b[k])))
print('classes with a STABLE order that DIFFERS between versions: %d' % len(stable_diff))
for k in stable_diff:
    print('    DIFF   %s' % k)
    print('      %-8s %s' % (a_label, next(iter(a[k]))))
    print('      %-8s %s' % (b_label, next(iter(b[k]))))
