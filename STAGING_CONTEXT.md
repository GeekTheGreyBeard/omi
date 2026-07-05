# Omi Frontend Rebuild - Staging

Fresh Omi front-end staging clone for Splat-I owned preproduction work.

- Upstream: `https://github.com/BasedHardware/Omi.git`
- Commit: `2e01508bc4bba27335878809c3e0a8e0bf512208`
- Scope: Android app and web app only
- Excluded: desktop apps and glasses
- Backend target: `http://127.0.0.1:18080`
- Source path: canonical local Projects root, `omiFrontendRebuild-staging`
- Splat-I integration docs: maintained in the private Splat-I integration project notes

This repository now lives directly under the canonical Projects root. Track Splat-I-specific notes, decisions, and release evidence in this wrapper and in the Splat-I integration docs.

## Local Build Notes

Android uses `adb reverse tcp:18080 tcp:18080` so the attached debug device can reach the local backend at `http://127.0.0.1:18080/`.

Local placeholder Firebase files are used only for staging buildability because the public clone does not include real Firebase project files. Crashlytics mapping upload is disabled only when the Gradle property `localBuildDisableCrashlyticsUpload=true` is supplied.

## Evidence

- Android APK: private build artifact retained outside the public repo
- Web build ID: private build artifact retained outside the public repo
- RaBobster launch logcat: private validation artifact retained outside the public repo
