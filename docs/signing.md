# Android signing

The release APK is signed with a permanent Nimiro release key that never lives
in this repository.

## How CI signs

`.github/workflows/build-apk.yml` rebuilds `android/key.properties` on the
runner from four repository secrets:

| Secret | Meaning |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 nimiro-release.p12` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | key password (same as the keystore password) |

The keystore file is deleted at the end of the job (`if: always()`).

`android/app/build.gradle` uses `signingConfigs.release` whenever
`android/key.properties` exists; otherwise it falls back to the debug key so a
local `flutter run --release` still works. Never ship a debug-signed build.

## Certificate

```
subject : C=EG, O=Nimiro, OU=Mobile, CN=Nimiro
SHA-256 : 40:42:AE:93:77:CD:DE:DE:4A:7B:90:94:7D:C9:ED:D1:2D:98:FB:37:1A:19:25:8F:6E:53:97:EA:E9:1E:3E:6D
valid   : 2026-10-29 → 2056-10-21
```

Any APK whose signer digest differs from the above is not an official build.

## Local signed build

```bash
cat > android/key.properties <<EOF
storeType=PKCS12
storeFile=/absolute/path/to/nimiro-release.p12
storePassword=...
keyAlias=nimiro
keyPassword=...
EOF
flutter build apk --release --split-per-abi
```

`android/key.properties`, `*.jks`, `*.keystore` and `*.p12` are git-ignored.

## Rotating the key

1. Generate a new keystore (see the deployment notes kept outside this repo).
2. Update the four secrets with `gh secret set <NAME> -R nimirochat-a11y/-Nimro`.
3. Publish with a *new* applicationId or accept that existing installs must be
   uninstalled, because Android refuses an update signed by a different key.
