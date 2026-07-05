# Omi Frontend Rebuild - Staging

Fresh Omi front-end staging clone for Splat-I owned preproduction work.

- Upstream: `https://github.com/BasedHardware/Omi.git`
- Commit: `2e01508bc4bba27335878809c3e0a8e0bf512208`
- Scope: Android app and web app only
- Excluded: desktop apps and glasses
- Backend target: `http://127.0.0.1:18080`
- Source path: `/run/media/gtgb/GTGB-Files/Projects/RASiTechnical/splatI/omiFrontendRebuild-staging`
- Splat-I integration docs: `../omiIntegration-staging/docs/`
- Obsidian documentation: `OpenClaw/Projects/splatI/omiIntegration-staging/`

The nested `Omi/` directory is a local upstream worktree and is intentionally ignored by the Splat-I repository. Track Splat-I-specific notes, decisions, and release evidence in this wrapper and in `../omiIntegration-staging/docs/`.

## Local Build Notes

Android uses `adb reverse tcp:18080 tcp:18080` so the attached debug device can reach the local backend at `http://127.0.0.1:18080/`.

Local placeholder Firebase files are used only for staging buildability because the public clone does not include real Firebase project files. Crashlytics mapping upload is disabled only when the Gradle property `localBuildDisableCrashlyticsUpload=true` is supplied.

## Evidence

- Android APK: `/run/media/gtgb/GTGB-Files/OpenClaw/artifacts/omiFrontendRebuild/android/omi-dev-release.apk`
- Web build ID: `/run/media/gtgb/GTGB-Files/OpenClaw/artifacts/omiFrontendRebuild/web/BUILD_ID`
- RaBobster launch logcat: `/run/media/gtgb/GTGB-Files/OpenClaw/artifacts/omiFrontendRebuild/logs/rabobster-launch-logcat.txt`
