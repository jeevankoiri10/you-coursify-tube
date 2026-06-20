# iOS / App Store publishing & automation

The release workflow ([`.github/workflows/release.yml`](.github/workflows/release.yml))
has an `ios` job that, on each `v*` tag, builds a signed IPA on a macOS runner and
uploads it to **TestFlight**.

It is **off by default**. It only runs when the repository variable
`IOS_RELEASE_ENABLED` is set to `true`, and it needs four secrets. Until then,
tagging still produces the Android release and GitHub Release as usual.

> ⚠️ iOS cannot be built on Windows or Linux — it requires macOS + Xcode. That is
> why this runs on GitHub's `macos-latest` runners. There is no sideload-able
> equivalent of the Android APK; Apple distribution always requires signing and a
> paid Apple Developer account.

---

## One-time setup

### 1. Apple Developer Program
- Enroll at <https://developer.apple.com/programs/> (**$99/year**).

### 2. Register the app
- In [App Store Connect](https://appstoreconnect.apple.com): **Apps → +** → new app.
- Bundle ID is **`com.youcoursifytube.app`** (matches Android; set on the `Runner`
  target). Register this Bundle ID under **Certificates, Identifiers & Profiles**
  first if needed.

### 3. Create an App Store Connect API key
- App Store Connect → **Users and Access → Integrations → App Store Connect API**.
- Generate a key with the **App Manager** role. Note the **Key ID** and **Issuer ID**
  and download the **`.p8`** file (downloadable only once).

### 4. Find your Team ID
- <https://developer.apple.com/account> → **Membership** → Team ID (10 chars).

### 5. Add GitHub secrets and the enable flag
```bash
gh secret set APPSTORE_API_KEY_ID      # the Key ID
gh secret set APPSTORE_API_ISSUER_ID   # the Issuer ID
gh secret set APPLE_TEAM_ID            # the Team ID
gh secret set APPSTORE_API_PRIVATE_KEY < AuthKey_XXXXXXXXXX.p8   # the .p8 contents

# turn the iOS job on
gh variable set IOS_RELEASE_ENABLED --body true
```

The next `v*` tag will build and upload to TestFlight automatically.

---

## First-run expectations
iOS CI signing is finicky and cannot be tested from this (Windows) repo. The first
real run may need small adjustments — most commonly:
- enabling **automatic signing** for the `Runner` target in Xcode and committing it,
- making sure the Bundle ID is registered before the first archive,
- bumping the build number (`pubspec.yaml` `+N`) for each TestFlight upload, since
  App Store Connect rejects duplicate build numbers.

If you'd rather not manage this by hand, **Fastlane** (`match` + `pilot`) or
**Codemagic** are common alternatives for Flutter iOS delivery.
