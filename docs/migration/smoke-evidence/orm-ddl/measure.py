#!/usr/bin/env python3
"""
Measure the divergence between the EFFECTIVE Liquibase schema and the STRUCTURAL
JPA mapping, for the ArkCase reactor.

WHY THIS SCRIPT WAS REWRITTEN
=============================
An earlier revision of this measurement counted three attributes over a flat scrape
of both sides, and a review established that its population was not authoritative.
Every one of the following was true of it, and every one of them is fixed here:

  * it keyed entity results by TABLE, so the 91 classes carrying both @Entity and
    @Table collapsed into 88 rows and three classes disappeared from the count;
  * it discovered DDL by globbing every *.xml whose path contained a "/ddl/"
    segment, so the 13 live changelogs under "/dml/" -- which rename a table and
    drop a unique key -- were invisible to it;
  * the glob result was unsorted, so two runs on two machines could disagree;
  * repeated definitions were last-write-wins with no record, and this repository
    re-creates the same table in several changelogs;
  * it ignored the changeSet dbms attribute, which 432 of the 1020 changeSets
    carry, so oracle-only and mssql-only definitions were folded into a model of a
    MySQL deployment;
  * it ignored modifyDataType, renameColumn, renameTable, dropColumn, dropTable,
    dropUniqueConstraint, dropNotNullConstraint, dropPrimaryKey, dropIndex and
    dropDefaultValue, so the model was a union of everything ever declared rather
    than the schema that actually results;
  * it ignored preconditions, so changeSets that are marked ran rather than
    executed were applied anyway;
  * it recorded whether an annotation attribute NAME occurred in the annotation
    text rather than its VALUE, so an @Column(length = 4000) against a DDL
    VARCHAR(255) read as agreement;
  * and it FLATTENED composite constraints onto each named column, so a composite
    unique key over (parent_id, child_id) was recorded as uniqueness on each of
    them separately.  That last one is not a rounding error: it is what hid six
    real ORM-to-DDL cardinality mismatches, because a JPA column declared
    unique = true looked satisfied by a composite key that does not constrain it.

WHAT THIS SCRIPT DOES
=====================
1. It resolves the real changelog graph.  Liquibase is wired three times in this
   reactor -- once for the core schema and once for each of the two extension
   applications -- and each root is walked in execution order through its include
   and includeAll elements, with classpath resource semantics and a deterministic
   sort.
2. It resolves changelog properties with their dbms filters, first definition
   winning, and records every placeholder it could not resolve.
3. It applies every structural operation, in graph order, to a schema model:
   creates, adds, modifies, renames, drops, keys, uniques, not-nulls, indexes,
   foreign keys and defaults.  Composite constraints stay composite.
4. It evaluates the preconditions it can evaluate against that model, and records
   the ones it cannot rather than pretending the changeSet ran.
5. It parses the Java mapping structurally: annotation bodies are scanned with a
   balanced-delimiter reader so nested annotations survive, attribute VALUES are
   read, comments are stripped first, inheritance and mapped superclasses are
   resolved so a subclass's columns land in the table it actually shares, and
   join tables, collection tables and element collections receive their own
   columns instead of being credited to the owning entity.
6. It reports what diverges, and -- separately -- what it does not model.

WHAT THIS SCRIPT DOES NOT MODEL, STATED SO THE OUTPUT CANNOT BE OVERREAD
========================================================================
  * 159 <sql> blocks and 30 <createProcedure> blocks are opaque.  Their text is
    not interpreted, so a schema change made in raw SQL is invisible to the model
    and is counted and reported as an un-modelled operation instead.
  * <insert>, <update> and <delete> are data, not schema, and are counted only.
  * sqlCheck preconditions cannot be evaluated without a database.
  * Liquibase's own runtime ordering across jar boundaries for a classpath*:
    includeAll is not fully determined by the sources; this model sorts by
    resource path and says so.
  * The model is built for ONE target DBMS at a time (default mysql, the deployed
    one).  It is not a claim about any other DBMS.

usage:  measure.py [REPO_ROOT] [JSON_OUT] [--dbms NAME] [--roots core,extension-foia,...]

  --roots restricts the model to a subset of the three wired roots.  It exists so
  that a reader can reproduce the schema of a deployment that loads only some of
  them: "--roots core" models the core application alone, and the difference
  between that and the full three-root model is exactly the extension surface.
"""
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections import OrderedDict, defaultdict

# ---------------------------------------------------------------------------
# constants
# ---------------------------------------------------------------------------

# Character types are the only ones for which a declared length is meaningful,
# which is why length divergence is scoped to them.
CHAR_TYPES = ('VARCHAR', 'CHAR', 'NVARCHAR', 'VARCHAR2', 'TEXT', 'CLOB', 'NCLOB',
              'LONGTEXT', 'MEDIUMTEXT', 'TINYTEXT')

# The three roots below are each wired to their own SpringLiquibase bean.  They
# are named by resource path rather than by file path because that is how the
# beans name them.
ROOT_CHANGELOGS = (
    ('core', 'ddl/acm-database-changelog.xml'),
    ('extension-foia',
     'com/armedia/acm/extension/foia/ddl/acm-extension-foia-database-changelog.xml'),
    ('extension-privacy',
     'com/armedia/acm/extension/privacy/ddl/acm-extension-privacy-database-changelog.xml'),
)

RESOURCE_SEGMENT = os.sep + 'src' + os.sep + 'main' + os.sep + 'resources' + os.sep
JAVA_SEGMENT = os.sep + 'src' + os.sep + 'main' + os.sep + 'java' + os.sep
SKIP_DIRS = ('target', 'node_modules', '.git', 'build')

STRUCTURAL_OPS = (
    'createTable', 'addColumn', 'modifyDataType', 'renameColumn', 'renameTable',
    'dropColumn', 'dropTable', 'addPrimaryKey', 'dropPrimaryKey',
    'addUniqueConstraint', 'dropUniqueConstraint', 'addNotNullConstraint',
    'dropNotNullConstraint', 'createIndex', 'dropIndex',
    'addForeignKeyConstraint', 'dropForeignKeyConstraint',
    'addDefaultValue', 'dropDefaultValue',
)
OPAQUE_OPS = ('sql', 'sqlFile', 'createProcedure', 'createView', 'dropView')
DATA_OPS = ('insert', 'update', 'delete', 'loadData', 'loadUpdateData')


def strip_ns(tag):
    """Element tag without its namespace."""
    return tag.split('}', 1)[-1]


def walk_files(root, wanted_segment, suffix):
    """Every file under root inside wanted_segment ending in suffix, sorted.

    Sorting is not cosmetic.  An unsorted walk makes the whole measurement
    machine-dependent, which was one of the defects this rewrite exists to fix.
    """
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        if wanted_segment not in dirpath + os.sep:
            continue
        for name in sorted(filenames):
            if name.endswith(suffix):
                found.append(os.path.join(dirpath, name))
    return sorted(found)


# ---------------------------------------------------------------------------
# 1. the classpath resource index
# ---------------------------------------------------------------------------
class ResourceIndex(object):
    """Maps a classpath resource name to the file(s) that provide it.

    Liquibase resolves "classpath*:/com/armedia/acm/ddl/tables" against every
    module on the classpath, so one resource NAME can be provided by more than one
    module.  That is a real property of this reactor -- ten resource names are
    provided twice -- and it is recorded rather than collapsed, because a reader
    who sees one file in the model and two on disk needs to know which.
    """

    def __init__(self, root):
        self.root = root
        self.by_name = defaultdict(list)
        for path in walk_files(root, RESOURCE_SEGMENT, '.xml'):
            rel = path.split(RESOURCE_SEGMENT, 1)[1].replace(os.sep, '/')
            self.by_name[rel].append(path)
        for name in self.by_name:
            self.by_name[name].sort()

    def is_changelog(self, path):
        try:
            with open(path, encoding='utf-8', errors='replace') as handle:
                return '<databaseChangeLog' in handle.read(4096)
        except OSError:
            return False

    def changelog_names(self):
        names = []
        for name, paths in self.by_name.items():
            if any(self.is_changelog(p) for p in paths):
                names.append(name)
        return sorted(names)

    def resolve_file(self, name):
        return list(self.by_name.get(name, ()))

    def resolve_directory(self, directory):
        """Every changelog resource directly inside a resource directory, sorted.

        includeAll here is NOT a subtree walk, and that is corroborated by the
        deployment rather than assumed: the archived startup captures show
        Liquibase 3.1.1 emitting "included file classpath:/ddl/acm-database-
        changelog.xml//com/armedia/acm/ddl/tables/person is not a recognized file
        type" for each SUBDIRECTORY of an includeAll path, which is what a
        non-recursive listing that hands directories to the parser looks like.
        The subdirectory changelogs are reached instead through per-module
        aggregator changelogs that <include> them with
        relativeToChangelogFile="true", and those includes are followed here.

        The sort is by resource name, which is what Liquibase's default comparator
        does with the names it is handed; the honest caveat is that the ORDER IN
        WHICH THE CLASSPATH ITSELF yields two providers of the same name is not
        determined by the sources, and that is stated in the report rather than
        silently assumed away.
        """
        prefix = directory.rstrip('/') + '/'
        names = []
        for name in self.by_name:
            if not name.startswith(prefix):
                continue
            if '/' in name[len(prefix):]:
                continue
            if any(self.is_changelog(p) for p in self.by_name[name]):
                names.append(name)
        return sorted(names)


# ---------------------------------------------------------------------------
# 2. changelog parameters, with dbms filtering
# ---------------------------------------------------------------------------
class Parameters(object):
    """Changelog parameters, resolved for one target DBMS.

    Liquibase 3.x keeps the FIRST value set for a key and ignores later ones, so
    a property redefined for an already-matched key does not overwrite it.  This
    repository contains one genuine instance of that -- classNameType is defined
    twice in a way that both definitions match mysql -- and the resolution order
    is therefore part of the effective schema rather than a detail.
    """

    PLACEHOLDER = re.compile(r'\$\{([^{}]+)\}')

    def __init__(self, dbms):
        self.dbms = dbms
        self.values = OrderedDict()
        self.shadowed = []
        self.unresolved = defaultdict(int)

    def dbms_matches(self, spec):
        if not spec:
            return True
        spec = self.expand(spec)
        listed = [s.strip().lower() for s in spec.split(',') if s.strip()]
        if not listed:
            return True
        negated = [s[1:] for s in listed if s.startswith('!')]
        positive = [s for s in listed if not s.startswith('!')]
        if self.dbms in negated:
            return False
        if not positive:
            return True
        return self.dbms in positive

    def define(self, name, value, dbms_spec, source):
        if not self.dbms_matches(dbms_spec):
            return
        if name in self.values:
            # De-duplicated: the three roots each re-read the shared property
            # changelogs, and reporting one shadowing three times would misstate
            # one condition as three.
            entry = OrderedDict((
                ('property', name),
                ('ignoredValue', value),
                ('keptValue', self.values[name]),
                ('source', source),
            ))
            if entry not in self.shadowed:
                self.shadowed.append(entry)
            return
        self.values[name] = value

    def expand(self, text):
        if text is None or '${' not in text:
            return text
        seen = set()
        result = text
        for _ in range(10):
            def replace(match):
                key = match.group(1)
                if key in self.values:
                    return self.values[key]
                seen.add(key)
                return match.group(0)
            new = self.PLACEHOLDER.sub(replace, result)
            if new == result:
                break
            result = new
        for key in seen:
            if key not in self.values:
                self.unresolved[key] += 1
        return result


# ---------------------------------------------------------------------------
# 3. the changelog graph, walked in execution order
# ---------------------------------------------------------------------------
class ChangeLogGraph(object):
    """One root changelog, expanded into the ordered list of changeSets it runs."""

    def __init__(self, index, params, root_name, root_resource):
        self.index = index
        self.params = params
        self.root_name = root_name
        self.root_resource = root_resource
        self.visited = []
        self.duplicate_visits = []
        self.missing_includes = []
        self.multi_provider = []
        self.changesets = []          # (resource, file_path, element)
        self._seen = set()

    def build(self):
        for path in self.index.resolve_file(self.root_resource):
            self._visit(self.root_resource, path)
        return self

    def _parse(self, path):
        try:
            return ET.parse(path).getroot()
        except (ET.ParseError, OSError):
            return None

    def _visit(self, resource, path):
        key = resource
        if key in self._seen:
            self.duplicate_visits.append(resource)
            return
        self._seen.add(key)
        self.visited.append(resource)
        root = self._parse(path)
        if root is None:
            return
        for node in list(root):
            tag = strip_ns(node.tag)
            if tag == 'property':
                self.params.define(node.get('name'), node.get('value'),
                                   node.get('dbms'), resource)
            elif tag == 'include':
                self._include(resource, node)
            elif tag == 'includeAll':
                self._include_all(resource, node)
            elif tag == 'changeSet':
                self.changesets.append((resource, path, node))

    def _relative(self, base_resource, target):
        base_dir = base_resource.rsplit('/', 1)[0] if '/' in base_resource else ''
        joined = (base_dir + '/' + target) if base_dir else target
        parts = []
        for piece in joined.split('/'):
            if piece in ('', '.'):
                continue
            if piece == '..':
                if parts:
                    parts.pop()
                continue
            parts.append(piece)
        return '/'.join(parts)

    def _strip_scheme(self, value):
        for scheme in ('classpath*:', 'classpath:'):
            if value.startswith(scheme):
                value = value[len(scheme):]
        return value.lstrip('/')

    def _include(self, base_resource, node):
        target = self.params.expand(node.get('file') or '')
        if not target:
            return
        relative = (node.get('relativeToChangelogFile') or 'false').lower() == 'true'
        name = self._relative(base_resource, target) if relative \
            else self._strip_scheme(target)
        paths = self.index.resolve_file(name)
        if not paths:
            self.missing_includes.append(name)
            return
        if len(paths) > 1:
            self.multi_provider.append(OrderedDict((('resource', name),
                                                    ('providers', len(paths)))))
        for path in paths:
            self._visit(name, path)

    def _include_all(self, base_resource, node):
        target = self.params.expand(node.get('path') or '')
        if not target:
            return
        relative = (node.get('relativeToChangelogFile') or 'false').lower() == 'true'
        directory = self._relative(base_resource, target) if relative \
            else self._strip_scheme(target)
        for name in self.index.resolve_directory(directory):
            paths = self.index.resolve_file(name)
            if len(paths) > 1:
                self.multi_provider.append(
                    OrderedDict((('resource', name), ('providers', len(paths)))))
            for path in paths:
                self._visit(name, path)


# ---------------------------------------------------------------------------
# 4. the effective schema model
# ---------------------------------------------------------------------------
LENGTH_RE = re.compile(r'\(\s*(\d+)\s*(?:,\s*(\d+)\s*)?\)')


def parse_type(raw):
    """(base, length, precision, scale) from a Liquibase type string."""
    if raw is None:
        return ('', None, None, None)
    text = raw.strip()
    upper = text.upper()
    base = re.split(r'[\s(]', upper, maxsplit=1)[0]
    match = LENGTH_RE.search(upper)
    length = precision = scale = None
    if match:
        first = int(match.group(1))
        second = int(match.group(2)) if match.group(2) is not None else None
        if second is None:
            if base.startswith(CHAR_TYPES):
                length = first
            else:
                precision = first
        else:
            precision, scale = first, second
    elif '${' in text and base.startswith(CHAR_TYPES):
        # A parameterised length is still a STATED length; recording it as absent
        # would credit the DDL with saying nothing where it says something.
        length = -1
    return (base, length, precision, scale)


class Table(object):
    def __init__(self, name):
        self.name = name
        self.columns = OrderedDict()      # lower name -> dict
        self.primary_key = None           # (constraintName, (cols,))
        self.uniques = []                 # [(constraintName, (cols,))]
        self.indexes = []                 # [(indexName, (cols,), unique)]
        self.foreign_keys = []            # [(name, (base,), refTable, (refCols,))]
        self.created_by = []              # provenance of every createTable
        self.dropped = False


class SchemaModel(object):
    """The schema that RESULTS from running the graph, not the union of declarations."""

    def __init__(self, params):
        self.params = params
        self.tables = OrderedDict()
        self.applied = 0
        self.skipped_dbms = 0
        self.skipped_precondition = 0
        self.opaque_ops = defaultdict(int)
        self.data_ops = defaultdict(int)
        self.structural_ops = defaultdict(int)
        self.unknown_ops = defaultdict(int)
        self.fail_on_error_false = []
        self.repeated_definitions = defaultdict(list)   # table -> [provenance]
        self.conflicting_types = []
        self.unevaluable_preconditions = []
        self.operations_on_absent_table = []
        self.changesets_seen = 0
        # Liquibase identifies an executed changeSet by (filePath, id, author) in
        # DATABASECHANGELOG, so a changeSet reachable from two roots runs ONCE.
        # Without this the three roots each replay the core graph and every count
        # downstream is multiplied -- which is a different way of being wrong from
        # the revision this replaces, and no less wrong.
        self.executed = set()
        self.skipped_already_executed = 0
        # Counted rather than assumed away.  A changeSet context would change which
        # changeSets run, so a model that ignored contexts would be unsound; this
        # repository declares none, and the count proves it rather than asserting it.
        self.contexts_declared = 0

    # -- helpers ---------------------------------------------------------------
    def table(self, name, create=False, provenance=None):
        if not name:
            return None
        key = name.lower()
        if key not in self.tables:
            if not create:
                return None
            self.tables[key] = Table(key)
        found = self.tables[key]
        if create:
            found.created_by.append(provenance)
            found.dropped = False
        return found

    def _note_absent(self, op, name, provenance):
        self.operations_on_absent_table.append(OrderedDict((
            ('operation', op), ('table', (name or '').lower()),
            ('changeSet', provenance))))

    # -- precondition evaluation ---------------------------------------------
    def evaluate_preconditions(self, node, provenance):
        """True when the changeSet should run, False when it is marked ran.

        Only the checks a static model can honestly make are made.  sqlCheck needs
        a database and is recorded as unevaluable, and an unevaluable precondition
        makes the changeSet RUN -- which is the conservative choice for a schema
        model, because skipping it would silently drop real structure.
        """
        outcome = self._evaluate(node, provenance)
        return outcome is not False

    def _evaluate(self, node, provenance):
        results = []
        for child in list(node):
            tag = strip_ns(child.tag)
            if tag == 'and':
                results.append(self._evaluate(child, provenance))
            elif tag == 'or':
                inner = [self._evaluate(c, provenance) for c in list(child)]
                if any(v is True for v in inner):
                    results.append(True)
                elif all(v is False for v in inner) and inner:
                    results.append(False)
                else:
                    results.append(None)
            elif tag == 'not':
                inner = self._evaluate(child, provenance)
                results.append(None if inner is None else (not inner))
            elif tag == 'dbms':
                results.append(self.params.dbms_matches(child.get('type')))
            elif tag == 'tableExists':
                found = self.table(self.params.expand(child.get('tableName')))
                results.append(bool(found) and not found.dropped)
            elif tag == 'columnExists':
                found = self.table(self.params.expand(child.get('tableName')))
                column = (self.params.expand(child.get('columnName')) or '').lower()
                results.append(bool(found) and column in found.columns)
            elif tag == 'indexExists':
                found = self.table(self.params.expand(child.get('tableName')))
                index = (child.get('indexName') or '').lower()
                names = [i[0].lower() for i in found.indexes if i[0]] if found else []
                results.append(bool(found) and index in names)
            elif tag == 'foreignKeyConstraintExists':
                table_name = child.get('foreignKeyTableName')
                found = self.table(self.params.expand(table_name)) if table_name else None
                key = (child.get('foreignKeyName') or '').lower()
                if found is None:
                    results.append(None)
                else:
                    results.append(key in [f[0].lower() for f in found.foreign_keys if f[0]])
            else:
                self.unevaluable_preconditions.append(OrderedDict((
                    ('precondition', tag), ('changeSet', provenance))))
                results.append(None)
        if any(v is False for v in results):
            return False
        if any(v is None for v in results):
            return None
        return True

    # -- application ---------------------------------------------------------
    def apply_changeset(self, resource, node):
        self.changesets_seen += 1
        if node.get('context') or node.get('contexts'):
            self.contexts_declared += 1
        file_path = node.get('logicalFilePath') or resource
        identity = (file_path, node.get('id'), node.get('author'))
        provenance = '%s::%s::%s' % (resource, node.get('id'), node.get('author'))
        # ORDER MATTERS, and getting it wrong loses real structure.  Liquibase
        # filters by dbms BEFORE it checks changeSet identity, which is why this
        # repository can carry a mysql variant and an oracle variant of the same
        # changeSet id in one file without a duplicate-identifier failure.  Checking
        # identity first would let the oracle variant consume the identity and the
        # mysql variant be discarded -- 105 changeSets, and with them 20 tables and
        # over 500 columns, silently vanished from an earlier draft of this model
        # for exactly that reason.
        if not self.params.dbms_matches(node.get('dbms')):
            self.skipped_dbms += 1
            return
        if identity in self.executed:
            self.skipped_already_executed += 1
            return
        self.executed.add(identity)
        if (node.get('failOnError') or '').lower() == 'false':
            self.fail_on_error_false.append(provenance)
        for child in list(node):
            if strip_ns(child.tag) == 'preConditions':
                if not self.evaluate_preconditions(child, provenance):
                    self.skipped_precondition += 1
                    return
        self.applied += 1
        for child in list(node):
            tag = strip_ns(child.tag)
            if tag in ('preConditions', 'rollback', 'comment', 'validCheckSum'):
                continue
            if tag in OPAQUE_OPS:
                self.opaque_ops[tag] += 1
                continue
            if tag in DATA_OPS:
                self.data_ops[tag] += 1
                continue
            if tag in STRUCTURAL_OPS:
                self.structural_ops[tag] += 1
                getattr(self, '_op_' + tag)(child, provenance)
                continue
            self.unknown_ops[tag] += 1

    def _column_dict(self, element, provenance):
        raw = self.params.expand(element.get('type'))
        base, length, precision, scale = parse_type(raw)
        entry = OrderedDict((
            ('name', (self.params.expand(element.get('name')) or '').lower()),
            ('rawType', raw), ('baseType', base), ('length', length),
            ('precision', precision), ('scale', scale),
            ('notNull', False), ('singleColumnUnique', False),
            ('uniqueConstraintName', None),
            ('default', element.get('defaultValue') or element.get('defaultValueComputed')
             or element.get('defaultValueBoolean') or element.get('defaultValueNumeric')),
            ('autoIncrement', (element.get('autoIncrement') or '').lower() == 'true'),
            ('declaredBy', provenance),
        ))
        for constraints in list(element):
            if strip_ns(constraints.tag) != 'constraints':
                continue
            if (constraints.get('nullable') or '').lower() == 'false':
                entry['notNull'] = True
            if (constraints.get('primaryKey') or '').lower() == 'true':
                entry['notNull'] = True
            if (constraints.get('unique') or '').lower() == 'true':
                entry['singleColumnUnique'] = True
                entry['uniqueConstraintName'] = constraints.get('uniqueConstraintName')
        return entry

    def _op_createTable(self, element, provenance):
        name = self.params.expand(element.get('tableName'))
        existing = self.table(name)
        if existing is not None and not existing.dropped:
            self.repeated_definitions[name.lower()].append(provenance)
        table = self.table(name, create=True, provenance=provenance)
        inline_pk = []
        for child in list(element):
            if strip_ns(child.tag) != 'column':
                continue
            entry = self._column_dict(child, provenance)
            if not entry['name']:
                continue
            previous = table.columns.get(entry['name'])
            if previous is not None and previous['rawType'] != entry['rawType']:
                self.conflicting_types.append(OrderedDict((
                    ('table', table.name), ('column', entry['name']),
                    ('previousType', previous['rawType']),
                    ('newType', entry['rawType']),
                    ('previouslyDeclaredBy', previous['declaredBy']),
                    ('redeclaredBy', provenance))))
            table.columns[entry['name']] = entry
            for constraints in list(child):
                if strip_ns(constraints.tag) != 'constraints':
                    continue
                if (constraints.get('primaryKey') or '').lower() == 'true':
                    inline_pk.append((entry['name'],
                                      constraints.get('primaryKeyName')))
        if inline_pk:
            table.primary_key = (inline_pk[0][1], tuple(c for c, _ in inline_pk))

    def _op_addColumn(self, element, provenance):
        name = self.params.expand(element.get('tableName'))
        table = self.table(name)
        if table is None:
            self._note_absent('addColumn', name, provenance)
            table = self.table(name, create=True, provenance=provenance + ' (implied)')
        for child in list(element):
            if strip_ns(child.tag) != 'column':
                continue
            entry = self._column_dict(child, provenance)
            if entry['name']:
                table.columns[entry['name']] = entry

    def _op_modifyDataType(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        column = (self.params.expand(element.get('columnName')) or '').lower()
        if table is None or column not in table.columns:
            self._note_absent('modifyDataType',
                              element.get('tableName'), provenance)
            return
        raw = self.params.expand(element.get('newDataType'))
        base, length, precision, scale = parse_type(raw)
        entry = table.columns[column]
        entry['rawType'] = raw
        entry['baseType'] = base
        entry['length'] = length
        entry['precision'] = precision
        entry['scale'] = scale

    def _op_renameColumn(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        old = (self.params.expand(element.get('oldColumnName')) or '').lower()
        new = (self.params.expand(element.get('newColumnName')) or '').lower()
        if table is None or old not in table.columns:
            self._note_absent('renameColumn', element.get('tableName'), provenance)
            return
        entry = table.columns.pop(old)
        entry['name'] = new
        table.columns[new] = entry
        table.primary_key = _rename_in_key(table.primary_key, old, new)
        table.uniques = [_rename_in_key(u, old, new) for u in table.uniques]
        table.indexes = [(n, tuple(new if c == old else c for c in cols), uniq)
                         for n, cols, uniq in table.indexes]

    def _op_renameTable(self, element, provenance):
        old = (self.params.expand(element.get('oldTableName')) or '').lower()
        new = (self.params.expand(element.get('newTableName')) or '').lower()
        if old not in self.tables:
            self._note_absent('renameTable', old, provenance)
            return
        table = self.tables.pop(old)
        table.name = new
        table.created_by.append(provenance + ' (renamed from %s)' % old)
        self.tables[new] = table

    def _op_dropColumn(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        column = (self.params.expand(element.get('columnName')) or '').lower()
        if table is None or column not in table.columns:
            self._note_absent('dropColumn', element.get('tableName'), provenance)
            return
        del table.columns[column]

    def _op_dropTable(self, element, provenance):
        name = (self.params.expand(element.get('tableName')) or '').lower()
        table = self.tables.get(name)
        if table is None:
            self._note_absent('dropTable', name, provenance)
            return
        table.dropped = True

    def _op_addPrimaryKey(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        if table is None:
            self._note_absent('addPrimaryKey', element.get('tableName'), provenance)
            return
        columns = _split_columns(self.params.expand(element.get('columnNames')))
        table.primary_key = (element.get('constraintName'), columns)
        for column in columns:
            if column in table.columns:
                table.columns[column]['notNull'] = True

    def _op_dropPrimaryKey(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        if table is not None:
            table.primary_key = None

    def _op_addUniqueConstraint(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        if table is None:
            self._note_absent('addUniqueConstraint',
                              element.get('tableName'), provenance)
            return
        columns = _split_columns(self.params.expand(element.get('columnNames')))
        table.uniques.append((element.get('constraintName'), columns))

    def _op_dropUniqueConstraint(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        if table is None:
            return
        name = (element.get('constraintName') or '').lower()
        table.uniques = [u for u in table.uniques
                         if (u[0] or '').lower() != name]
        for entry in table.columns.values():
            if (entry.get('uniqueConstraintName') or '').lower() == name:
                entry['singleColumnUnique'] = False
                entry['uniqueConstraintName'] = None
        table.indexes = [i for i in table.indexes
                         if not (i[2] and (i[0] or '').lower() == name)]

    def _op_addNotNullConstraint(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        column = (self.params.expand(element.get('columnName')) or '').lower()
        if table is None or column not in table.columns:
            self._note_absent('addNotNullConstraint',
                              element.get('tableName'), provenance)
            return
        table.columns[column]['notNull'] = True

    def _op_dropNotNullConstraint(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        column = (self.params.expand(element.get('columnName')) or '').lower()
        if table is None or column not in table.columns:
            self._note_absent('dropNotNullConstraint',
                              element.get('tableName'), provenance)
            return
        table.columns[column]['notNull'] = False

    def _op_createIndex(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        if table is None:
            self._note_absent('createIndex', element.get('tableName'), provenance)
            return
        columns = tuple((self.params.expand(c.get('name')) or '').lower()
                        for c in list(element) if strip_ns(c.tag) == 'column')
        unique = (element.get('unique') or '').lower() == 'true'
        table.indexes.append((element.get('indexName'), columns, unique))

    def _op_dropIndex(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        if table is None:
            return
        name = (element.get('indexName') or '').lower()
        table.indexes = [i for i in table.indexes if (i[0] or '').lower() != name]

    def _op_addForeignKeyConstraint(self, element, provenance):
        table = self.table(self.params.expand(element.get('baseTableName')))
        if table is None:
            self._note_absent('addForeignKeyConstraint',
                              element.get('baseTableName'), provenance)
            return
        table.foreign_keys.append((
            element.get('constraintName'),
            _split_columns(self.params.expand(element.get('baseColumnNames'))),
            (self.params.expand(element.get('referencedTableName')) or '').lower(),
            _split_columns(self.params.expand(element.get('referencedColumnNames')))))

    def _op_dropForeignKeyConstraint(self, element, provenance):
        table = self.table(self.params.expand(element.get('baseTableName')))
        if table is None:
            return
        name = (element.get('constraintName') or '').lower()
        table.foreign_keys = [f for f in table.foreign_keys
                              if (f[0] or '').lower() != name]

    def _op_addDefaultValue(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        column = (self.params.expand(element.get('columnName')) or '').lower()
        if table is None or column not in table.columns:
            return
        table.columns[column]['default'] = (
            element.get('defaultValue') or element.get('defaultValueNumeric')
            or element.get('defaultValueComputed'))

    def _op_dropDefaultValue(self, element, provenance):
        table = self.table(self.params.expand(element.get('tableName')))
        column = (self.params.expand(element.get('columnName')) or '').lower()
        if table is None or column not in table.columns:
            return
        table.columns[column]['default'] = None

    # -- queries -------------------------------------------------------------
    def live_tables(self):
        return OrderedDict((k, v) for k, v in sorted(self.tables.items())
                           if not v.dropped)

    def explicit_single_column_unique(self, table, column):
        """An explicit uniqueness constraint over this one column alone.

        A composite key over (a, b) does not make a unique, and this returns False
        for that case instead of True.  The primary key is deliberately NOT counted
        here: a single-column primary key is unique by definition and JPA's @Id
        already says so, so reporting "@Id does not also say unique = true" as an
        omission would manufacture one row per entity out of nothing.
        """
        entry = table.columns.get(column)
        if entry is not None and entry['singleColumnUnique']:
            return True
        for _name, columns in table.uniques:
            if len(columns) == 1 and columns[0] == column:
                return True
        for _name, columns, unique in table.indexes:
            if unique and len(columns) == 1 and columns[0] == column:
                return True
        return False

    def single_column_unique(self, table, column):
        """Whether the effective schema constrains this column alone, PK included.

        This is the predicate whose absence hid six defects.  It is the right one
        for judging a JPA unique = true declaration, because a single-column
        primary key does satisfy such a declaration -- whereas a COMPOSITE key
        mentioning the column does not.
        """
        if self.explicit_single_column_unique(table, column):
            return True
        if table.primary_key and len(table.primary_key[1]) == 1 \
                and table.primary_key[1][0] == column:
            return True
        return False

    def composite_uniqueness_covering(self, table, column):
        """Composite keys that MENTION the column without constraining it alone.

        De-duplicated by (kind, name, columns): this repository re-creates several
        join tables in later changelogs, so the same composite key is declared more
        than once and listing it three times would misreport one constraint as
        three.
        """
        covering = []
        for name, columns in table.uniques:
            if len(columns) > 1 and column in columns:
                covering.append(OrderedDict((('kind', 'uniqueConstraint'),
                                             ('name', name),
                                             ('columns', list(columns)))))
        for name, columns, unique in table.indexes:
            if unique and len(columns) > 1 and column in columns:
                covering.append(OrderedDict((('kind', 'uniqueIndex'),
                                             ('name', name),
                                             ('columns', list(columns)))))
        if table.primary_key and len(table.primary_key[1]) > 1 \
                and column in table.primary_key[1]:
            covering.append(OrderedDict((('kind', 'compositePrimaryKey'),
                                         ('name', table.primary_key[0]),
                                         ('columns', list(table.primary_key[1])))))
        unique_covering = []
        seen = set()
        for entry in covering:
            key = (entry['kind'], entry['name'], tuple(entry['columns']))
            if key in seen:
                continue
            seen.add(key)
            unique_covering.append(entry)
        return unique_covering


def _split_columns(value):
    if not value:
        return tuple()
    return tuple(part.strip().lower() for part in value.split(',') if part.strip())


def _rename_in_key(key, old, new):
    if not key:
        return key
    name, columns = key
    return (name, tuple(new if c == old else c for c in columns))


# ---------------------------------------------------------------------------
# 5. structural Java mapping parser
# ---------------------------------------------------------------------------
def strip_comments(source):
    """Remove comments while preserving string and character literals.

    This matters more than it looks.  The previous revision searched raw file text,
    so an annotation inside a Javadoc block or a commented-out mapping counted as a
    mapping, and this repository contains both.
    """
    out = []
    index = 0
    length = len(source)
    while index < length:
        char = source[index]
        if char == '/' and index + 1 < length:
            following = source[index + 1]
            if following == '/':
                end = source.find('\n', index)
                if end < 0:
                    break
                out.append('\n' * source.count('\n', index, end))
                index = end
                continue
            if following == '*':
                end = source.find('*/', index + 2)
                if end < 0:
                    break
                out.append('\n' * source.count('\n', index, end))
                index = end + 2
                continue
        if char in ('"', "'"):
            quote = char
            out.append(char)
            index += 1
            while index < length:
                if source[index] == '\\':
                    out.append(source[index:index + 2])
                    index += 2
                    continue
                out.append(source[index])
                if source[index] == quote:
                    index += 1
                    break
                index += 1
            continue
        out.append(char)
        index += 1
    return ''.join(out)


ANNOTATION_START = re.compile(r'@([A-Za-z_][A-Za-z0-9_.]*)')


def read_balanced(source, start, opener='(', closer=')'):
    """Index just past the balanced group starting at source[start] == opener."""
    depth = 0
    index = start
    length = len(source)
    while index < length:
        char = source[index]
        if char in ('"', "'"):
            quote = char
            index += 1
            while index < length:
                if source[index] == '\\':
                    index += 2
                    continue
                if source[index] == quote:
                    break
                index += 1
        elif char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return length


def scan_annotations(source):
    """[(name, body, end_index)] for every annotation, bodies balanced."""
    found = []
    for match in ANNOTATION_START.finditer(source):
        name = match.group(1).rsplit('.', 1)[-1]
        cursor = match.end()
        while cursor < len(source) and source[cursor] in ' \t\r\n':
            cursor += 1
        if cursor < len(source) and source[cursor] == '(':
            end = read_balanced(source, cursor)
            body = source[cursor + 1:end - 1]
        else:
            end = match.end()
            body = ''
        found.append((name, body, match.start(), end))
    return found


def annotation_attribute(body, attribute):
    """Value of one attribute of an annotation body, or None.

    Nested annotations are skipped over, so the length in
    @JoinTable(joinColumns = @JoinColumn(length = 5)) is not read as the
    JoinTable's own attribute.
    """
    if not body:
        return None
    depth = 0
    index = 0
    length = len(body)
    pattern = re.compile(r'\b' + re.escape(attribute) + r'\s*=')
    while index < length:
        char = body[index]
        if char in ('"', "'"):
            quote = char
            index += 1
            while index < length:
                if body[index] == '\\':
                    index += 2
                    continue
                if body[index] == quote:
                    break
                index += 1
        elif char in '({[':
            depth += 1
        elif char in ')}]':
            depth -= 1
        elif depth == 0:
            match = pattern.match(body, index)
            if match:
                cursor = match.end()
                while cursor < length and body[cursor] in ' \t\r\n':
                    cursor += 1
                start = cursor
                inner = 0
                while cursor < length:
                    current = body[cursor]
                    if current in ('"', "'"):
                        quote = current
                        cursor += 1
                        while cursor < length:
                            if body[cursor] == '\\':
                                cursor += 2
                                continue
                            if body[cursor] == quote:
                                break
                            cursor += 1
                    elif current in '({[':
                        inner += 1
                    elif current in ')}]':
                        if inner == 0:
                            break
                        inner -= 1
                    elif current == ',' and inner == 0:
                        break
                    cursor += 1
                return body[start:cursor].strip()
        index += 1
    return None


def string_value(raw):
    if raw is None:
        return None
    match = re.search(r'"([^"]*)"', raw)
    return match.group(1) if match else None


def int_value(raw):
    if raw is None:
        return None
    match = re.search(r'-?\d+', raw)
    return int(match.group(0)) if match else None


def bool_value(raw):
    if raw is None:
        return None
    text = raw.strip().lower()
    if text.startswith('true'):
        return True
    if text.startswith('false'):
        return False
    return None


def nested_annotations(body, name):
    """Every nested @name(...) inside an annotation body, in order."""
    if not body:
        return []
    found = []
    for annotation, inner, _start, _end in scan_annotations(body):
        if annotation == name:
            found.append(inner)
    return found


class JavaClass(object):
    def __init__(self, name, path, module):
        self.name = name
        self.path = path
        self.module = module
        self.superclass = None
        self.is_entity = False
        self.is_mapped_superclass = False
        self.is_embeddable = False
        self.table = None
        self.table_unique_constraints = []
        self.inheritance = None
        self.discriminator_column = None
        self.discriminator_value = None
        self.own_columns = OrderedDict()       # column -> mapping dict
        self.secondary_tables = defaultdict(OrderedDict)   # table -> columns
        self.relationships = []
        self.generators = []
        self.id_columns = []
        self.embedded_types = []


MEMBER_RE = re.compile(r'[A-Za-z_$][\w$<>\[\],.\s?]*\s+([A-Za-z_$][\w$]*)\s*[;=(]')


def parse_java(path, root):
    source = strip_comments(open(path, encoding='utf-8', errors='replace').read())
    class_match = re.search(
        r'\b(?:public|abstract|final|\s)*\b(class|enum|interface)\s+([A-Za-z_$][\w$]*)'
        r'([^{]*)\{', source)
    if not class_match:
        return None
    kind, name, tail = class_match.group(1), class_match.group(2), class_match.group(3)
    relative = os.path.relpath(path, root).replace(os.sep, '/')
    module = relative.split('/src/')[0]
    holder = JavaClass(name, relative, module)
    extends = re.search(r'\bextends\s+([A-Za-z_$][\w$.]*)', tail)
    if extends:
        holder.superclass = extends.group(1).rsplit('.', 1)[-1]

    annotations = scan_annotations(source)
    class_start = class_match.start()
    for annotation, body, start, _end in annotations:
        if start >= class_start:
            continue
        if annotation == 'Entity':
            holder.is_entity = True
        elif annotation == 'MappedSuperclass':
            holder.is_mapped_superclass = True
        elif annotation == 'Embeddable':
            holder.is_embeddable = True
        elif annotation == 'Table':
            holder.table = (string_value(annotation_attribute(body, 'name')) or '').lower() \
                or None
            for constraint in nested_annotations(body, 'UniqueConstraint'):
                columns = re.findall(r'"([^"]+)"',
                                     annotation_attribute(constraint, 'columnNames') or '')
                if columns:
                    holder.table_unique_constraints.append(
                        tuple(c.lower() for c in columns))
        elif annotation == 'Inheritance':
            strategy = annotation_attribute(body, 'strategy') or ''
            holder.inheritance = strategy.rsplit('.', 1)[-1].strip() or None
        elif annotation == 'DiscriminatorColumn':
            holder.discriminator_column = \
                (string_value(annotation_attribute(body, 'name')) or '').lower() or None
        elif annotation == 'DiscriminatorValue':
            holder.discriminator_value = string_value(body) or string_value(
                annotation_attribute(body, 'value'))
    if kind != 'class' and not holder.is_entity:
        return holder if (holder.is_mapped_superclass or holder.is_embeddable) else None

    _parse_members(holder, source, annotations, class_match.end())
    return holder


def _member_name(source, index):
    match = MEMBER_RE.search(source, index)
    return match.group(1) if match else None


def _parse_members(holder, source, annotations, body_start):
    """Group annotations into per-member blocks and record every mapping."""
    groups = []
    current = []
    previous_end = None
    for annotation, body, start, end in annotations:
        if start < body_start:
            continue
        if previous_end is not None:
            between = source[previous_end:start]
            if between.strip():
                if current:
                    groups.append((current, previous_end))
                current = []
        current.append((annotation, body, start, end))
        previous_end = end
    if current:
        groups.append((current, previous_end))

    for group, end_index in groups:
        names = dict((a, b) for a, b, _s, _e in group)
        member = _member_name(source, end_index)
        target_table = None
        # A join table or collection table owns its own columns; crediting them to
        # the entity's table is exactly the error that hid the cardinality gaps.
        for holder_annotation in ('JoinTable', 'CollectionTable'):
            if holder_annotation in names:
                target_table = (string_value(
                    annotation_attribute(names[holder_annotation], 'name')) or '').lower() \
                    or None
        if 'JoinTable' in names:
            _record_join_table(holder, names, member)
            continue
        if 'TableGenerator' in names:
            holder.generators.append(OrderedDict((
                ('member', member),
                ('table', (string_value(annotation_attribute(
                    names['TableGenerator'], 'table')) or '').lower() or None),
                ('pkColumnName', string_value(annotation_attribute(
                    names['TableGenerator'], 'pkColumnName'))),
                ('valueColumnName', string_value(annotation_attribute(
                    names['TableGenerator'], 'valueColumnName'))))))
        if 'Embedded' in names:
            holder.embedded_types.append(member)
        # An @AttributeOverride re-points an embedded or inherited attribute at a
        # different column, so its column IS part of this class's mapping and
        # omitting it would leave that column looking unmapped.
        for override_holder in ('AttributeOverrides', 'AttributeOverride'):
            if override_holder not in names:
                continue
            body = names[override_holder]
            overrides = nested_annotations(body, 'AttributeOverride') \
                if override_holder == 'AttributeOverrides' else [body]
            for override in overrides:
                inner = annotation_attribute(override, 'column')
                for column_body in (nested_annotations(inner, 'Column')
                                    if inner else []):
                    column = (string_value(annotation_attribute(column_body,
                                                                'name')) or '').lower()
                    if not column:
                        continue
                    holder.own_columns[column] = OrderedDict((
                        ('column', column), ('member', member),
                        ('annotation', 'AttributeOverride/Column'),
                        ('length', int_value(annotation_attribute(column_body,
                                                                  'length'))),
                        ('precision', int_value(annotation_attribute(column_body,
                                                                     'precision'))),
                        ('scale', int_value(annotation_attribute(column_body,
                                                                 'scale'))),
                        ('nullable', bool_value(annotation_attribute(column_body,
                                                                     'nullable'))),
                        ('unique', bool_value(annotation_attribute(column_body,
                                                                   'unique'))),
                        ('insertable', None), ('updatable', None),
                        ('columnDefinition', None), ('elementCollection', False),
                        ('isId', False), ('generated', False),
                        ('converted', False), ('enumerated', False)))
        column_body = names.get('Column')
        join_body = names.get('JoinColumn')
        joins_body = names.get('JoinColumns')
        entries = []
        if column_body is not None:
            entries.append(('Column', column_body))
        if join_body is not None:
            entries.append(('JoinColumn', join_body))
        if joins_body is not None:
            for inner in nested_annotations(joins_body, 'JoinColumn'):
                entries.append(('JoinColumn', inner))
        for kind, body in entries:
            column = (string_value(annotation_attribute(body, 'name')) or '').lower()
            if not column:
                continue
            mapping = OrderedDict((
                ('column', column), ('member', member), ('annotation', kind),
                ('length', int_value(annotation_attribute(body, 'length'))),
                ('precision', int_value(annotation_attribute(body, 'precision'))),
                ('scale', int_value(annotation_attribute(body, 'scale'))),
                ('nullable', bool_value(annotation_attribute(body, 'nullable'))),
                ('unique', bool_value(annotation_attribute(body, 'unique'))),
                ('insertable', bool_value(annotation_attribute(body, 'insertable'))),
                ('updatable', bool_value(annotation_attribute(body, 'updatable'))),
                ('columnDefinition',
                 string_value(annotation_attribute(body, 'columnDefinition'))),
                ('elementCollection', 'ElementCollection' in names),
                ('isId', 'Id' in names),
                ('generated', 'GeneratedValue' in names),
                ('converted', 'Convert' in names),
                ('enumerated', 'Enumerated' in names),
            ))
            if target_table:
                holder.secondary_tables[target_table][column] = mapping
            else:
                holder.own_columns[column] = mapping
            if 'Id' in names:
                holder.id_columns.append(column)


def _record_join_table(holder, names, member):
    """Record a @JoinTable relationship with its own columns and cardinality."""
    body = names['JoinTable']
    table = (string_value(annotation_attribute(body, 'name')) or '').lower() or None
    cardinality = None
    relation_body = None
    for candidate in ('OneToMany', 'ManyToMany', 'OneToOne', 'ManyToOne',
                      'ElementCollection'):
        if candidate in names:
            cardinality = candidate
            relation_body = names[candidate]
            break
    cascades = []
    orphan_removal = None
    mapped_by = None
    fetch = None
    if relation_body:
        raw = annotation_attribute(relation_body, 'cascade')
        if raw:
            cascades = sorted(set(re.findall(r'CascadeType\.([A-Z_]+)', raw))) \
                or sorted(set(re.findall(r'\b([A-Z_]{3,})\b', raw)))
        orphan_removal = bool_value(
            annotation_attribute(relation_body, 'orphanRemoval'))
        mapped_by = string_value(annotation_attribute(relation_body, 'mappedBy'))
        fetch_raw = annotation_attribute(relation_body, 'fetch')
        fetch = fetch_raw.rsplit('.', 1)[-1].strip() if fetch_raw else None
    record = OrderedDict((
        ('member', member), ('joinTable', table), ('cardinality', cardinality),
        ('cascade', cascades), ('orphanRemoval', orphan_removal),
        ('mappedBy', mapped_by), ('fetch', fetch),
        ('owningColumns', []), ('inverseColumns', [])))
    for attribute, bucket in (('joinColumns', 'owningColumns'),
                              ('inverseJoinColumns', 'inverseColumns')):
        raw = annotation_attribute(body, attribute)
        for inner in nested_annotations(raw, 'JoinColumn') if raw else []:
            column = (string_value(annotation_attribute(inner, 'name')) or '').lower()
            if not column:
                continue
            mapping = OrderedDict((
                ('column', column), ('member', member),
                ('annotation', 'JoinColumn/' + attribute),
                ('length', int_value(annotation_attribute(inner, 'length'))),
                ('precision', None), ('scale', None),
                ('nullable', bool_value(annotation_attribute(inner, 'nullable'))),
                ('unique', bool_value(annotation_attribute(inner, 'unique'))),
                ('insertable', bool_value(annotation_attribute(inner, 'insertable'))),
                ('updatable', bool_value(annotation_attribute(inner, 'updatable'))),
                ('columnDefinition', None), ('elementCollection', False),
                ('isId', False), ('generated', False), ('converted', False),
                ('enumerated', False),
            ))
            record[bucket].append(mapping)
            if table:
                holder.secondary_tables[table][column] = mapping
    holder.relationships.append(record)


# ---------------------------------------------------------------------------
# 6. resolving the ORM model against inheritance
# ---------------------------------------------------------------------------
class OrmModel(object):
    def __init__(self, root):
        self.classes = OrderedDict()
        for path in walk_files(root, JAVA_SEGMENT, '.java'):
            try:
                holder = parse_java(path, root)
            except (OSError, RecursionError):
                continue
            if holder is None:
                continue
            if not (holder.is_entity or holder.is_mapped_superclass
                    or holder.is_embeddable):
                continue
            # Two classes can share a simple name across modules; keep both, keyed
            # by path, and index by simple name for superclass resolution only.
            self.classes[holder.path] = holder
        self.by_name = {}
        for holder in self.classes.values():
            self.by_name.setdefault(holder.name, holder)

    def entities(self):
        return [c for c in self.classes.values() if c.is_entity]

    def ancestors(self, holder):
        chain = []
        seen = set()
        current = holder
        while current and current.superclass and current.superclass not in seen:
            seen.add(current.superclass)
            parent = self.by_name.get(current.superclass)
            if parent is None:
                break
            chain.append(parent)
            current = parent
        return chain

    def effective_table(self, holder):
        """The table a class's own columns land in.

        A SINGLE_TABLE subclass has no @Table of its own and shares its nearest
        annotated ancestor's table; that is why counting tables is not the same as
        counting classes.
        """
        if holder.table:
            return holder.table
        for parent in self.ancestors(holder):
            if parent.table:
                return parent.table
        return None

    def table_mappings(self):
        """table -> {column: [mapping, ...]} across every class that writes to it."""
        result = defaultdict(lambda: defaultdict(list))
        for holder in self.classes.values():
            if holder.is_entity:
                table = self.effective_table(holder)
                if table:
                    for column, mapping in holder.own_columns.items():
                        enriched = OrderedDict(mapping)
                        enriched['declaringClass'] = holder.path
                        result[table][column].append(enriched)
                    # a mapped superclass contributes its columns to every entity
                    # table beneath it
                    for parent in self.ancestors(holder):
                        if not parent.is_mapped_superclass:
                            continue
                        for column, mapping in parent.own_columns.items():
                            enriched = OrderedDict(mapping)
                            enriched['declaringClass'] = parent.path
                            result[table][column].append(enriched)
                    if holder.discriminator_column:
                        result[table][holder.discriminator_column].append(OrderedDict((
                            ('column', holder.discriminator_column),
                            ('member', '(discriminator)'), ('annotation',
                                                            'DiscriminatorColumn'),
                            ('length', None), ('precision', None), ('scale', None),
                            ('nullable', None), ('unique', None),
                            ('declaringClass', holder.path))))
            for table, columns in holder.secondary_tables.items():
                for column, mapping in columns.items():
                    enriched = OrderedDict(mapping)
                    enriched['declaringClass'] = holder.path
                    result[table][column].append(enriched)
        return result


# ---------------------------------------------------------------------------
# 7. comparison
# ---------------------------------------------------------------------------
def attribute_stated(mappings, key):
    return any(m.get(key) is not None for m in mappings)


def stated_value(mappings, key):
    for mapping in mappings:
        if mapping.get(key) is not None:
            return mapping[key]
    return None


def compare(schema, orm):
    tables = schema.live_tables()
    mapped = orm.table_mappings()
    per_class = OrderedDict()
    per_table = OrderedDict()
    cardinality_gaps = []
    length_conflicts = []
    nullability_conflicts = []
    totals = defaultdict(int)

    # per-CLASS accounting, so 91 classes stay 91 classes
    class_of_column = defaultdict(list)
    for holder in orm.classes.values():
        table = orm.effective_table(holder) if holder.is_entity else None
        if table:
            for column in holder.own_columns:
                class_of_column[(table, column)].append(holder)
        for secondary, columns in holder.secondary_tables.items():
            for column in columns:
                class_of_column[(secondary, column)].append(holder)

    for table_name in sorted(tables):
        table = tables[table_name]
        columns_mapped = mapped.get(table_name, {})
        row = OrderedDict((
            ('table', table_name),
            ('ddlColumns', len(table.columns)),
            ('mappedColumns', 0), ('unmappedDdlColumns', 0),
            ('mappedColumnsAbsentFromDdl', 0),
            ('omittedLength', 0), ('omittedNullability', 0),
            ('omittedUniqueness', 0), ('omittedPrecisionScale', 0),
        ))
        for column in sorted(table.columns):
            ddl = table.columns[column]
            mappings = columns_mapped.get(column)
            if not mappings:
                row['unmappedDdlColumns'] += 1
                totals['unmappedDdlColumns'] += 1
                continue
            row['mappedColumns'] += 1
            totals['columnsCompared'] += 1
            omissions = []
            if ddl['length'] is not None and not attribute_stated(mappings, 'length'):
                omissions.append('length')
                row['omittedLength'] += 1
                totals['omittedLength'] += 1
            elif ddl['length'] not in (None, -1) and attribute_stated(mappings, 'length') \
                    and stated_value(mappings, 'length') != ddl['length']:
                length_conflicts.append(OrderedDict((
                    ('table', table_name), ('column', column),
                    ('ddlLength', ddl['length']),
                    ('ormLength', stated_value(mappings, 'length')))))
            if ddl['notNull'] and not attribute_stated(mappings, 'nullable'):
                omissions.append('nullability')
                row['omittedNullability'] += 1
                totals['omittedNullability'] += 1
            elif ddl['notNull'] and stated_value(mappings, 'nullable') is True:
                nullability_conflicts.append(OrderedDict((
                    ('table', table_name), ('column', column),
                    ('ddl', 'NOT NULL'), ('orm', 'nullable = true'))))
            if schema.explicit_single_column_unique(table, column) \
                    and stated_value(mappings, 'unique') is not True:
                omissions.append('uniqueness')
                row['omittedUniqueness'] += 1
                totals['omittedUniqueness'] += 1
            if (ddl['precision'] is not None or ddl['scale'] is not None) \
                    and not attribute_stated(mappings, 'precision') \
                    and not attribute_stated(mappings, 'scale'):
                omissions.append('precisionScale')
                row['omittedPrecisionScale'] += 1
                totals['omittedPrecisionScale'] += 1

            # THE CARDINALITY CHECK.  A JPA column declared unique = true whose
            # effective schema does not constrain that column alone.
            if stated_value(mappings, 'unique') is True \
                    and not schema.single_column_unique(table, column):
                covering = schema.composite_uniqueness_covering(table, column)
                owners = sorted(set(m.get('declaringClass') for m in mappings
                                    if m.get('declaringClass')))
                cardinality_gaps.append(OrderedDict((
                    ('table', table_name), ('column', column),
                    ('ormDeclares', 'unique = true'),
                    ('declaredBy', owners),
                    ('viaAnnotation', sorted(set(m.get('annotation')
                                                 for m in mappings))),
                    ('ddlSingleColumnUniqueness', 'absent'),
                    ('ddlCompositeUniquenessMentioningColumn', covering),
                    ('effect', 'a composite key does not constrain this column '
                               'alone, so more than one row can carry the same '
                               'value the ORM declares unique'
                     if covering else
                     'the effective schema carries no uniqueness for this column '
                     'at all'),
                    ('ddlDeclaredBy', ddl['declaredBy']),
                )))
            for mapping in mappings:
                owner = mapping.get('declaringClass')
                if not owner:
                    continue
                bucket = per_class.setdefault(owner, OrderedDict((
                    ('class', owner), ('table', table_name),
                    ('module', owner.split('/src/')[0]),
                    ('length', 0), ('nullability', 0), ('unique', 0),
                    ('precisionScale', 0), ('total', 0))))
                for kind in omissions:
                    key = {'length': 'length', 'nullability': 'nullability',
                           'uniqueness': 'unique',
                           'precisionScale': 'precisionScale'}[kind]
                    bucket[key] += 1
                    bucket['total'] += 1
                break
        for column in sorted(columns_mapped):
            if column not in table.columns:
                row['mappedColumnsAbsentFromDdl'] += 1
                totals['mappedColumnsAbsentFromDdl'] += 1
        per_table[table_name] = row

    mapped_tables_absent = sorted(set(mapped) - set(tables))
    return OrderedDict((
        ('perTable', per_table), ('perClass', per_class),
        ('cardinalityGaps', cardinality_gaps),
        ('lengthConflicts', length_conflicts),
        ('nullabilityConflicts', nullability_conflicts),
        ('mappedTablesAbsentFromEffectiveSchema', mapped_tables_absent),
        ('totals', OrderedDict(sorted(totals.items()))),
    ))


# ---------------------------------------------------------------------------
# 8. reporting
# ---------------------------------------------------------------------------
def build(root, dbms, roots=None):
    index = ResourceIndex(root)
    params = Parameters(dbms)
    schema = SchemaModel(params)
    graphs = []
    for name, resource in ROOT_CHANGELOGS:
        if roots and name not in roots:
            continue
        graph = ChangeLogGraph(index, params, name, resource).build()
        graphs.append(graph)
        for resource_name, _path, node in graph.changesets:
            schema.apply_changeset(resource_name, node)
    orm = OrmModel(root)
    result = compare(schema, orm)
    return index, params, schema, graphs, orm, result


def emit_text(out, index, params, schema, graphs, orm, result):
    write = out.append
    totals = result['totals']
    entities = orm.entities()
    with_table = [c for c in entities if c.table]
    tables_claimed = sorted(set(t for t in (orm.effective_table(c) for c in entities)
                                if t))
    live = schema.live_tables()

    write('effective-schema versus structural-mapping measurement')
    write('')
    write('target-dbms: %s' % params.dbms)
    write('roots-modelled: %s' % ', '.join(g.root_name for g in graphs))
    write('changelog-resources-discovered: %d' % len(index.changelog_names()))
    write('root-changelogs-walked: %d' % len(graphs))
    for graph in graphs:
        write('  %-18s %-72s resources %3d  changeSets %4d'
              % (graph.root_name, graph.root_resource,
                 len(graph.visited), len(graph.changesets)))
    write('changeSets-in-graph-order: %d' % schema.changesets_seen)
    write('  applied to the model                     : %d' % schema.applied)
    write('  skipped, changeSet dbms excludes %-8s: %d'
          % (params.dbms, schema.skipped_dbms))
    write('  skipped, already executed from another root: %d'
          % schema.skipped_already_executed)
    write('  skipped, precondition evaluated false     : %d'
          % schema.skipped_precondition)
    write('  carrying failOnError="false"              : %d'
          % len(schema.fail_on_error_false))
    write('  declaring a context (would change what runs): %d'
          % schema.contexts_declared)
    write('')
    write('EFFECTIVE SCHEMA (after creates, adds, modifies, renames and drops)')
    write('  tables live at the end of the graph       : %d' % len(live))
    write('  tables dropped by the graph               : %d'
          % (len(schema.tables) - len(live)))
    write('  columns across live tables                : %d'
          % sum(len(t.columns) for t in live.values()))
    write('  single-column unique constraints           : %d'
          % sum(1 for t in live.values() for n, c in t.uniques if len(c) == 1))
    write('  COMPOSITE unique constraints, kept composite: %d'
          % sum(1 for t in live.values() for n, c in t.uniques if len(c) > 1))
    write('  composite primary keys                     : %d'
          % sum(1 for t in live.values()
                if t.primary_key and len(t.primary_key[1]) > 1))
    write('  unique indexes                             : %d'
          % sum(1 for t in live.values() for i in t.indexes if i[2]))
    write('  foreign keys                                : %d'
          % sum(len(t.foreign_keys) for t in live.values()))
    write('  tables re-created by a later changeSet       : %d'
          % len(schema.repeated_definitions))
    write('  columns re-declared with a different type    : %d'
          % len(schema.conflicting_types))
    write('  operations naming a table the model does not hold: %d'
          % len(schema.operations_on_absent_table))
    write('')
    write('STRUCTURAL MAPPING (parsed per class, not per table)')
    write('  classes carrying @Entity                   : %d' % len(entities))
    write('  of those, carrying @Table(name = ...)      : %d' % len(with_table))
    write('  distinct tables those entities resolve to  : %d' % len(tables_claimed))
    write('  @MappedSuperclass classes                  : %d'
          % sum(1 for c in orm.classes.values() if c.is_mapped_superclass))
    write('  @Embeddable classes                        : %d'
          % sum(1 for c in orm.classes.values() if c.is_embeddable))
    write('  join / collection tables owning their own columns: %d'
          % len(set(t for c in orm.classes.values() for t in c.secondary_tables)))
    relationships = [r for c in orm.classes.values() for r in c.relationships]
    write('  @JoinTable relationships recorded          : %d' % len(relationships))
    write('    with a cascade declared                  : %d'
          % sum(1 for r in relationships if r['cascade']))
    write('    with orphanRemoval = true                : %d'
          % sum(1 for r in relationships if r['orphanRemoval'] is True))
    write('    whose inverse join column is declared unique: %d'
          % sum(1 for r in relationships
                if any(c['unique'] is True for c in r['inverseColumns'])))
    write('  @AttributeOverride column re-points captured: %d'
          % sum(1 for c in orm.classes.values() for m in c.own_columns.values()
                if m.get('annotation') == 'AttributeOverride/Column'))
    write('')
    write('DIVERGENCE, over columns present in BOTH the effective schema and a mapping')
    write('  columns compared                           : %d'
          % totals.get('columnsCompared', 0))
    write('  omitted length declarations                : %d'
          % totals.get('omittedLength', 0))
    write('  omitted nullability declarations           : %d'
          % totals.get('omittedNullability', 0))
    write('  omitted uniqueness declarations            : %d'
          % totals.get('omittedUniqueness', 0))
    write('  omitted precision/scale declarations       : %d'
          % totals.get('omittedPrecisionScale', 0))
    write('  TOTAL omitted dimensions                   : %d'
          % (totals.get('omittedLength', 0) + totals.get('omittedNullability', 0)
             + totals.get('omittedUniqueness', 0)
             + totals.get('omittedPrecisionScale', 0)))
    write('  classes carrying at least one omission     : %d' % len(result['perClass']))
    write('')
    write('  length stated on both sides but DIFFERENT  : %d'
          % len(result['lengthConflicts']))
    write('  DDL NOT NULL against ORM nullable = true   : %d'
          % len(result['nullabilityConflicts']))
    write('  effective-schema columns no mapping names  : %d'
          % totals.get('unmappedDdlColumns', 0))
    write('  mapped columns absent from the schema      : %d'
          % totals.get('mappedColumnsAbsentFromDdl', 0))
    write('  mapped tables absent from the schema       : %d'
          % len(result['mappedTablesAbsentFromEffectiveSchema']))
    for name in result['mappedTablesAbsentFromEffectiveSchema']:
        write('    %s' % name)
    write('')
    write('CARDINALITY GAPS -- ORM declares unique = true, the effective schema does not')
    write('  gaps found: %d' % len(result['cardinalityGaps']))
    write('  These are reported separately from the omission count above because they')
    write('  are the OPPOSITE defect: the omissions are constraints the DDL states and')
    write('  the ORM does not, whereas these are constraints the ORM states and the')
    write('  DDL does not enforce.  A composite key over (parent, child) is NOT')
    write('  single-column uniqueness, and reporting it as such is what hid these.')
    for gap in result['cardinalityGaps']:
        write('')
        write('  %s.%s' % (gap['table'], gap['column']))
        write('    ORM        : unique = true via %s' % ', '.join(gap['viaAnnotation']))
        for owner in gap['declaredBy']:
            write('    declared in: %s' % owner)
        write('    DDL        : no single-column uniqueness; declared by %s'
              % gap['ddlDeclaredBy'])
        for covering in gap['ddlCompositeUniquenessMentioningColumn']:
            write('    composite  : %s %s over (%s)'
                  % (covering['kind'], covering['name'] or '(unnamed)',
                     ', '.join(covering['columns'])))
        write('    effect     : %s' % gap['effect'])
    write('')
    write('TOP 15 CLASSES BY OMISSION COUNT')
    ordered = sorted(result['perClass'].values(), key=lambda r: (-r['total'], r['class']))
    for row in ordered[:15]:
        write('  %-34s %4d  (len %3d, null %3d, uniq %2d, prec %2d)  %s'
              % (row['table'], row['total'], row['length'], row['nullability'],
                 row['unique'], row['precisionScale'],
                 os.path.basename(row['class'])))
    write('')
    write('WHAT THIS MODEL DOES NOT MODEL')
    for tag in sorted(schema.opaque_ops):
        write('  opaque, text not interpreted   %-22s %d'
              % (tag, schema.opaque_ops[tag]))
    for tag in sorted(schema.data_ops):
        write('  data rather than schema        %-22s %d' % (tag, schema.data_ops[tag]))
    for tag in sorted(schema.unknown_ops):
        write('  not handled by this model      %-22s %d'
              % (tag, schema.unknown_ops[tag]))
    write('  preconditions that cannot be evaluated statically: %d'
          % len(schema.unevaluable_preconditions))
    write('  changelog placeholders left unresolved           : %d'
          % len(params.unresolved))
    for key in sorted(params.unresolved):
        write('    ${%s} x%d' % (key, params.unresolved[key]))
    # Liquibase keeps the first value set for a parameter, so a later definition is
    # discarded.  Most of this repository's re-definitions repeat the same value and
    # are harmless; the ones that do NOT are a latent defect, because the changelog
    # that re-declares the value does not get the value it declares.  The two cases
    # are separated so the material one cannot be lost in the harmless ones.
    material = [e for e in params.shadowed if e['keptValue'] != e['ignoredValue']]
    harmless = len(params.shadowed) - len(material)
    write('  properties shadowed by an earlier definition     : %d'
          % len(params.shadowed))
    write('    of those, re-declaring the SAME value (harmless): %d' % harmless)
    write('    of those, re-declaring a DIFFERENT value        : %d' % len(material))
    for entry in material:
        write('      %s kept %r, DISCARDED %r declared in %s'
              % (entry['property'], entry['keptValue'], entry['ignoredValue'],
                 entry['source']))
    write('  includeAll ordering across classpath providers is not determined by the')
    write('    sources; this model sorts by resource name and reports resources')
    write('    provided by more than one module: %d'
          % len(set(m['resource'] for g in graphs for m in g.multi_provider)))
    write('  include targets that resolved to no resource     : %d'
          % sum(len(g.missing_includes) for g in graphs))
    write('  this measurement is for ONE dbms (%s) and makes no claim about another'
          % params.dbms)
    return out


def main(argv):
    root = os.path.abspath('.')
    json_out = None
    dbms = 'mysql'
    roots = None
    positional = []
    index = 1
    while index < len(argv):
        if argv[index] == '--dbms' and index + 1 < len(argv):
            dbms = argv[index + 1].lower()
            index += 2
            continue
        if argv[index] == '--roots' and index + 1 < len(argv):
            roots = [r.strip() for r in argv[index + 1].split(',') if r.strip()]
            index += 2
            continue
        positional.append(argv[index])
        index += 1
    if positional:
        root = os.path.abspath(positional[0])
    if len(positional) > 1:
        json_out = positional[1]

    built = build(root, dbms, roots)
    lines = emit_text([], *built)
    sys.stdout.write('\n'.join(lines) + '\n')

    if json_out:
        _index, params, schema, graphs, orm, result = built
        live = schema.live_tables()
        payload = OrderedDict((
            ('targetDbms', params.dbms),
            ('rootsModelled', [g.root_name for g in graphs]),
            ('graph', [OrderedDict((
                ('root', g.root_name), ('resource', g.root_resource),
                ('resourcesVisited', len(g.visited)),
                ('changeSets', len(g.changesets)),
                ('missingIncludes', sorted(g.missing_includes)),
                ('resourcesProvidedByMoreThanOneModule',
                 sorted(set(m['resource'] for m in g.multi_provider))))) for g in graphs]),
            ('changeSetAccounting', OrderedDict((
                ('seen', schema.changesets_seen), ('applied', schema.applied),
                ('skippedByDbms', schema.skipped_dbms),
                ('skippedByPrecondition', schema.skipped_precondition),
                ('skippedAsAlreadyExecuted', schema.skipped_already_executed),
                ('failOnErrorFalse', sorted(schema.fail_on_error_false)),
                ('contextsDeclared', schema.contexts_declared),
                ('structuralOperations', OrderedDict(sorted(
                    schema.structural_ops.items()))),
                ('opaqueOperations', OrderedDict(sorted(schema.opaque_ops.items()))),
                ('dataOperations', OrderedDict(sorted(schema.data_ops.items()))),
                ('unhandledOperations', OrderedDict(sorted(
                    schema.unknown_ops.items())))))),
            ('effectiveSchema', OrderedDict((
                ('liveTables', len(live)),
                ('droppedTables', len(schema.tables) - len(live)),
                ('columns', sum(len(t.columns) for t in live.values())),
                ('singleColumnUniqueConstraints',
                 sum(1 for t in live.values() for n, c in t.uniques if len(c) == 1)),
                ('compositeUniqueConstraints',
                 sum(1 for t in live.values() for n, c in t.uniques if len(c) > 1)),
                ('compositePrimaryKeys',
                 sum(1 for t in live.values()
                     if t.primary_key and len(t.primary_key[1]) > 1)),
                ('uniqueIndexes',
                 sum(1 for t in live.values() for i in t.indexes if i[2])),
                ('foreignKeys', sum(len(t.foreign_keys) for t in live.values())),
                ('tablesRecreatedLater', OrderedDict(sorted(
                    (k, v) for k, v in schema.repeated_definitions.items()))),
                ('columnsRedeclaredWithADifferentType', schema.conflicting_types),
                ('operationsOnAbsentTables', schema.operations_on_absent_table)))),
            ('structuralMapping', OrderedDict((
                ('entityClasses', len(orm.entities())),
                ('entityClassesWithTableAnnotation',
                 len([c for c in orm.entities() if c.table])),
                ('distinctTablesClaimed',
                 len(set(t for t in (orm.effective_table(c) for c in orm.entities())
                         if t))),
                ('mappedSuperclasses',
                 sum(1 for c in orm.classes.values() if c.is_mapped_superclass)),
                ('embeddables',
                 sum(1 for c in orm.classes.values() if c.is_embeddable)),
                ('joinOrCollectionTables',
                 len(set(t for c in orm.classes.values() for t in c.secondary_tables))),
                ('joinTableRelationships',
                 sum(len(c.relationships) for c in orm.classes.values())),
                ('joinTableRelationshipDetail',
                 [r for c in sorted(orm.classes.values(), key=lambda x: x.path)
                  for r in c.relationships])))),
            ('divergence', result),
            ('notModelled', OrderedDict((
                ('unevaluablePreconditions', schema.unevaluable_preconditions),
                ('unresolvedPlaceholders', OrderedDict(sorted(
                    params.unresolved.items()))),
                ('shadowedProperties', params.shadowed)))),
        ))
        with open(json_out, 'w', encoding='utf-8') as handle:
            json.dump(payload, handle, indent=2, sort_keys=False)
            handle.write('\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
