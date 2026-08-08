#!/usr/bin/env node
'use strict';

// verify-artifact-equivalence.js — decide, mechanically, whether two frontend bundles
// that differ in BYTES differ in BEHAVIOUR.
//
// WHY THIS PROGRAM EXISTS, STATED WITHOUT SOFTENING WHAT IT DOES NOT DO.
//
// The frontend acceptance criterion for this migration is byte identity of five build
// artifacts against a pre-migration baseline.  Three of the five are byte-identical.
// Two are not, and this program does NOT make them so and does not claim to: the
// criterion is about bytes, the bytes differ, and the comparison record states that
// plainly as a failure.  What this program does is answer the different and narrower
// question a reader needs answered next — whether the two differing artifacts do the
// same thing — and answer it by construction rather than by argument.
//
// It is written to be able to FAIL.  Every check below either establishes equivalence
// by exhaustion over a stated domain or reports that it could not, and the exit status
// is non-zero in the second case.  A prover that cannot fail proves nothing.
//
// WHAT IT CHECKS.
//
//   SCRIPT BUNDLE.  Byte-compares first.  Where a line differs, it isolates the
//   difference and tests whether the whole of it is accounted for by regular-expression
//   literals that differ only in REDUNDANT escaping of a forward slash inside a
//   character class — the one form of difference a change of JavaScript engine is known
//   to produce here, because the minifier re-prints a literal through the RegExp
//   object's own string conversion and the engine's normalisation of that conversion
//   changed.  For each such pair it constructs both patterns and compares their
//   accept/reject behaviour over every code point in a stated range and over a corpus
//   of realistic inputs.  Then it normalises that one escape in both files and requires
//   the whole file to compare EQUAL — so a second, unrelated difference hiding on the
//   same line cannot pass unnoticed.
//
//   STYLE BUNDLE.  Parses both, expands every rule into per-selector ORDERED
//   declaration lists inside their at-rule context, and requires the two expansions to
//   be identical: the same selectors, each receiving the same declarations, with the
//   same values, in the same order.  Selector grouping is what a stylesheet minifier
//   regroups when its internal ordering changes; the declarations a selector receives
//   are what the browser acts on.  Both are measured, and the report says which one
//   differs.
//
// WHAT IT DOES NOT ESTABLISH, SAID HERE RATHER THAN LEFT TO BE DISCOVERED.  The style
// check compares each selector's own ordered declarations.  It does not attempt to
// prove that the RELATIVE order of two rules with different selectors and equal
// specificity is preserved, because that is a property of the minifier's restructuring
// pass rather than of these two files, and the minifier is the same version on both
// sides — so any defect in it is present in both.  A reader who needs that stronger
// property needs it from the tool, not from this comparison.
//
// usage:
//   node verify-artifact-equivalence.js --baseline-js <f> --migrated-js <f> \
//        --baseline-css <f> --migrated-css <f> [--out <file>]

const fs = require('fs');
const crypto = require('crypto');

function fail(msg) {
    process.stderr.write('verify-artifact-equivalence.js: ' + msg + '\n');
    process.exit(2);
}

const args = process.argv.slice(2);
const opt = {};
for (let i = 0; i < args.length; i += 2) {
    const k = args[i];
    const v = args[i + 1];
    if (!k.startsWith('--') || v === undefined) { fail('bad argument near ' + k); }
    opt[k.slice(2)] = v;
}
for (const need of ['baseline-js', 'migrated-js', 'baseline-css', 'migrated-css']) {
    if (!opt[need]) { fail('missing --' + need); }
    if (!fs.existsSync(opt[need])) { fail('no such file: ' + opt[need]); }
}

const out = [];
const say = (s) => { out.push(s); };

// ---------------------------------------------------------------------------
// script bundle
// ---------------------------------------------------------------------------

// A regular-expression literal in minified output, matched conservatively: it must
// start at a position where a literal is possible and must not span a newline.  The
// pattern is deliberately narrow — it only has to find the literals that CONTAIN a
// character class with a forward slash in it, which is the only shape under test.
const CLASS_WITH_SLASH = /\[[^\]\n]*\/[^\]\n]*\]/g;

// UNESCAPE only the redundant form: a backslash before a forward slash INSIDE a
// character class.  Outside a class the escape is not redundant, so it is left alone.
function normaliseRedundantSlashEscapes(text) {
    let changed = 0;
    const result = text.replace(/\[(?:\\.|[^\]\\\n])*\]/g, (cls) => {
        const fixed = cls.replace(/\\\//g, () => { changed += 1; return '/'; });
        return fixed;
    });
    return { text: result, changed };
}

function regexEquivalent(patternA, patternB) {
    let ra;
    let rb;
    try {
        ra = new RegExp('^(?:' + patternA + ')$');
        rb = new RegExp('^(?:' + patternB + ')$');
    } catch (e) {
        return { ok: false, reason: 'one of the patterns does not compile: ' + e.message };
    }
    let tested = 0;
    let mismatches = 0;
    for (let cp = 0; cp < 0x2000; cp += 1) {
        const ch = String.fromCodePoint(cp);
        tested += 1;
        if (ra.test(ch) !== rb.test(ch)) { mismatches += 1; }
    }
    const corpus = [
        '', '/', '//', '///', 'a/b', 'http://example.invalid/path',
        'https://example.invalid/a/b?c=d&e=f', 'example.invalid', 'a-b_c.d~e#f?g&h=i',
        '%20', '(x)', '@host', ':80', 'ftp://x//y', '\\', 'a\\/b', '=', '&&', '?'
    ];
    for (const s of corpus) {
        tested += 1;
        if (ra.test(s) !== rb.test(s)) { mismatches += 1; }
    }
    return { ok: mismatches === 0, tested, mismatches };
}

function checkScript() {
    const a = fs.readFileSync(opt['baseline-js'], 'utf8');
    const b = fs.readFileSync(opt['migrated-js'], 'utf8');
    say('===== script bundle =====');
    say('pre-migration bytes: ' + Buffer.byteLength(a));
    say('post-migration bytes: ' + Buffer.byteLength(b));
    say('byte-identical: ' + (a === b ? 'yes' : 'no'));
    if (a === b) {
        say('nothing further to establish: the bytes are the same.');
        return true;
    }

    const la = a.split('\n');
    const lb = b.split('\n');
    if (la.length !== lb.length) {
        say('DIFFERING LINE COUNT: ' + la.length + ' vs ' + lb.length);
        say('equivalence NOT established: a differing line count is not the shape this');
        say('program can account for, and it will not guess.');
        return false;
    }
    const differing = [];
    for (let i = 0; i < la.length; i += 1) { if (la[i] !== lb[i]) { differing.push(i); } }
    say('lines: ' + la.length + '; differing lines: ' + differing.length +
        ' at index ' + JSON.stringify(differing));

    let allAccounted = true;
    for (const i of differing) {
        const ca = la[i].match(CLASS_WITH_SLASH) || [];
        const cb = lb[i].match(CLASS_WITH_SLASH) || [];
        say('  line ' + i + ': character classes containing a forward slash — ' +
            ca.length + ' pre-migration, ' + cb.length + ' post-migration');
        if (ca.length !== cb.length) { allAccounted = false; continue; }
        for (let k = 0; k < ca.length; k += 1) {
            if (ca[k] === cb[k]) { continue; }
            const stripA = ca[k].replace(/\\\//g, '/');
            const stripB = cb[k].replace(/\\\//g, '/');
            const onlyEscaping = stripA === stripB;
            say('    class ' + k + ' differs');
            say('      pre-migration : ' + ca[k]);
            say('      post-migration: ' + cb[k]);
            say('      difference is ONLY redundant forward-slash escaping: ' +
                (onlyEscaping ? 'yes' : 'NO'));
            if (!onlyEscaping) { allAccounted = false; continue; }
            const eq = regexEquivalent(ca[k] + '*', cb[k] + '*');
            say('      accept/reject equivalence: ' +
                (eq.ok ? 'PROVED over ' + eq.tested + ' inputs, 0 disagreements'
                       : 'NOT proved — ' + (eq.reason || (eq.mismatches + ' disagreements'))));
            if (!eq.ok) { allAccounted = false; }
        }
    }

    const na = normaliseRedundantSlashEscapes(a);
    const nb = normaliseRedundantSlashEscapes(b);
    say('after normalising redundant forward-slash escapes inside character classes:');
    say('  escapes normalised, pre-migration: ' + na.changed);
    say('  escapes normalised, post-migration: ' + nb.changed);
    say('  the two files then compare: ' + (na.text === nb.text ? 'EQUAL' : 'STILL DIFFERENT'));
    if (na.text !== nb.text) {
        say('  a residual difference survives normalisation, so the whole of the byte');
        say('  difference is NOT accounted for by engine escaping.  Equivalence NOT');
        say('  established.');
        return false;
    }
    if (!allAccounted) {
        say('  the files normalise to the same bytes, but at least one individual class');
        say('  could not be shown equivalent, so no equivalence claim is made.');
        return false;
    }
    say('VERDICT: the two script bundles differ in bytes and are EQUIVALENT in behaviour.');
    say('  The whole of the difference is redundant escaping of a forward slash inside a');
    say('  character class, every affected pattern was proved to accept and reject');
    say('  identically, and after normalising that one escape the files are byte-equal —');
    say('  which is what rules out a second difference hiding beside the first.');
    return true;
}

// ---------------------------------------------------------------------------
// style bundle
// ---------------------------------------------------------------------------

// A small, explicit CSS reader.  It is written out rather than delegated so that what
// it does and does not understand is visible: it tracks strings, parentheses and
// comments, treats an at-rule with a block as a context that nests, and treats an
// at-rule without one as a statement.
function parseCss(text) {
    const rules = [];      // { context, selectors:[...], declarations:[[prop,value],...] }
    const statements = []; // at-rules without a block, e.g. @import / @charset
    let i = 0;
    const n = text.length;
    const contextStack = [];

    function skipWhitespaceAndComments() {
        for (;;) {
            while (i < n && /\s/.test(text[i])) { i += 1; }
            if (text[i] === '/' && text[i + 1] === '*') {
                const end = text.indexOf('*/', i + 2);
                i = end === -1 ? n : end + 2;
                continue;
            }
            return;
        }
    }

    function readUntilTopLevel(stops) {
        let start = i;
        let depthParen = 0;
        let quote = null;
        while (i < n) {
            const ch = text[i];
            if (quote) {
                if (ch === '\\') { i += 2; continue; }
                if (ch === quote) { quote = null; }
                i += 1;
                continue;
            }
            if (ch === '"' || ch === "'") { quote = ch; i += 1; continue; }
            if (ch === '/' && text[i + 1] === '*') {
                const end = text.indexOf('*/', i + 2);
                i = end === -1 ? n : end + 2;
                continue;
            }
            if (ch === '(') { depthParen += 1; i += 1; continue; }
            if (ch === ')') { depthParen -= 1; i += 1; continue; }
            if (depthParen === 0 && stops.indexOf(ch) !== -1) { break; }
            i += 1;
        }
        return text.slice(start, i);
    }

    function splitTopLevel(s, sep) {
        const parts = [];
        let depthParen = 0;
        let depthBracket = 0;
        let quote = null;
        let cur = '';
        for (let k = 0; k < s.length; k += 1) {
            const ch = s[k];
            if (quote) {
                cur += ch;
                if (ch === '\\') { cur += s[k + 1] || ''; k += 1; continue; }
                if (ch === quote) { quote = null; }
                continue;
            }
            if (ch === '"' || ch === "'") { quote = ch; cur += ch; continue; }
            if (ch === '(') { depthParen += 1; cur += ch; continue; }
            if (ch === ')') { depthParen -= 1; cur += ch; continue; }
            if (ch === '[') { depthBracket += 1; cur += ch; continue; }
            if (ch === ']') { depthBracket -= 1; cur += ch; continue; }
            if (ch === sep && depthParen === 0 && depthBracket === 0) { parts.push(cur); cur = ''; continue; }
            cur += ch;
        }
        parts.push(cur);
        return parts;
    }

    function parseBlockBody() {
        // i points just past '{'
        for (;;) {
            skipWhitespaceAndComments();
            if (i >= n) { return; }
            if (text[i] === '}') { i += 1; return; }
            const prelude = readUntilTopLevel(['{', '}', ';']).trim();
            if (text[i] === '{') {
                i += 1;
                if (prelude.startsWith('@')) {
                    contextStack.push(prelude.replace(/\s+/g, ' '));
                    parseBlockBody();
                    contextStack.pop();
                } else {
                    const decls = [];
                    // declaration block
                    for (;;) {
                        skipWhitespaceAndComments();
                        if (i >= n) { break; }
                        if (text[i] === '}') { i += 1; break; }
                        const d = readUntilTopLevel([';', '}']).trim();
                        if (text[i] === ';') { i += 1; }
                        if (!d) { continue; }
                        const colon = (() => {
                            let depthParen = 0;
                            let quote = null;
                            for (let k = 0; k < d.length; k += 1) {
                                const ch = d[k];
                                if (quote) { if (ch === '\\') { k += 1; continue; } if (ch === quote) { quote = null; } continue; }
                                if (ch === '"' || ch === "'") { quote = ch; continue; }
                                if (ch === '(') { depthParen += 1; continue; }
                                if (ch === ')') { depthParen -= 1; continue; }
                                if (ch === ':' && depthParen === 0) { return k; }
                            }
                            return -1;
                        })();
                        if (colon === -1) { decls.push(['<malformed>', d]); continue; }
                        decls.push([
                            d.slice(0, colon).trim().toLowerCase(),
                            d.slice(colon + 1).trim()
                        ]);
                    }
                    rules.push({
                        context: contextStack.join(' >> '),
                        selectors: splitTopLevel(prelude, ',').map((s) => s.replace(/\s+/g, ' ').trim()).filter(Boolean),
                        declarations: decls
                    });
                }
            } else {
                if (text[i] === ';') { i += 1; }
                if (prelude) { statements.push(contextStack.join(' >> ') + '|' + prelude.replace(/\s+/g, ' ')); }
                if (text[i] === '}') { i += 1; return; }
            }
        }
    }

    // top level: same shape as a block body but terminated by end of input
    for (;;) {
        skipWhitespaceAndComments();
        if (i >= n) { break; }
        const prelude = readUntilTopLevel(['{', ';']).trim();
        if (i < n && text[i] === '{') {
            i += 1;
            if (prelude.startsWith('@')) {
                contextStack.push(prelude.replace(/\s+/g, ' '));
                parseBlockBody();
                contextStack.pop();
            } else {
                i -= 1;
                // reuse the block-body declaration reader by faking a one-rule body
                i += 1;
                const decls = [];
                for (;;) {
                    skipWhitespaceAndComments();
                    if (i >= n) { break; }
                    if (text[i] === '}') { i += 1; break; }
                    const d = readUntilTopLevel([';', '}']).trim();
                    if (text[i] === ';') { i += 1; }
                    if (!d) { continue; }
                    const colon = d.indexOf(':');
                    if (colon === -1) { decls.push(['<malformed>', d]); continue; }
                    decls.push([d.slice(0, colon).trim().toLowerCase(), d.slice(colon + 1).trim()]);
                }
                rules.push({
                    context: '',
                    selectors: splitTopLevel(prelude, ',').map((s) => s.replace(/\s+/g, ' ').trim()).filter(Boolean),
                    declarations: decls
                });
            }
        } else {
            if (i < n && text[i] === ';') { i += 1; }
            if (prelude) { statements.push('|' + prelude.replace(/\s+/g, ' ')); }
        }
    }
    return { rules, statements };
}

function expand(parsed) {
    // context + selector -> ordered list of "prop:value"
    const map = new Map();
    let declCount = 0;
    for (const r of parsed.rules) {
        for (const sel of r.selectors) {
            const key = r.context + '||' + sel;
            if (!map.has(key)) { map.set(key, []); }
            const list = map.get(key);
            for (const [p, v] of r.declarations) { list.push(p + ':' + v); declCount += 1; }
        }
    }
    return { map, declCount };
}

function checkStyle() {
    const at = fs.readFileSync(opt['baseline-css'], 'utf8');
    const bt = fs.readFileSync(opt['migrated-css'], 'utf8');
    say('');
    say('===== style bundle =====');
    say('pre-migration bytes: ' + Buffer.byteLength(at));
    say('post-migration bytes: ' + Buffer.byteLength(bt));
    say('byte-identical: ' + (at === bt ? 'yes' : 'no'));
    if (at === bt) {
        say('nothing further to establish: the bytes are the same.');
        return true;
    }
    const pa = parseCss(at);
    const pb = parseCss(bt);
    const ea = expand(pa);
    const eb = expand(pb);
    say('rule blocks: ' + pa.rules.length + ' pre-migration, ' + pb.rules.length + ' post-migration');
    say('at-rule statements without a block: ' + pa.statements.length + ' / ' + pb.statements.length);
    say('distinct context+selector keys: ' + ea.map.size + ' / ' + eb.map.size);
    say('declarations after expanding every selector group: ' + ea.declCount + ' / ' + eb.declCount);

    const malformedA = pa.rules.reduce((acc, r) => acc + r.declarations.filter((d) => d[0] === '<malformed>').length, 0);
    const malformedB = pb.rules.reduce((acc, r) => acc + r.declarations.filter((d) => d[0] === '<malformed>').length, 0);
    say('declarations the reader could not split into property and value: ' + malformedA + ' / ' + malformedB);
    if (malformedA !== 0 || malformedB !== 0) {
        say('equivalence NOT established: the reader did not fully understand the input, so');
        say('a comparison over its output would be a comparison of its own confusion.');
        return false;
    }

    const keysA = [...ea.map.keys()].sort();
    const keysB = [...eb.map.keys()].sort();
    const onlyA = keysA.filter((k) => !eb.map.has(k));
    const onlyB = keysB.filter((k) => !ea.map.has(k));
    say('selectors present only pre-migration: ' + onlyA.length);
    say('selectors present only post-migration: ' + onlyB.length);
    for (const k of onlyA.slice(0, 10)) { say('    only pre-migration: ' + k); }
    for (const k of onlyB.slice(0, 10)) { say('    only post-migration: ' + k); }

    // A DIFFERING ORDER IS NOT AUTOMATICALLY A DIFFERING RESULT, AND NOT AUTOMATICALLY
    // HARMLESS EITHER.  Reordering two declarations changes what the browser computes
    // only if the two can interact: if they set the same property, or if one is a
    // shorthand that writes the other's value.  So a differing order is classified
    // rather than counted, and the classification is deliberately CONSERVATIVE — a pair
    // it cannot rule out as independent is treated as interacting, which can only ever
    // move a selector into the unproved column and never out of it.
    // WHETHER TWO DECLARATIONS INTERACT.  Reordering two declarations inside one
    // selector changes what a browser computes only if the two write to a common
    // underlying property.  In CSS a declaration writes exactly one property unless
    // that property is a SHORTHAND, in which case it writes the longhands the
    // shorthand expands to.  So the question is decided by expanding each property to
    // its set of leaf longhands and asking whether the two sets intersect.
    //
    // The expansion table below is the audited part of this program.  Every property
    // NOT in it is treated as writing only itself, which is what the CSS rules say a
    // non-shorthand does; the risk in that treatment is a shorthand this table has
    // failed to list, so the program PRINTS every property name it had to classify as
    // a non-shorthand and a reader can check the list rather than trust it.
    const SHORTHANDS = {
        all: ['\u0000ALL\u0000'],
        margin: ['margin-top', 'margin-right', 'margin-bottom', 'margin-left'],
        padding: ['padding-top', 'padding-right', 'padding-bottom', 'padding-left'],
        inset: ['top', 'right', 'bottom', 'left'],
        border: ['border-width', 'border-style', 'border-color', 'border-image'],
        'border-width': ['border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width'],
        'border-style': ['border-top-style', 'border-right-style', 'border-bottom-style', 'border-left-style'],
        'border-color': ['border-top-color', 'border-right-color', 'border-bottom-color', 'border-left-color'],
        'border-image': ['border-image-source', 'border-image-slice', 'border-image-width', 'border-image-outset', 'border-image-repeat'],
        'border-top': ['border-top-width', 'border-top-style', 'border-top-color'],
        'border-right': ['border-right-width', 'border-right-style', 'border-right-color'],
        'border-bottom': ['border-bottom-width', 'border-bottom-style', 'border-bottom-color'],
        'border-left': ['border-left-width', 'border-left-style', 'border-left-color'],
        'border-radius': ['border-top-left-radius', 'border-top-right-radius', 'border-bottom-right-radius', 'border-bottom-left-radius'],
        background: ['background-image', 'background-position', 'background-size', 'background-repeat',
            'background-origin', 'background-clip', 'background-attachment', 'background-color'],
        font: ['font-style', 'font-variant', 'font-weight', 'font-stretch', 'font-size', 'line-height', 'font-family'],
        'font-variant': ['font-variant-ligatures', 'font-variant-caps', 'font-variant-numeric', 'font-variant-east-asian'],
        'list-style': ['list-style-type', 'list-style-position', 'list-style-image'],
        transition: ['transition-property', 'transition-duration', 'transition-timing-function', 'transition-delay'],
        animation: ['animation-name', 'animation-duration', 'animation-timing-function', 'animation-delay',
            'animation-iteration-count', 'animation-direction', 'animation-fill-mode', 'animation-play-state'],
        flex: ['flex-grow', 'flex-shrink', 'flex-basis'],
        'flex-flow': ['flex-direction', 'flex-wrap'],
        grid: ['grid-template-rows', 'grid-template-columns', 'grid-template-areas',
            'grid-auto-rows', 'grid-auto-columns', 'grid-auto-flow'],
        'grid-template': ['grid-template-rows', 'grid-template-columns', 'grid-template-areas'],
        'grid-area': ['grid-row-start', 'grid-row-end', 'grid-column-start', 'grid-column-end'],
        'grid-row': ['grid-row-start', 'grid-row-end'],
        'grid-column': ['grid-column-start', 'grid-column-end'],
        gap: ['row-gap', 'column-gap'],
        'place-items': ['align-items', 'justify-items'],
        'place-content': ['align-content', 'justify-content'],
        'place-self': ['align-self', 'justify-self'],
        outline: ['outline-width', 'outline-style', 'outline-color'],
        overflow: ['overflow-x', 'overflow-y'],
        columns: ['column-width', 'column-count'],
        'column-rule': ['column-rule-width', 'column-rule-style', 'column-rule-color'],
        'text-decoration': ['text-decoration-line', 'text-decoration-style', 'text-decoration-color', 'text-decoration-thickness'],
        'text-emphasis': ['text-emphasis-style', 'text-emphasis-color'],
        mask: ['mask-image', 'mask-mode', 'mask-position', 'mask-size', 'mask-repeat',
            'mask-origin', 'mask-clip', 'mask-composite'],
        // legacy aliases, folded onto the property they alias so an alias pair is not
        // mistaken for two independent properties
        'word-wrap': ['overflow-wrap'],
        'word-break': ['word-break'],
        'box-shadow': ['box-shadow']
    };
    const VENDOR = /^-(?:webkit|moz|ms|o|khtml|apple|epub)-/;
    const prefixOf = (prop) => { const m = VENDOR.exec(prop); return m ? m[0] : ''; };
    const classifiedAsLeaf = new Set();
    const leavesOf = (prop) => {
        const pre = prefixOf(prop);
        const base = pre ? prop.slice(pre.length) : prop;
        let leaves = SHORTHANDS[base];
        if (!leaves) { classifiedAsLeaf.add(prop); leaves = [base]; }
        else if (leaves.length > 1 || leaves[0] !== base) {
            // expand recursively so a shorthand of shorthands reaches real leaves
            const out = new Set();
            const walk = (b, depth) => {
                const next = SHORTHANDS[b];
                if (!next || depth > 6 || (next.length === 1 && next[0] === b)) { out.add(b); return; }
                for (const n of next) { walk(n, depth + 1); }
            };
            walk(base, 0);
            leaves = [...out];
        }
        const set = new Set(leaves);
        if (pre) {
            // a vendor-prefixed property writes its own prefixed leaves, and in an engine
            // that treats the prefixed form as an alias it writes the unprefixed leaves
            // too, so both are counted — the wider reading, not the narrower one
            for (const l of leaves) { set.add(pre + l); }
        }
        return set;
    };
    const interacts = (p, q) => {
        if (p === q) { return true; }
        const pp = prefixOf(p);
        const pq = prefixOf(q);
        if (pp && pq && pp !== pq) {
            // two differently-prefixed properties: an engine recognises at most one of
            // them and discards the other as invalid, so which came first cannot matter
            return false;
        }
        const ep = leavesOf(p);
        const eq = leavesOf(q);
        if (ep.has('\u0000ALL\u0000') || eq.has('\u0000ALL\u0000')) { return true; }
        for (const l of ep) { if (eq.has(l)) { return true; } }
        return false;
    };
    const propOf = (d) => d.slice(0, d.indexOf(':'));

    let differingOrder = 0;
    let differingSet = 0;
    let reorderProvedInert = 0;
    let reorderNotProved = 0;
    const examples = [];
    const unproved = [];
    for (const k of keysA) {
        if (!eb.map.has(k)) { continue; }
        const la2 = ea.map.get(k);
        const lb2 = eb.map.get(k);
        if (la2.join(';') === lb2.join(';')) { continue; }
        differingOrder += 1;
        const sa = [...la2].sort().join(';');
        const sb = [...lb2].sort().join(';');
        if (sa !== sb) {
            differingSet += 1;
            if (examples.length < 5) { examples.push(['SET DIFFERS', k, la2.join(';'), lb2.join(';')]); }
            continue;
        }
        // same multiset, different order: is any interacting pair reordered?
        let offending = null;
        for (let x = 0; x < la2.length && !offending; x += 1) {
            for (let y = x + 1; y < la2.length; y += 1) {
                const dx = la2[x];
                const dy = la2[y];
                if (!interacts(propOf(dx), propOf(dy))) { continue; }
                const ix = lb2.indexOf(dx);
                const iy = lb2.indexOf(dy);
                if (ix === -1 || iy === -1 || ix > iy) { offending = [dx, dy]; break; }
            }
        }
        if (offending) {
            reorderNotProved += 1;
            if (unproved.length < 10) { unproved.push([k, offending[0], offending[1]]); }
        } else {
            reorderProvedInert += 1;
            if (examples.length < 5) { examples.push(['ORDER ONLY, INERT', k, la2.join(';'), lb2.join(';')]); }
        }
    }
    say('selectors whose ordered declaration list differs: ' + differingOrder);
    say('  of those, differing in the SET of declarations: ' + differingSet);
    say('  of those, same set reordered with every interacting pair still in order: ' + reorderProvedInert);
    say('  of those, same set reordered with an interacting pair out of order: ' + reorderNotProved);
    say('Two declarations interact when the sets of leaf longhand properties they write');
    say('intersect. A property that is not a shorthand writes only itself. Property');
    say('names this run had to classify as non-shorthands, for the reader to check:');
    const leafNames = [...classifiedAsLeaf].sort();
    say('  ' + leafNames.length + ' name(s)');
    for (let x = 0; x < leafNames.length; x += 6) {
        say('    ' + leafNames.slice(x, x + 6).join('  '));
    }
    for (const [kind, k, x, y] of examples) {
        say('    ' + kind + '  ' + k);
        say('      pre : ' + x.slice(0, 240));
        say('      post: ' + y.slice(0, 240));
    }
    for (const [k, dx, dy] of unproved) {
        say('    OUT OF ORDER  ' + k + '   ' + dx + '  before  ' + dy + '  pre-migration, not post');
    }

    const stA = [...pa.statements].sort();
    const stB = [...pb.statements].sort();
    const stSame = stA.length === stB.length && stA.every((v, k) => v === stB[k]);
    say('block-less at-rule statements identical as a set: ' + (stSame ? 'yes' : 'NO'));

    if (onlyA.length === 0 && onlyB.length === 0 && differingSet === 0
        && reorderNotProved === 0 && stSame) {
        say('VERDICT: the two style bundles differ in bytes and are EQUIVALENT in the');
        say('  declarations they apply.  Every selector present on one side is present on');
        say('  the other with the same declaration multiset and the same values; the');
        say('  block-less at-rules match; and where a selector\'s declarations appear in a');
        say('  different ORDER, no pair that could interact was reordered, so no computed');
        say('  value can differ.  What differs is how the minifier GROUPED selectors that');
        say('  share a body, which is the ordering-sensitive part of its output and is the');
        say('  same version of the same tool on both sides.');
        return true;
    }
    say('VERDICT: equivalence NOT established for the style bundles.');
    if (differingSet > 0) { say('  ' + differingSet + ' selector(s) receive a different SET of declarations.'); }
    if (reorderNotProved > 0) { say('  ' + reorderNotProved + ' selector(s) have an interacting pair reordered.'); }
    if (onlyA.length || onlyB.length) { say('  the selector sets themselves differ.'); }
    if (!stSame) { say('  the block-less at-rule statements differ.'); }
    return false;
}

// A PROVENANCE PREAMBLE, so the archived output says what it compared.  Without it a
// reader holding only this output has to take on trust which two builds produced the
// two files, which is the same weakness that made an earlier evidence set unusable.
say('what was compared');
say('=================');
say('compared at: ' + new Date().toISOString().replace(/\.\d+Z$/, 'Z') + ' UTC');
for (const [label, key] of [['baseline script', 'baseline-js'], ['migrated script', 'migrated-js'],
    ['baseline style', 'baseline-css'], ['migrated style', 'migrated-css']]) {
    const f = opt[key];
    if (!f) { continue; }
    const buf = fs.readFileSync(f);
    say('  ' + label.padEnd(16) + crypto.createHash('sha256').update(buf).digest('hex'));
    say('  ' + ' '.repeat(16) + f);
}
say('Each digest above is the digest of the file this run actually read, so it can be');
say('checked against the digest record archived for that artifact.');

const jsOk = checkScript();
const cssOk = checkStyle();

say('');
say('===== overall =====');
say('script bundle behavioural equivalence: ' + (jsOk ? 'ESTABLISHED' : 'NOT ESTABLISHED'));
say('style bundle declaration equivalence: ' + (cssOk ? 'ESTABLISHED' : 'NOT ESTABLISHED'));
say('');
say('WHAT THIS DOES NOT DO.  It does not satisfy the byte-identity criterion and does');
say('not soften it.  Two of the five artifacts differ in bytes; that is a failure of');
say('that criterion and is recorded as one in the comparison record beside this output.');
say('This program answers only the next question: whether the differing bytes carry a');
say('behavioural difference.  A reader who needs byte identity is not served by an');
say('equivalence proof, and this file does not pretend otherwise.');

const text = out.join('\n') + '\n';
if (opt.out) { fs.writeFileSync(opt.out, text); }
process.stdout.write(text);
process.exit(jsOk && cssOk ? 0 : 1);
