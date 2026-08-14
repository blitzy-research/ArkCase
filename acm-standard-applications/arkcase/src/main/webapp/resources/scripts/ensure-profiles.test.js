'use strict';

/**
 * Tests for the `prebuild` helper `scripts/ensure-profiles.js`, run by `npm test` on Node 20 with the runtime's
 * built-in `node:test` runner. No test dependency is added: `node --test` is not a watcher and exits non-zero on
 * the first failing test, so it is safe in CI and adds nothing to the committed lockfile.
 *
 * WHAT IS UNDER TEST, AND WHY IT MATTERS
 *
 * The helper emits `profiles.js`, the module `config/config.js` requires unconditionally. Two properties of it are
 * contracts rather than implementation details, and neither is checkable by any other means:
 *
 *   1. The EXACT BYTES. The same module is written at deploy time by the Java assembler
 *      (`AngularResourceCopier.createProfilesJsFileInDir`), and the two writers must not drift: single quotes, one
 *      space inside each bracket, a trailing semicolon and NO trailing newline. A formatter, a linter autofix or a
 *      "helpful" newline would silently make the checkout build differ from the deployed build.
 *   2. It NEVER OVERWRITES. On a deployed instance `profiles.js` may legitimately carry an extension profile
 *      alongside `custom`; an unconditional write would downgrade that deployment to the single default profile.
 *
 * The create / non-overwrite / failure cases run against a COPY of the helper placed in a throwaway directory with
 * the same `scripts/<file>` layout, so `__dirname` resolves inside the temporary tree. That keeps the suite
 * hermetic - it never creates, modifies or deletes anything in the working tree, including the repository's own
 * `profiles.js` - while still exercising the real file rather than a re-implementation of it.
 */
var assert = require('node:assert');
var crypto = require('node:crypto');
var fs = require('node:fs');
var os = require('node:os');
var path = require('node:path');
var test = require('node:test');

var HELPER_FILE_NAME = 'ensure-profiles.js';
var HELPER_PATH = path.join(__dirname, HELPER_FILE_NAME);
var FRONTEND_ROOT = path.join(__dirname, '..');
var MANIFEST_PATH = path.join(FRONTEND_ROOT, 'package.json');

/** The module body the Java assembler emits for the default single-profile case, byte for byte. */
var EXPECTED_DEFAULT_MODULE = 'module.exports = { profiles: [ \'custom\' ] };';

/** SHA-256 of EXPECTED_DEFAULT_MODULE, so a drift is reported as a digest mismatch as well as a text one. */
var EXPECTED_DEFAULT_SHA256 = crypto.createHash('sha256').update(EXPECTED_DEFAULT_MODULE, 'utf8').digest('hex');

/**
 * Copy the real helper into a fresh temporary `scripts/` directory and load it from there, so its `__dirname`
 * (and therefore the file it manages) lives entirely inside that directory. The directory is removed when the
 * calling test finishes, so repeated runs leave nothing behind.
 *
 * @param {object} t the running test's context, used to register the cleanup
 * @returns {{ helper: object, root: string, profilesPath: string }}
 */
function loadHelperInTemporaryRoot(t) {
    var root = fs.mkdtempSync(path.join(os.tmpdir(), 'ensure-profiles-test-'));
    var scriptsDir = path.join(root, 'scripts');
    fs.mkdirSync(scriptsDir);

    var helperCopyPath = path.join(scriptsDir, HELPER_FILE_NAME);
    fs.copyFileSync(HELPER_PATH, helperCopyPath);

    t.after(function() {
        fs.rmSync(root, { recursive: true, force: true });
    });

    return {
        helper: require(helperCopyPath),
        root: root,
        profilesPath: path.join(root, 'profiles.js')
    };
}

test('renders the default profile list exactly as the Java assembler does', function() {
    var helper = require(HELPER_PATH);

    var rendered = helper.renderProfilesModule(helper.DEFAULT_PROFILES);

    assert.strictEqual(rendered, EXPECTED_DEFAULT_MODULE);
    assert.strictEqual(crypto.createHash('sha256').update(rendered, 'utf8').digest('hex'),
        EXPECTED_DEFAULT_SHA256);
    assert.ok(!/\n$/.test(rendered), 'the module must not end with a newline');
    assert.deepStrictEqual(helper.DEFAULT_PROFILES, [ 'custom' ]);
});

test('renders a multi-profile list with the assembler\'s separator and quoting', function() {
    var helper = require(HELPER_PATH);

    assert.strictEqual(helper.renderProfilesModule([ 'foia', 'custom' ]),
        'module.exports = { profiles: [ \'foia\', \'custom\' ] };');
});

test('resolves the target from __dirname rather than the working directory', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    assert.strictEqual(loaded.helper.resolveProfilesPath(), loaded.profilesPath);
    assert.strictEqual(path.basename(loaded.helper.resolveProfilesPath()), loaded.helper.PROFILES_FILE_NAME);
});

test('creates the module with the exact expected bytes when it is absent', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    assert.strictEqual(loaded.helper.ensureProfilesModule(), true, 'a fresh root must report a creation');

    var written = fs.readFileSync(loaded.profilesPath);
    assert.strictEqual(written.toString('utf8'), EXPECTED_DEFAULT_MODULE);
    assert.strictEqual(crypto.createHash('sha256').update(written).digest('hex'), EXPECTED_DEFAULT_SHA256);
    assert.strictEqual(written.length, Buffer.byteLength(EXPECTED_DEFAULT_MODULE, 'utf8'));
});

test('leaves an existing module untouched, keeping both its content and its modification time', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    var deployedModule = 'module.exports = { profiles: [ \'foia\', \'custom\' ] };';
    fs.writeFileSync(loaded.profilesPath, deployedModule, 'utf8');
    var backdated = new Date(Date.now() - 60000);
    fs.utimesSync(loaded.profilesPath, backdated, backdated);
    var before = fs.statSync(loaded.profilesPath);

    assert.strictEqual(loaded.helper.ensureProfilesModule(), false, 'an existing module must report a skip');

    var after = fs.statSync(loaded.profilesPath);
    assert.strictEqual(fs.readFileSync(loaded.profilesPath, 'utf8'), deployedModule,
        'a deployed extension profile must not be downgraded to the default');
    assert.strictEqual(after.mtimeMs, before.mtimeMs,
        'the exclusive create must not even open the file for writing');
});

test('propagates a genuine I/O failure instead of reporting a skip', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    // An absent package root - the very failure the helper's own comment names ("an unwritable package root, for
    // instance"). The helper is already loaded, so removing the tree leaves it writing into a directory that no
    // longer exists. Deliberately NOT simulated by revoking write permission on the root: the build can run as a
    // user for whom permissions are advisory, which would make such a test pass or fail by accident. Nor by
    // placing a directory at the target path - an exclusive create reports that as EEXIST, which is the
    // "already provisioned" outcome rather than a failure.
    fs.rmSync(loaded.root, { recursive: true, force: true });

    assert.throws(function() {
        loaded.helper.ensureProfilesModule();
    }, function(error) {
        assert.notStrictEqual(error.code, 'EEXIST', 'a real I/O failure must not be reported as EEXIST');
        assert.strictEqual(error.code, 'ENOENT', 'unexpected error code: ' + error.code);
        return true;
    });
});

test('publishes the module atomically and leaves no temporary file behind', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    assert.strictEqual(loaded.helper.ensureProfilesModule(), true);

    // The module is staged in a sibling temporary file, synced, and only then published under its real
    // name with a hard link. Both links are dropped afterwards except the published one, so the frontend
    // root must contain exactly the module and nothing resembling a staging file - a survivor would be
    // picked up by the `*.js` globs in config/env/all.js on the next build.
    var leftovers = fs.readdirSync(loaded.root).filter(function(entry) {
        return entry !== 'scripts' && entry !== loaded.helper.PROFILES_FILE_NAME;
    });

    assert.deepStrictEqual(leftovers, [], 'unexpected entries in the frontend root: ' + leftovers.join(', '));
});

test('rejects a truncated module rather than protecting it forever', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    // What an interrupted write leaves behind. The create-only rule means a bad file here would be
    // preserved by every later build, so it must be reported instead of accepted.
    fs.writeFileSync(loaded.profilesPath, 'module.exports = { profiles: [ \'cus', 'utf8');

    assert.throws(function() {
        loaded.helper.ensureProfilesModule();
    }, function(error) {
        assert.ok(/cannot be used/.test(error.message), 'unexpected message: ' + error.message);
        assert.ok(error.message.indexOf(loaded.profilesPath) >= 0, 'the message must name the path');
        return true;
    });
});

test('rejects a directory occupying the target path', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    fs.mkdirSync(loaded.profilesPath);

    assert.throws(function() {
        loaded.helper.ensureProfilesModule();
    }, function(error) {
        assert.ok(/not a regular file/.test(error.message), 'unexpected message: ' + error.message);
        return true;
    });
});

test('accepts a deployed module written by the Java assembler', function(t) {
    var loaded = loadHelperInTemporaryRoot(t);

    // Exactly the bytes AngularResourceCopier.createProfilesJsFileInDir emits for an extension profile.
    fs.writeFileSync(loaded.profilesPath, 'module.exports = { profiles: [ \'foia\', \'custom\' ] };', 'utf8');

    assert.doesNotThrow(function() {
        loaded.helper.verifyExistingModule(loaded.profilesPath);
    });
    assert.strictEqual(loaded.helper.ensureProfilesModule(), false);
});

test('the manifest wires the helper as the prebuild step of the Grunt build', function() {
    var manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));

    assert.strictEqual(manifest.scripts.prebuild, 'node scripts/' + HELPER_FILE_NAME,
        'npm runs prebuild automatically ahead of build; this is the only thing that guarantees profiles.js '
        + 'exists in a bare checkout');
    assert.strictEqual(manifest.scripts.build, 'grunt default',
        'the build must invoke the Grunt default task so the emitted bundle set is unchanged');
    assert.strictEqual(manifest.scripts.test, 'node --test scripts/',
        'the test script must stay non-watch and dependency-free');
    assert.ok(!Object.prototype.hasOwnProperty.call(manifest.dependencies || {}, 'node'),
        'the test runner is built into Node 20 and must not be declared as a dependency');
});
