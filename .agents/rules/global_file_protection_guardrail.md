---
description: Global safety guardrail preventing accidental deletion, removal, or modification of files outside the project workspace root.
globs: ["**/*"]
alwaysApply: true
---

# Global Non-Destructive File Protection Guardrail

## 🛡️ Strict Boundaries & Prohibited Operations

1. **Workspace Containment**:
   - **NEVER** create, edit, overwrite, or delete files or directories outside the designated workspace root (`C:\Users\koi\Documents\repositories\Pickleball`).
   - **NEVER** run destructive shell commands targeting parent, sibling, system, or home directories (e.g., `Remove-Item`, `del`, `rmdir`, `rm -rf`, `git clean -f` targeting `..`, `C:\`, `C:\Users\koi`, `C:\flutter`, `~`, or user profile directories).

2. **Zero Destructive External Actions**:
   - Prohibit recursive deletion or batch removal commands (`del /s /q`, `rm -rf`, `Remove-Item -Recurse -Force`) on external or root paths.
   - Any temporary scripts, scratchpads, or logs MUST strictly live inside the designated sandbox artifacts or `.agents/` scratch directories.

3. **Read-Only Third-Party SDKs & System Tools**:
   - Flutter SDK (`C:\flutter`), Dart SDK, Android SDK, and global developer tools MUST remain strictly **READ-ONLY** and NEVER be mutated, uninstalled, or deleted.

4. **Preservation of Reference and Core Directories**:
   - Workspace directories like `referenceonly/`, `lib/`, `test/`, `android/`, and `ios/` must never be wiped as a whole.
   - All modifications must be targeted, surgical, and additive/refactive on single files.
