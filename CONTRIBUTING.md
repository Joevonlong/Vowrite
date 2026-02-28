# Contributing to Vowrite

## Branch Strategy

```
main          ← Release-only. Each commit = a version release.
  └─ develop  ← Integration branch. All features merge here first.
       └─ feature/xxx  ← Individual feature branches.
```

## Workflow

### 1. Start a Feature

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-feature
```

### 2. Develop & Commit

Commit freely on your feature branch — commit messages don't need to be perfect here.

### 3. Merge to develop

```bash
git checkout develop
git merge --squash feature/my-feature
git commit -m "feat: short description of what this adds"
git push origin develop
git branch -d feature/my-feature
```

**Always squash merge** into develop. One feature = one commit.

### 4. Release to main

When develop is stable and ready for release:

```bash
git checkout main
git merge --squash develop
git commit -m "vX.Y: brief release summary"
git tag vX.Y
git push origin main --tags
```

Then create a GitHub Release with changelog.

## Commit Message Format

- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `chore:` — Build, config, tooling
- `refactor:` — Code change that neither fixes a bug nor adds a feature

## Rules

- **Never push directly to main** — always go through develop
- **Squash merge** everything — keep history clean
- **Tag every release** on main with 4-segment version (`v0.1.5.0`, `v0.1.6.0`, etc.)
- **Delete feature branches** after merge
