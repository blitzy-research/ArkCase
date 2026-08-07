#!/usr/bin/env python3
"""
Measure the ORM-versus-DDL divergence population.

For every mapped column that exists in BOTH the Liquibase DDL and a JPA @Column annotation,
count the attributes the DDL states and the annotation does not: column length, nullability,
and uniqueness. Emits a per-entity breakdown and the totals.

Deliberate scoping, so the number means something:
  - Only tables that a @Table-annotated @Entity claims are considered.
  - Only columns present on both sides are counted. A DDL column with no annotation is a
    different finding (unmapped column) and is reported separately rather than folded in.
  - Length is only counted for character types, since it is meaningless elsewhere.
  - nullable="true" in the DDL is the JPA default, so it is NOT counted as a divergence;
    only nullable="false" is, because that is the constraint the ORM fails to state.
"""
import os
import re
import sys
import json
import glob
import xml.etree.ElementTree as ET
from collections import defaultdict

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '.')

CHAR_TYPES = ('VARCHAR', 'CHAR', 'NVARCHAR', 'VARCHAR2', 'TEXT', 'CLOB')


def java_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        if 'target' in dirpath.split(os.sep) or 'node_modules' in dirpath.split(os.sep):
            continue
        if os.sep + 'src' + os.sep + 'main' + os.sep + 'java' not in dirpath:
            continue
        for name in filenames:
            if name.endswith('.java'):
                yield os.path.join(dirpath, name)


ENTITY_RE = re.compile(r'@Entity\b')
TABLE_RE = re.compile(r'@Table\s*\(([^)]*)\)', re.S)
NAME_ATTR_RE = re.compile(r'name\s*=\s*"([^"]+)"')
COLUMN_RE = re.compile(r'@Column\s*\(([^)]*)\)', re.S)
JOIN_COLUMN_RE = re.compile(r'@JoinColumn\s*\(([^)]*)\)', re.S)
ID_RE = re.compile(r'@Id\b')


def parse_entities():
    """table name (lower) -> {'file':..., 'module':..., 'columns': {col: attrs-stated}}"""
    entities = {}
    for path in java_files():
        try:
            src = open(path, encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        if not ENTITY_RE.search(src):
            continue
        tm = TABLE_RE.search(src)
        if not tm:
            continue
        nm = NAME_ATTR_RE.search(tm.group(1))
        if not nm:
            continue
        table = nm.group(1).lower()
        cols = {}
        # @JoinColumn is treated as a mapping of the same column, because for the three
        # dimensions counted here it carries exactly the same attributes as @Column and the
        # DDL cannot tell the two apart. Leaving it out would credit a foreign-key column as
        # unmapped rather than as mapped-without-constraints.
        for cm in list(COLUMN_RE.finditer(src)) + list(JOIN_COLUMN_RE.finditer(src)):
            body = cm.group(1)
            cn = NAME_ATTR_RE.search(body)
            if not cn:
                continue
            key = cn.group(1).lower()
            attrs = {
                'length': 'length' in body,
                'nullable': 'nullable' in body,
                'unique': 'unique' in body,
            }
            if key in cols:
                for k in attrs:
                    cols[key][k] = cols[key][k] or attrs[k]
            else:
                cols[key] = attrs
        rel = os.path.relpath(path, ROOT)
        entities[table] = {
            'file': rel,
            'module': rel.split(os.sep + 'src' + os.sep)[0],
            'columns': cols,
        }
    return entities


def strip_ns(tag):
    return tag.split('}', 1)[-1]


def parse_ddl():
    """table name (lower) -> {col: {'length':int|None,'notnull':bool,'unique':bool,'type':str}}"""
    ddl = defaultdict(dict)
    files = [p for p in glob.glob(os.path.join(ROOT, '**', '*.xml'), recursive=True)
             if os.sep + 'ddl' + os.sep in p and os.sep + 'target' + os.sep not in p]
    for path in files:
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            continue
        for ct in tree.iter():
            # addColumn is included alongside createTable because the schema is built
            # incrementally: later changelogs add columns to tables created earlier, and a
            # column added that way is no less part of the authoritative DDL. Omitting it was
            # the largest single source of undercounting in the first version of this script.
            if strip_ns(ct.tag) not in ('createTable', 'addColumn'):
                continue
            table = (ct.get('tableName') or '').lower()
            if not table:
                continue
            for col in ct:
                if strip_ns(col.tag) != 'column':
                    continue
                cname = (col.get('name') or '').lower()
                if not cname:
                    continue
                ctype = (col.get('type') or '').upper()
                length = None
                lm = re.search(r'\(\s*([0-9]+)\s*\)', ctype)
                if lm and any(ctype.startswith(t) for t in CHAR_TYPES):
                    length = int(lm.group(1))
                elif any(ctype.startswith(t) for t in CHAR_TYPES) and '${' in (col.get('type') or ''):
                    length = -1          # parameterised length, still a stated length
                notnull = False
                unique = False
                for con in col:
                    if strip_ns(con.tag) != 'constraints':
                        continue
                    if (con.get('nullable') or '').lower() == 'false':
                        notnull = True
                    if (con.get('unique') or '').lower() == 'true':
                        unique = True
                    if (con.get('primaryKey') or '').lower() == 'true':
                        notnull = True
                ddl[table][cname] = {
                    'length': length,
                    'notnull': notnull,
                    'unique': unique,
                    'type': ctype,
                    'file': os.path.relpath(path, ROOT),
                }
    # Out-of-line constraints are part of the same authoritative DDL and are folded onto the
    # column they name. Without these, a uniqueness or nullability rule expressed as its own
    # changeset rather than inline on the column would be invisible to this measurement.
    for path in files:
        try:
            tree = ET.parse(path)
        except ET.ParseError:
            continue
        for node in tree.iter():
            tag = strip_ns(node.tag)
            table = (node.get('tableName') or '').lower()
            if not table or table not in ddl:
                continue
            if tag == 'addUniqueConstraint':
                for cname in (node.get('columnNames') or '').split(','):
                    cname = cname.strip().lower()
                    if cname in ddl[table]:
                        ddl[table][cname]['unique'] = True
            elif tag == 'addPrimaryKey':
                for cname in (node.get('columnNames') or '').split(','):
                    cname = cname.strip().lower()
                    if cname in ddl[table]:
                        ddl[table][cname]['notnull'] = True
            elif tag == 'addNotNullConstraint':
                cname = (node.get('columnName') or '').strip().lower()
                if cname in ddl[table]:
                    ddl[table][cname]['notnull'] = True
            elif tag == 'createIndex' and (node.get('unique') or '').lower() == 'true':
                for col in node:
                    if strip_ns(col.tag) == 'column':
                        cname = (col.get('name') or '').strip().lower()
                        if cname in ddl[table]:
                            ddl[table][cname]['unique'] = True
    return ddl


entities = parse_entities()
ddl = parse_ddl()

per_entity = {}
tot_len = tot_null = tot_uniq = 0
matched_tables = 0
matched_cols = 0
unmapped_cols = 0

for table, info in sorted(entities.items()):
    if table not in ddl:
        continue
    matched_tables += 1
    d = ddl[table]
    n_len = n_null = n_uniq = 0
    for col, dattrs in d.items():
        if col not in info['columns']:
            unmapped_cols += 1
            continue
        matched_cols += 1
        o = info['columns'][col]
        if dattrs['length'] is not None and not o['length']:
            n_len += 1
        if dattrs['notnull'] and not o['nullable']:
            n_null += 1
        if dattrs['unique'] and not o['unique']:
            n_uniq += 1
    if n_len or n_null or n_uniq:
        per_entity[table] = {
            'file': info['file'],
            'module': info['module'],
            'length': n_len,
            'nullability': n_null,
            'unique': n_uniq,
            'total': n_len + n_null + n_uniq,
        }
    tot_len += n_len
    tot_null += n_null
    tot_uniq += n_uniq

print('entities with @Entity and @Table            : %d' % len(entities))
print('of those whose table appears in the DDL     : %d' % matched_tables)
print('columns present in BOTH DDL and an @Column  : %d' % matched_cols)
print('DDL columns with no matching @Column        : %d  (separate finding, not counted below)'
      % unmapped_cols)
print()
print('entities carrying at least one omission     : %d' % len(per_entity))
print('omitted length declarations                 : %d' % tot_len)
print('omitted nullability declarations            : %d' % tot_null)
print('omitted uniqueness declarations             : %d' % tot_uniq)
print('TOTAL omitted dimensions                    : %d' % (tot_len + tot_null + tot_uniq))
print()
print('top 15 entities by omission count:')
for t, v in sorted(per_entity.items(), key=lambda kv: -kv[1]['total'])[:15]:
    print('  %-34s %4d  (len %3d, null %3d, uniq %2d)  %s'
          % (t, v['total'], v['length'], v['nullability'], v['unique'],
             os.path.basename(v['file'])))

if len(sys.argv) > 2:
    with open(sys.argv[2], 'w', encoding='utf-8') as fh:
        json.dump({'perEntity': per_entity,
                   'totals': {'length': tot_len, 'nullability': tot_null,
                              'unique': tot_uniq,
                              'total': tot_len + tot_null + tot_uniq,
                              'entitiesWithOmissions': len(per_entity),
                              'entitiesMatched': matched_tables,
                              'columnsCompared': matched_cols,
                              'ddlColumnsUnmapped': unmapped_cols,
                              'entitiesTotal': len(entities)}},
                  fh, indent=2, sort_keys=True)
