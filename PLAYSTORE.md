# Play Store publishing & automation

Releases are automated by [`.github/workflows/release.yml`](.github/workflows/release.yml).
Pushing a `v*` tag builds a signed AAB and **uploads it to the Google Play
*Internal testing* track** — once the one-time setup below is done.

```bash
# cut a release (bump the version in pubspec.yaml first)
git tag v1.1.0
git push origin v1.1.0
```

The Play upload step is **inert until you add the `PLAY_SERVICE_ACCOUNT_JSON`
secret**, so tagging still produces a GitHub Release before Play is configured.

---

## One-time setup (do these once, in order)

### 1. Google Play Developer account
- Register at <https://play.google.com/console> (one-time **$25** fee).
- Complete identity verification (can take 1–2 days).

### 2. Create the app
- In the Play Console: **Create app**.
- Package name must be exactly **`com.youcoursifytube.app`** (matches the build).

### 3. Upload the FIRST build manually ⚠️
Google's API refuses uploads until at least one build exists for the package.
So the **first** AAB must go through the console by hand:
- Build it: `flutter build appbundle --release`
  (or download `YouCoursifyTube-vX.Y.Z.aab` from a GitHub Release).
- In the console: **Testing → Internal testing → Create new release**, upload the
  `.aab`, and roll it out. After this, the workflow handles every future upload.

### 4. Enable Play App Signing
- When prompted during the first release, **let Google manage the app signing key**.
- Your `upload-keystore.jks` (alias `upload`) is the **upload key** — already used by
  the build and stored in the repo secrets. Keep it backed up.

### 5. Create a service account for the API
- Play Console → **Setup → API access** → link or create a Google Cloud project.
- Create a **service account** in Google Cloud (IAM & Admin → Service Accounts),
  then create a **JSON key** for it and download the file.
- Back in Play Console → **API access → grant access** to that service account, with
  permission to **Release to testing tracks** (Releases → at least the Internal track).
- Accept/confirm the invitation.

### 6. Add the secret to GitHub
Store the downloaded JSON key as a repository secret:

```bash
gh secret set PLAY_SERVICE_ACCOUNT_JSON < path/to/service-account.json
```

That's it. The next `v*` tag will build, publish a GitHub Release, **and** push the
AAB to Internal testing automatically.

---

## Promote to production
The automation stops at Internal testing on purpose. When a build is verified:
- Play Console → **Testing → Internal testing → Promote release → Production**.

To automate production later, change `track: internal` to `track: production` in the
workflow (and consider `status: inProgress` with a staged `userFraction` rollout).

---

## Compliance note
This app uses `youtube_explode_dart` (scrapes YouTube metadata). Google Play reviews
for **YouTube ToS compliance**, and scraping is a common rejection reason. If review
flags it, switch metadata fetching to the official **YouTube Data API**. Sideloading
the APK from GitHub Releases is unaffected.
