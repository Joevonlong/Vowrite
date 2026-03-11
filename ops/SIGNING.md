# Code Signing Setup

## Problem

Without a consistent signing identity, macOS resets permissions (microphone, accessibility) every time you install a new Vowrite build.

## Solution: Self-Signed Certificate (one-time setup)

Create a "Vowrite Developer" certificate in Keychain Access. This gives every build the same identity, so permissions persist across updates.

### Steps

1. Open **Keychain Access** (`⌘ Space` → "Keychain Access")
2. Menu: **Keychain Access → Certificate Assistant → Create a Certificate...**
3. Fill in:
   - **Name:** `Vowrite Developer`
   - **Identity Type:** Self-Signed Root
   - **Certificate Type:** Code Signing
4. Click **Create**
5. If prompted about trust, click **Always Trust**

### Verify

```bash
security find-identity -v -p codesigning
# Should show: "Vowrite Developer"
```

After setup, `release.sh` will automatically use this certificate instead of ad-hoc signing.

## How It Works

| Signing Method | Permissions Persist? | First Launch |
|---------------|---------------------|-------------|
| Ad-hoc (`-`) | ❌ Reset each build | Right-click → Open |
| Self-signed (`Vowrite Developer`) | ✅ Persist | Right-click → Open (first time only) |
| Apple Developer ID + Notarization | ✅ Persist | Double-click (no warning) |

## Future: Apple Developer Program

For public distribution without warnings: Apple Developer Program ($99/year) → Developer ID certificate + Notarization.
