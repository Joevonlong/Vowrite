# Contributing to Vowrite

## Branch Strategy

```
main              ← Default branch. Development + tagged releases.
  └─ feature/xxx  ← Feature branches for larger changes.
```

## Workflow

### Small Changes (bug fix, docs, config)

```bash
git checkout main
git pull origin main
# make changes...
git commit -m "fix: short description"
git push origin main
```

### Larger Features

```bash
git checkout main && git pull
git checkout -b feature/my-feature
# develop and commit freely...
git checkout main
git merge --squash feature/my-feature
git commit -m "feat: short description of what this adds"
git push origin main
git branch -d feature/my-feature
```

**Always squash merge** feature branches. One feature = one commit on main.

### Release

When main is ready for a versioned release:

```bash
ops/scripts/release.sh v0.1.6.0 "Brief release summary"
git push origin main --tags
gh release create v0.1.6.0 releases/Vowrite-v0.1.6.0.dmg --title "Vowrite v0.1.6.0 — Summary"
```

The release script handles: changelog → version bump → build → commit → tag.

## Commit Message Format

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `chore:` — Build, config, tooling
- `refactor:` — Code change that neither fixes a bug nor adds a feature
- `security:` — Security fix

See [ops/VERSIONING.md](ops/VERSIONING.md) for the full convention.

## Rules

- **Squash merge** feature branches — keep history clean
- **Tag every release** with 4-segment version (`v0.1.6.0`)
- **Delete feature branches** after merge
- **All commits in English**
