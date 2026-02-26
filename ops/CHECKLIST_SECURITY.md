# Security Cleanup Checklist

**Must be executed before each release or when security-related changes are involved.**

---

## API Key / Credentials

- [ ] API Keys are stored only in macOS Keychain, never written to files
- [ ] No hardcoded API Keys, Tokens, or passwords in code
- [ ] `.env` / `Secrets.swift` are in `.gitignore`
- [ ] No leaks in Git history (run: `git log -p | grep -i "sk-\|api.key\|secret\|token" | head -20`)

## Logging

- [ ] Debug logs like `NSLog("[TextInjector]...")` in release builds have been assessed
  - Do not output user voice content
  - Do not output API Keys
  - Do not output full request/response bodies
- [ ] User audio recording files are deleted promptly after use (`removeItem` in `WhisperService`)

## Network

- [ ] API requests use HTTPS
- [ ] No plaintext HTTP requests
- [ ] Requests do not carry unnecessary user information

## Permissions

- [ ] Only necessary permissions are requested (Microphone, Accessibility)
- [ ] Permission usage descriptions are accurate (`Usage Description` in `Info.plist`)
- [ ] Features degrade gracefully when permissions are not granted

## Clipboard

- [ ] Original clipboard content is restored after pasting
- [ ] Restoration delay is reasonable (currently 1.5 seconds)

## Data Storage

- [ ] SwiftData history records are stored locally, not uploaded
- [ ] No sensitive information stored in UserDefaults
- [ ] Temporary audio files are deleted after use

## Dependencies

- [ ] No third-party dependencies (currently pure Swift + system frameworks)
- [ ] If dependencies are introduced, their security must be reviewed

---

## Quick Check Commands

```bash
# Check for hardcoded keys in code
grep -rn "sk-\|api_key\|apiKey.*=.*\"" VowriteApp/ --include="*.swift" | grep -v "Keychain\|placeholder\|example"

# Check Git history
git log -p | grep -i "sk-" | head -10

# Check temp file cleanup
ls /tmp/vowrite_* 2>/dev/null && echo "WARNING: temp files exist" || echo "OK: no temp files"
```
