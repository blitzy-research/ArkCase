'use strict';

/**
 * Prebuild helper, wired as the `prebuild` script so npm runs it ahead of `build`: it puts a `profiles.js`
 * module in the frontend root when a checkout has none. At deploy time the Java assembler
 * (`AngularResourceCopier.createProfilesJsFileInDir`) is the producer, and this helper is deliberately absent
 * from the deploy-time copy lists so it stays the only one there.
 *
 * The emitted bytes are a contract, matching the assembler exactly - single quotes, one space inside each
 * bracket, a trailing semicolon, no trailing newline:
 *
 *     module.exports = { profiles: [ 'custom' ] };
 *
 * Creation is conditional on absence, unlike the assembler's REPLACE_EXISTING write, because a deployed
 * `profiles.js` may hold an extension profile alongside `custom` and overwriting it would silently downgrade
 * that deployment to the single default profile.
 */
var fs = require('fs'), path = require('path');

var PROFILES_FILE_NAME = 'profiles.js';

/**
 * Mirrors the assembler's own fallback, `.orElse(Collections.singletonList("custom"))`. Not configurable and
 * not read from the environment, so the emitted bytes cannot drift from it.
 */
var DEFAULT_PROFILES = [ 'custom' ];

/**
 * Tests structural completeness only - the assignment head, the `profiles` key and the closing `] };` - so a
 * truncated or empty file fails it. It does not parse the module and so does not prove that node can load it;
 * quoting style, spacing and a trailing newline all pass, deliberately, so a benign difference between the two
 * legitimate producers does not fail a build.
 */
var COMPLETE_MODULE_PATTERN = /^\s*module\.exports\s*=\s*\{\s*profiles\s*:\s*\[[\s\S]*\]\s*\}\s*;?\s*$/;

/**
 * Name shape of the sibling temporary file the module is published from. The `.tmp` suffix keeps it out of
 * every `*.js` glob in `config/env/all.js`; the process id and millisecond clock keep concurrent runs apart.
 */
var TEMPORARY_PREFIX = '.' + PROFILES_FILE_NAME + '.';
var TEMPORARY_SUFFIX = '.tmp';

// Bounds the name search so a collision ends in a clear error rather than an unbounded loop.
var TEMPORARY_NAME_ATTEMPTS = 10;

/**
 * Codes that mean the filesystem cannot make a hard link at all, as opposed to refusing this particular one.
 * FAT32 and exFAT have no link operation; many SMB/CIFS and NFS mounts and some container bind-mounts refuse
 * it; and the deploy driver documents Windows support, where a temp folder can easily sit on such a volume.
 * `EEXIST` is deliberately absent: that is the create-only outcome the publication relies on, not a missing
 * capability. `EPERM` appears here because that is what a link-less volume reports, and it is safe to include
 * even though a permission problem raises it too - the fallback then fails the same way the link did.
 */
var HARD_LINK_UNSUPPORTED_CODES = [ 'EPERM', 'EXDEV', 'ENOSYS', 'EOPNOTSUPP', 'ENOTSUP' ];

function isHardLinkUnsupported(error) {
    return !!error && HARD_LINK_UNSUPPORTED_CODES.indexOf(error.code) !== -1;
}

// Returns the module body the assembler emits, deliberately without a trailing newline.
function renderProfilesModule(profiles) {
    var quoted = profiles.map(function(profile) {
        return '\'' + profile + '\'';
    });

    return 'module.exports = { profiles: [ ' + quoted.join(', ') + ' ] };';
}

// Resolved from `__dirname`, never `process.cwd()`, so the helper is correct wherever it is invoked from. The
// parent is the package root, which always exists, so no directory is ever created.
function resolveProfilesPath() {
    return path.join(__dirname, '..', PROFILES_FILE_NAME);
}

function describeUnusableTarget(target, reason) {
    return 'ensure-profiles: ' + target + ' already exists but cannot be used, because ' + reason +
        '. Remove it and run the build again - the next prebuild writes ' +
        renderProfilesModule(DEFAULT_PROFILES) + ' in its place.';
}

/**
 * Second half of the create-only contract: a directory, a dangling symbolic link and a half-written file all
 * occupy the target path, and accepting one silently would let a single interrupted write poison every later
 * build, since create-only then preserves it forever. Only structural completeness is checked, not
 * loadability, so a file that is whole but not valid JavaScript still reaches node. `statSync` rather than
 * `lstatSync` deliberately: a link to a real module is accepted, as node would accept it, while a dangling one
 * surfaces as `ENOENT`.
 */
function verifyExistingModule(target) {
    var stats, body;

    try {
        stats = fs.statSync(target);
    } catch (error) {
        if (error && error.code === 'ENOENT') {
            throw new Error(describeUnusableTarget(target, 'it is a symbolic link that resolves to nothing'));
        }

        throw error;
    }

    if (!stats.isFile()) {
        throw new Error(describeUnusableTarget(target, 'it is not a regular file'));
    }

    body = fs.readFileSync(target, 'utf8');

    if (!COMPLETE_MODULE_PATTERN.test(body)) {
        throw new Error(describeUnusableTarget(target, 'its ' + stats.size +
            ' bytes are not a complete profiles module, which is what an interrupted write leaves behind'));
    }
}

/**
 * Remove the temporary file, whether or not it was published.
 *
 * Runs on every path. After a successful link the temporary name is a second link to the same inode, so
 * dropping it leaves the published module untouched; otherwise it is the only link and dropping it leaves
 * nothing behind. An unlink failure is reported and swallowed: it says nothing about whether the target is
 * correct, and on a failure path throwing here would replace the diagnosis with the cleanup.
 *
 * Declared ahead of `writeTemporaryModule` because that function calls it to clear its own partial file, and
 * `.jshintrc` sets `latedef`.
 *
 * @param {?string} temporary path returned by, or staged inside, `writeTemporaryModule`, or null
 * @returns {void}
 */
function removeTemporaryModule(temporary) {
    if (!temporary) {
        return;
    }

    try {
        fs.unlinkSync(temporary);
    } catch (error) {
        if (!error || error.code !== 'ENOENT') {
            console.error('ensure-profiles: could not remove the temporary file ' + temporary +
                ' [' + (error && error.code) + ']');
        }
    }
}

/**
 * Write the module body to a fresh sibling temporary file and return its path.
 *
 * Staging the bytes elsewhere first, and syncing them before the descriptor closes, is what lets
 * `ensureProfilesModule` publish a complete inode in one step. The temporary file must share the target's
 * directory, because the hard link that publishes it cannot cross a filesystem boundary.
 *
 * A failed staging attempt is cleaned up here rather than by the caller, because the candidate path is a local:
 * it reaches `ensureProfilesModule` only through the return value, so a write, `fsync` or close that throws
 * would leave the caller with `null` and nothing to remove, and the partial file would sit in the frontend root
 * under a name no later run reproduces. The descriptor is closed, the candidate unlinked, and the original
 * failure re-raised unchanged so the caller still reports the real cause.
 *
 * @param {string} directory the frontend root, i.e. the target's parent
 * @param {string} body the module body to stage
 * @returns {string} absolute path of the written, synced temporary file
 * @throws {Error} the write, `fsync` or close failure, after the partial file has been removed; or a plain
 *         Error when no free temporary name could be reserved, in which case nothing was created
 */
function writeTemporaryModule(directory, body) {
    var attempt, candidate, descriptor;

    for (attempt = 0; attempt < TEMPORARY_NAME_ATTEMPTS; attempt++) {
        candidate = path.join(directory, TEMPORARY_PREFIX + process.pid + '-' + Date.now() + '-' + attempt +
            TEMPORARY_SUFFIX);

        try {
            descriptor = fs.openSync(candidate, 'wx');
        } catch (error) {
            if (error && error.code === 'EEXIST') {
                continue;
            }

            throw error;
        }

        try {
            try {
                fs.writeFileSync(descriptor, body, 'utf8');
                fs.fsyncSync(descriptor);
            } finally {
                fs.closeSync(descriptor);
            }
        } catch (error) {
            // The inner `finally` has already released the descriptor - including
            // when the close itself is what failed - so nothing holds the inode
            // open while the entry is dropped. The unlink cannot mask the failure
            // being re-raised: `removeTemporaryModule` reports its own trouble and
            // never throws.
            removeTemporaryModule(candidate);

            throw error;
        }

        return candidate;
    }

    throw new Error('ensure-profiles: could not reserve a temporary file in ' + directory + ' after ' +
        TEMPORARY_NAME_ATTEMPTS + ' attempts.');
}

/**
 * Publish the staged module by moving it, for filesystems with no hard-link operation.
 *
 * `rename` would replace an existing `profiles.js`, which is the one thing this helper must never do, so the
 * target is tested first and an existing file is reported as `EEXIST` - the same code `link` raises - so the
 * caller's create-only handling is identical on both paths.
 *
 * @param {string} temporary path of the staged file
 * @param {string} target path the module is published at
 */
function publishByRename(temporary, target) {
    if (fs.existsSync(target)) {
        var occupied = new Error('ensure-profiles: ' + target + ' already exists.');
        occupied.code = 'EEXIST';
        throw occupied;
    }

    fs.renameSync(temporary, target);
}

/**
 * Create `<frontend root>/profiles.js` when, and only when, it is absent.
 *
 * Publication is a single atomic step: the module is staged in a sibling temporary file, synced, and then
 * linked into place. `link` refuses to clobber, so the name appears exactly once already carrying every byte -
 * whereas writing straight to `profiles.js` with an exclusive flag reserves the name before the bytes exist,
 * and a crash after that leaves a half-written module the create-only rule would then preserve forever.
 * `rename` is unsuitable for the same reason the flag was exclusive: it would replace a `profiles.js` a
 * deployment legitimately populated.
 *
 * `EEXIST` is the expected "already provisioned" outcome, believed only after `verifyExistingModule` accepts
 * what occupies the path; the file is never opened for writing, so its content and modification time survive
 * either way. Any other error is reported with the failing path and code and re-raised, since continuing would
 * only resurface as an opaque module-not-found out of `config/config.js`.
 *
 * The directory entry is deliberately not synced after the link: a crash before it reaches the device leaves
 * the module absent, which the next prebuild simply repairs. The property worth paying for is that a module
 * which is present is always whole, and the `fsync` before publication is what buys it.
 *
 * Where the filesystem has no hard links at all - FAT32, exFAT, many network shares, some container
 * bind-mounts - `link` cannot be used and `rename` publishes instead. `rename` does clobber, so the create-only
 * rule is enforced by testing for the target first and reporting a synthetic `EEXIST`, which routes that case
 * into exactly the same "already provisioned" branch below. That test and the rename are two steps rather than
 * one, so this path is not atomic against a second writer that creates `profiles.js` in between: it trades the
 * link path's guarantee for working at all on a volume that cannot link, and it is entered only when the link
 * was refused for want of the capability. Both producers are single prebuild or deploy steps, so a concurrent
 * second writer is not a situation either of them creates.
 *
 * @returns {boolean} true when the file was created, false when it was skipped
 */
function ensureProfilesModule() {
    var target = resolveProfilesPath();
    var temporary = null;

    try {
        temporary = writeTemporaryModule(path.dirname(target), renderProfilesModule(DEFAULT_PROFILES));

        try {
            fs.linkSync(temporary, target);
        } catch (linkError) {
            if (!isHardLinkUnsupported(linkError)) {
                throw linkError;
            }

            console.log('ensure-profiles: hard links are unavailable here [' + linkError.code +
                ']; publishing ' + target + ' by rename instead.');
            publishByRename(temporary, target);

            // The rename moved the staged file, so there is no longer a temporary to clean up. Clearing the
            // handle keeps the `finally` below from unlinking a path that no longer names the staged bytes.
            temporary = null;
        }
    } catch (error) {
        // `writeTemporaryModule` retries its own EEXIST and reports exhaustion as a
        // plain Error, so an EEXIST reaching this point can only be the published
        // name already being taken.
        if (error && error.code === 'EEXIST') {
            verifyExistingModule(target);
            console.log('ensure-profiles: ' + target + ' already exists; leaving it untouched.');
            return false;
        }

        console.error('ensure-profiles: could not create ' + target + ' [' + (error && error.code) + ']');
        throw error;
    } finally {
        removeTemporaryModule(temporary);
    }

    console.log('ensure-profiles: created ' + target + ' with profiles [ ' + DEFAULT_PROFILES.join(', ') + ' ].');
    return true;
}

// Run only when executed directly (`node scripts/ensure-profiles.js`, which is how the `prebuild` script
// invokes it), so the same file can also be required by the test suite. Created and skipped both exit 0; only
// a genuine I/O failure propagates and fails the build.
if (require.main === module) {
    ensureProfilesModule();
}

module.exports = {
    DEFAULT_PROFILES: DEFAULT_PROFILES,
    PROFILES_FILE_NAME: PROFILES_FILE_NAME,
    renderProfilesModule: renderProfilesModule,
    resolveProfilesPath: resolveProfilesPath,
    verifyExistingModule: verifyExistingModule,
    ensureProfilesModule: ensureProfilesModule
};
