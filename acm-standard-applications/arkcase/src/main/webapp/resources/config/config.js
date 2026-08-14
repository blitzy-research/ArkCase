'use strict';

var _ = require('lodash'), glob = require('glob');

module.exports = _.extend(require('./env/all'));

/**
 * `profiles.js` is generated, never checked in - by AngularResourceCopier at deploy time and by the `prebuild`
 * script in a checkout - so only its absence is defaulted, to the single-profile value the assembler itself
 * emits. Every other failure is re-thrown rather than masked, because substituting that default would silently
 * downgrade a multi-profile deployment. Absence is therefore identified by MODULE_NOT_FOUND together with an
 * innermost require frame of this file, so a generated module that does not parse, throws, or has an
 * unresolvable require of its own surfaces its real error. `requireStack` is advisory: when node does not
 * supply it the code alone decides, which keeps a bare checkout building. The message text is never matched.
 */
try {
    var activeProfiles = require('./../profiles');
} catch (ex) {
    if (!ex || ex.code !== 'MODULE_NOT_FOUND' || (ex.requireStack && ex.requireStack[0] !== __filename)) {
        throw ex;
    }
    console.log('Active profiles module does not exist..continuing..');
    activeProfiles = { profiles: [ 'custom' ] };
}

module.exports.getGlobbedFiles = function(globPatterns, removeRoot) {
    var _this = this;
    var urlRegex = new RegExp('^(?:[a-z]+:)?\/\/', 'i');
    var output = [];

    // A URL is kept verbatim; only a filesystem pattern is expanded, and an array is expanded element by element.
    if (_.isArray(globPatterns)) {
        globPatterns.forEach(function(globPattern) {
            output = _.union(output, _this.getGlobbedFiles(globPattern, removeRoot));
        });
    } else if (_.isString(globPatterns)) {
        if (urlRegex.test(globPatterns)) {
            output.push(globPatterns);
        } else {
            var files = glob.sync(globPatterns);
            if (removeRoot) {
                files = files.map(function(file) {
                    return file.replace(removeRoot, '');
                });
            }
            output = _.union(output, files);
        }
    }

    return output;
};

module.exports.getJavaScriptAssets = function() {
    return this.getGlobbedFiles(this.assets.lib.js.concat(this.assets.js, this.assets.lib.customJs), '');
};

module.exports.getModulesJavaScriptAssets = function() {
    var output = [];
    var _this = this;

    var jsModules = _this.getGlobbedFiles(this.assets.jsModules, 'modules/');
    jsModules = _.map(jsModules, function(item) {
        return 'modules/' + item;
    });

    var jsDirectives = _this.getGlobbedFiles(_this.assets.jsDirectives, 'directives/');
    jsDirectives = _.map(jsDirectives, function(item) {
        return 'directives/' + item;
    });

    var jsServices = _this.getGlobbedFiles(_this.assets.jsServices, 'services/');
    jsServices = _.map(jsServices, function(item) {
        return 'services/' + item;
    });

    var jsCustomModules = [];
    var jsCustomDirectives = [];
    var jsCustomServices = [];

    _.forEach(activeProfiles, function(profile) {
        var jsProfileModuleDirs = _.map(_this.assets.jsCustomModules, function(dir) {
            return profile + dir;
        });
        var customModulesFiles = _this.getGlobbedFiles(jsProfileModuleDirs, profile + '_modules/');
        jsModules = _.difference(jsModules, customModulesFiles);

        var profileModulesFiles = _.map(customModulesFiles, function(item) {
            return profile + '_modules/' + item;
        });
        jsCustomModules.concat(profileModulesFiles);

        var jsProfileDirectiveDirs = _.map(_this.assets.jsCustomDirectives, function(dir) {
            return profile + dir;
        });
        var customDirectivesFiles = _this.getGlobbedFiles(jsProfileDirectiveDirs, profile + '_directives/');
        jsDirectives = _.difference(jsDirectives, customDirectivesFiles);

        var profileDirectivesFiles = _.map(customDirectivesFiles, function(item) {
            return profile + '_directives/' + item;
        });
        jsCustomDirectives.concat(profileDirectivesFiles);

        var jsProfileServiceDirs = _.map(_this.assets.jsCustomServices, function(dir) {
            return profile + dir;
        });
        var customServicesFiles = _this.getGlobbedFiles(jsProfileServiceDirs, profile + '_services/');
        jsServices = _.difference(jsServices, customServicesFiles);

        var profileServicesFiles = _.map(customServicesFiles, function(item) {
            return profile + '_services/' + item;
        });
        jsCustomServices.concat(profileServicesFiles);
    });

    output = output.concat(jsModules);
    output = output.concat(jsCustomModules);
    output = output.concat(jsDirectives);
    output = output.concat(jsCustomDirectives);
    output = output.concat(jsServices);
    output = output.concat(jsCustomServices);
    return output;
};

module.exports.getCSSAssets = function() {
    var _this = this;
    var cssResources = _this.assets.lib.css.concat(_this.assets.css);
    _.forEach(activeProfiles, function(profile) {
        var customCssResources = _.map(_this.assets.jsCustomCss, function(item) {
            return profile + item;
        });
        cssResources.concat(customCssResources);
    });
    return this.getGlobbedFiles(cssResources, '');
};
