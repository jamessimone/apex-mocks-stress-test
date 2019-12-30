require("dotenv").config();

var gulp = require("gulp");
var zip = require("gulp-zip");
var forceDeploy = require("gulp-jsforce-deploy");
var debug = require("gulp-debug");
var del = require("del");

const clean = () => del("./tmp/");

gulp.task("default", done => {
  gulp.series(clean, moveSrcFiles, build, clean)(done);
});

const shouldRunTests = () => (process.env.RUN_TESTS || "").match(/^true/i);

const build = () => {
  return gulp
    .src("./tmp/**", { base: "./tmp/" })
    .pipe(debug({ title: "Zipping", showFiles: false }))
    .pipe(zip("deploy.zip"))
    .pipe(
      forceDeploy({
        username: process.env.USER_NAME,
        password: process.env.PASSWORD + process.env.SECURITY_TOKEN,
        loginUrl: process.env.INSTANCE,
        checkOnly: false,
        singlePackage: true,
        ignoreWarnings: true,
        testLevel: shouldRunTests() ? "RunLocalTests" : "NoTestRun",
        rollbackOnError: true,
        verbose: false,
        pollTimeout: 1000000
      })
    )
    .on("error", () => {
      gulp.start(clean);
    });
};

const moveSrcFiles = () => {
  return gulp
    .src("./src/**/*")
    .pipe(debug({ title: "Moving", showFiles: false }))
    .pipe(gulp.dest("./tmp/"));
};
