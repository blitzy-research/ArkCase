'use strict';

/**
 * Prebuild helper: guarantee that the frontend root carries a `profiles.js`
 * module before Grunt runs.
 *
 * `config/config.js` requires `./../profiles` unconditionally, and that module
 * is normally produced at deploy time by the Java assembler
 * (`AngularResourceCopier.createProfilesJsFileInDir`), which writes it into the
 * assembly temp folder immediately before invoking Grunt. A bare checkout has
 * no `profiles.js` at all, so the Grunt configuration cannot be loaded and
 * `npm run build` fails before it starts. This helper closes that gap for the
 * checkout case only: it is wired as the `prebuild` script in `package.json`,
 * which npm runs automatically ahead of `build`. It is deliberately absent from
 * the deploy-time copy lists, so on a deployed instance the Java writer remains
 * the single producer of `profiles.js`.
 *
 * WHAT IT EMITS - byte-for-byte what the Java writer emits:
 *
 *     module.exports = { profiles: [ 'custom' ] };
 *
 * single quotes, exactly one space inside each bracket, a trailing semicolon,
 * and NO trailing newline (the Java side streams the bare string, so none is
 * ever appended). `profiles.js` is a behavioural contract rather than a source
 * file: do not reformat it, pretty-print it, add a banner to it, or terminate
 * it with a newline.
 *
 * WHY IT NEVER OVERWRITES - this is a deliberate divergence from the Java
 * writer, which uses `StandardCopyOption.REPLACE_EXISTING`. At deploy time
 * `profiles.js` may legitimately hold an extension profile alongside `custom`
 * (for example `module.exports = { profiles: [ 'foia', 'custom' ] };`), and an
 * unconditional write would silently downgrade such a deployment to the single
 * default profile. That is why the file is created only when absent (the
 * "ensure" in the filename) and why the guard below must not be simplified
 * away.
 */
var fs = require('fs'), path = require('path');

/**
 * Name of the generated module, resolved relative to the frontend root.
 */
var PROFILES_FILE_NAME = 'profiles.js';

/**
 * Profile list the Java assembler falls back to when no extension profile is
 * active: `.orElse(Collections.singletonList("custom"))`. A checkout has no
 * Spring context and therefore no extension profile, so this default is always
 * the correct one here. It is not configurable, and it is not read from the
 * environment, precisely so the emitted bytes cannot drift from the assembler.
 */
var DEFAULT_PROFILES = [ 'custom' ];

/**
 * Render the profiles module exactly as the Java assembler does: each profile
 * single-quoted, joined with `, `, wrapped in `{ profiles: [ ` ... ` ] };` and
 * prefixed with `module.exports = `. Building the string from the array keeps
 * the multi-profile shape legible instead of hiding the contract behind one
 * opaque literal, and keeps this helper honest if the default ever changes.
 *
 * @param {string[]} profiles active profile names, in the assembler's order
 * @returns {string} the module body, deliberately without a trailing newline
 */
function renderProfilesModule(profiles) {
    var quoted = profiles.map(function(profile) {
        return '\'' + profile + '\'';
    });

    return 'module.exports = { profiles: [ ' + quoted.join(', ') + ' ] };';
}

/**
 * Absolute path of the generated module. Resolved from `__dirname` and never
 * from `process.cwd()`, so the helper is correct wherever it is invoked from:
 * npm happens to run lifecycle scripts with the package root as the working
 * directory, but nothing here may depend on that. The parent of the target is
 * the package root, which always exists, so no directory is ever created.
 *
 * @returns {string} absolute path of `<frontend root>/profiles.js`
 */
function resolveProfilesPath() {
    return path.join(__dirname, '..', PROFILES_FILE_NAME);
}

/**
 * Create `<frontend root>/profiles.js` when, and only when, it is absent.
 *
 * The exclusive `wx` flag makes the check-and-create one atomic operation, so a
 * file that is already present is never opened for writing and keeps both its
 * content and its modification time, with no separate existence check to race
 * against. `EEXIST` is therefore the expected "already provisioned" outcome and
 * is reported rather than raised. Any other failure is genuine (an unwritable
 * package root, for instance): it is reported with the failing path and error
 * code and then re-raised, because letting the build continue would only
 * surface later as an opaque module-not-found error out of `config/config.js`.
 *
 * @returns {boolean} true when the file was created, false when it was skipped
 */
function ensureProfilesModule() {
    var target = resolveProfilesPath();

    try {
        fs.writeFileSync(target, renderProfilesModule(DEFAULT_PROFILES), {
            encoding: 'utf8',
            flag: 'wx'
        });
    } catch (error) {
        if (error && error.code === 'EEXIST') {
            console.log('ensure-profiles: ' + target + ' already exists; leaving it untouched.');
            return false;
        }

        console.error('ensure-profiles: could not create ' + target + ' [' + (error && error.code) + ']');
        throw error;
    }

    console.log('ensure-profiles: created ' + target + ' with profiles [ ' + DEFAULT_PROFILES.join(', ') + ' ].');
    return true;
}

/**
 * Run only when executed directly (`node scripts/ensure-profiles.js`, which is
 * how the `prebuild` script invokes it), so the module can also be required for
 * verification without touching the filesystem. Both outcomes, created and
 * skipped, exit 0; only a genuine I/O failure propagates and fails the build.
 */
if (require.main === module) {
    ensureProfilesModule();
}

module.exports = {
    DEFAULT_PROFILES: DEFAULT_PROFILES,
    PROFILES_FILE_NAME: PROFILES_FILE_NAME,
    renderProfilesModule: renderProfilesModule,
    resolveProfilesPath: resolveProfilesPath,
    ensureProfilesModule: ensureProfilesModule
};
