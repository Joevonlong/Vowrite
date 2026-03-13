# Code Signing Setup

## Problem

Without a consistent signing identity, macOS resets permissions (microphone, accessibility) every time you install a new Vowrite build. This is because macOS TCC (Transparency, Consent, and Control) ties permission grants to the app's code signing identity.

## Solution: Self-Signed Certificate (one-time setup)

A dedicated signing keychain with a "Vowrite Developer" certificate gives every build the same identity, so permissions persist across updates.

### Current Setup (F-024)

The signing infrastructure uses a dedicated keychain at `~/Library/Keychains/vowrite-signing.keychain-db` with a self-signed "Vowrite Developer" certificate. Both `build.sh` and `release.sh` automatically use this keychain.

### How It Works

| Signing Method | Permissions Persist? | First Launch | Cost |
|---|---|---|---|
| Ad-hoc (`-`) | ❌ Reset each build | Right-click → Open | Free |
| **Self-signed (`Vowrite Developer`)** | **✅ Persist** | **Right-click → Open (first time only)** | **Free** |
| Apple Developer ID + Notarization | ✅ Persist | Double-click (no warning) | $99/year |

### Setup Steps (one-time, on build machine)

If the signing keychain doesn't exist yet, run these commands:

```bash
# 1. Generate key + cert
openssl req -x509 -newkey rsa:2048 \
    -keyout /tmp/vw.key -out /tmp/vw.crt \
    -days 3650 -nodes \
    -subj "/CN=Vowrite Developer" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"

# 2. Create p12 (use -legacy for OpenSSL 3.x)
openssl pkcs12 -export -out /tmp/vw.p12 \
    -inkey /tmp/vw.key -in /tmp/vw.crt \
    -passout pass:vw -name "Vowrite Developer" -legacy

# 3. Create dedicated signing keychain
security create-keychain -p "vowrite" ~/Library/Keychains/vowrite-signing.keychain-db

# 4. Add to keychain search list
EXISTING=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
security list-keychains -d user -s $EXISTING ~/Library/Keychains/vowrite-signing.keychain-db

# 5. Unlock + disable auto-lock
security unlock-keychain -p "vowrite" ~/Library/Keychains/vowrite-signing.keychain-db
security set-keychain-settings ~/Library/Keychains/vowrite-signing.keychain-db

# 6. Import identity
security import /tmp/vw.p12 -k ~/Library/Keychains/vowrite-signing.keychain-db \
    -P "vw" -T /usr/bin/codesign -T /usr/bin/security

# 7. Set partition list for codesign access
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "vowrite" \
    ~/Library/Keychains/vowrite-signing.keychain-db

# 8. Clean up temp files
rm -f /tmp/vw.key /tmp/vw.crt /tmp/vw.p12
```

### Verify

```bash
# Should show "Vowrite Developer" as authority:
codesign --force --sign "Vowrite Developer" \
    --keychain ~/Library/Keychains/vowrite-signing.keychain-db \
    /tmp/test_binary
codesign -dvv /tmp/test_binary 2>&1 | grep Authority
# → Authority=Vowrite Developer
```

### How build.sh / release.sh Use It

Both scripts automatically:
1. Check for `~/Library/Keychains/vowrite-signing.keychain-db`
2. Unlock the keychain
3. Sign with `--sign "Vowrite Developer" --keychain <path>`
4. Fall back to ad-hoc (`-`) if keychain not found

### User Impact

- **First install:** Users need to right-click → Open (Gatekeeper warning for unnotarized app)
- **Updates:** Permissions (microphone, accessibility) persist — no re-authorization needed
- **No action required from users** regarding certificates

## Future: Apple Developer Program

For "double-click to run" with zero warnings:

1. Enroll in Apple Developer Program ($99/year)
2. Download "Developer ID Application" certificate
3. Update release.sh to sign with Developer ID
4. Add notarization step: `xcrun notarytool submit` + `xcrun stapler staple`
5. Users get a completely seamless experience
