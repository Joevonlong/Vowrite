# Vowrite Operations Center (ops/)

This directory is the **management, maintenance, and release process directory** for the Vowrite project. It is not packaged into the software.

## Directory Structure

```
ops/
├── README.md              ← You are reading this file
├── PROCESS.md             ← Core process overview (Develop → Test → Release → Ops)
├── CHECKLIST_RELEASE.md   ← Pre-release checklist (required before every release)
├── CHECKLIST_SECURITY.md  ← Security cleanup checklist
├── VERSIONING.md          ← Version numbering and changelog standards
├── WEBSITE.md             ← Website planning and deployment
├── ROADMAP.md             ← Product roadmap
└── scripts/
    ├── release.sh         ← Automated release script
    ├── test.sh            ← Automated test script
    └── clean.sh           ← Build cleanup script
```

## Principles

1. **Before every release**, complete `CHECKLIST_RELEASE.md`
2. **Before every security-related change**, complete `CHECKLIST_SECURITY.md`
3. **Version numbers and changelogs** follow the standards in `VERSIONING.md`
4. **All scripts** are in `ops/scripts/`, not in the project root (`build.sh` is the exception — it's for development use)
