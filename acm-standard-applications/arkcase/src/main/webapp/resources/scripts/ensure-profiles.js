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
 * Structural signature of a *complete* profiles module, used to decide whether a
 * `profiles.js` that is already on disk may be kept. It matches the assignment
 * head, the `profiles` key, and - the part that carries the weight - the closing
 * `] };`, so a file truncated anywhere in the middle fails it and an empty file
 * fails it too.
 *
 * It is deliberately tolerant about everything else: quoting style, spacing and
 * a trailing newline all pass. The question being asked is "is this file whole?",
 * not "is this file formatted the way I would have formatted it". A stricter
 * grammar would start failing builds over a benign difference between two
 * legitimate producers, which is a worse outcome than the defect it guards.
 */
var COMPLETE_MODULE_PATTERN = /^\s*module\.exports\s*=\s*\{\s*profiles\s*:\s*\[[\s\S]*\]\s*\}\s*;?\s*$/;

/**
 * Name shape of the sibling temporary file the finished module is published
 * from. The leading dot keeps it out of the way, the `.tmp` suffix keeps it out
 * of every `*.js` glob in `config/env/all.js`, and the process id plus
 * millisecond clock in the middle keep two concurrent runs from colliding.
 */
var TEMPORARY_PREFIX = '.' + PROFILES_FILE_NAME + '.';
var TEMPORARY_SUFFIX = '.tmp';

/**
 * How many names the temporary file may try before giving up. A collision needs
 * a leftover file from a crashed run that shared this process id *and* landed in
 * the same millisecond, so one attempt is realistically always enough; the
 * budget exists so that the impossible case ends in a clear error rather than an
 * unbounded loop.
 */
var TEMPORARY_NAME_ATTEMPTS = 10;

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
 * Wording of the failure raised when something already occupies the target path
 * but is not a module the build can load. It names the path, says what is wrong
 * with it, and states the one action that clears it - because a build that stops
 * without telling the operator what to do is only marginally better than a build
 * that carries on with a broken module.
 *
 * @param {string} target absolute path of the unusable entry
 * @param {string} reason what is wrong with it, as a clause
 * @returns {string} the diagnostic message
 */
function describeUnusableTarget(target, reason) {
    return 'ensure-profiles: ' + target + ' already exists but cannot be used, because ' + reason +
        '. Remove it and run the build again - the next prebuild writes ' +
        renderProfilesModule(DEFAULT_PROFILES) + ' in its place.';
}

/**
 * Confirm that the `profiles.js` already sitting at the target path is a module
 * the Grunt configuration can actually load, and raise a diagnostic if it is not.
 *
 * This is the second half of the create-only contract. Reserving the name is not
 * the same as having published a module: a directory, a symbolic link that
 * resolves to nothing, or a file left half-written by an interrupted run all
 * occupy the path just as convincingly as a good module does. Accepting them
 * silently is what would let one interrupted write poison every later build,
 * since the create-only rule then preserves the damage forever. Failing here
 * costs one build and names its own remedy.
 *
 * `statSync` rather than `lstatSync` on purpose: it follows a symbolic link, so a
 * link pointing at a real module is accepted (node would resolve it too) while a
 * dangling one surfaces as `ENOENT` and is rejected.
 *
 * @param {string} target absolute path of the existing entry
 * @returns {void} returns normally when the entry is usable; throws otherwise
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
 * Write the module body to a fresh sibling temporary file and return its path.
 *
 * Staging the bytes somewhere else first is what makes the publication in
 * `ensureProfilesModule` a single step rather than two. `fsync` before the
 * descriptor is closed is the other half: it puts the bytes on the device while
 * the file is still invisible under the name the build reads, so the inode that
 * gets published is a complete one and never a promise of one.
 *
 * The temporary file is created in the same directory as the target, because the
 * hard link that publishes it cannot cross a filesystem boundary. No mode is
 * passed, so the file lands with the same default permissions the previous direct
 * write produced.
 *
 * @param {string} directory the frontend root, i.e. the target's parent
 * @param {string} body the module body to stage
 * @returns {string} absolute path of the written, synced temporary file
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
            fs.writeFileSync(descriptor, body, 'utf8');
            fs.fsyncSync(descriptor);
        } finally {
            fs.closeSync(descriptor);
        }

        return candidate;
    }

    throw new Error('ensure-profiles: could not reserve a temporary file in ' + directory + ' after ' +
        TEMPORARY_NAME_ATTEMPTS + ' attempts.');
}

/**
 * Remove the temporary file, whether or not it was published.
 *
 * After a successful link the temporary name is one of two links to the same
 * inode, so dropping it leaves the published module untouched; after a failure it
 * is the only link and dropping it leaves nothing behind. Either way the frontend
 * root keeps no debris. A failure to unlink is reported and swallowed on purpose:
 * the module itself is already correct by this point, and a stranded 44-byte file
 * is not worth failing a build over.
 *
 * @param {?string} temporary path returned by `writeTemporaryModule`, or null
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
 * Create `<frontend root>/profiles.js` when, and only when, it is absent.
 *
 * The module is staged in a sibling temporary file, synced to the device and only
 * then published under its real name with `link`, which is atomic and refuses to
 * clobber: the name appears exactly once, already carrying every byte. That
 * ordering is the point. Writing straight to `profiles.js` with an exclusive flag
 * also refuses to clobber, but it reserves the name *before* the bytes exist, so a
 * process killed mid-write - or an `ENOSPC`, or any I/O failure after the
 * directory entry appears - leaves a half-written module that the create-only rule
 * below then protects from ever being repaired. Everything the build does after
 * that point reads a broken module.
 *
 * `link` rather than `rename` for the same reason the previous flag was exclusive:
 * rename would silently replace a `profiles.js` that a deployment legitimately
 * populated with an extension profile.
 *
 * `EEXIST` from the link is still the expected "already provisioned" outcome, but
 * it is now believed only after `verifyExistingModule` confirms that what occupies
 * the path really is a loadable module; the file keeps its content and its
 * modification time either way, because nothing ever opens it for writing. Any
 * other failure is genuine (an unwritable frontend root, for instance - though the
 * pipeline writes its bundles into that same directory, so a build could not have
 * got this far without it): it is reported with the failing path and error code and
 * then re-raised, because letting the build continue would only surface later as an
 * opaque module-not-found error out of `config/config.js`.
 *
 * Note what is deliberately *not* done: the directory entry is not synced after the
 * link. A crash before the entry reaches the device leaves the module **absent**,
 * and absent is the self-healing state - the next prebuild simply writes it. The
 * only property worth paying for here is that a module which *is* present is always
 * whole, and the `fsync` before publication is what buys it.
 *
 * @returns {boolean} true when the file was created, false when it was skipped
 */
function ensureProfilesModule() {
    var target = resolveProfilesPath();
    var temporary = null;

    try {
        temporary = writeTemporaryModule(path.dirname(target), renderProfilesModule(DEFAULT_PROFILES));
        fs.linkSync(temporary, target);
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

// This file is a script, not a module: npm's `prebuild` hook runs it as
// `node scripts/ensure-profiles.js`. Both outcomes, created and skipped, exit 0;
// only a genuine I/O failure propagates and fails the build.
ensureProfilesModule();
