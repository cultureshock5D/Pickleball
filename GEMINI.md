# Global Agent Guardrails & Non-Destructive Protection Rules

This document establishes the mandatory security and safety guardrails across all agent operations within this repository.

---

## 🛡️ Non-Destructive Operations & External Protection Rules

### 1. Zero File Modifications or Deletions Outside Workspace
* **Strict Workspace Containment**: The agent is strictly forbidden from writing, modifying, creating, or deleting files outside the project root directory (`C:\Users\koi\Documents\repositories\Pickleball`).
* **No External Destructive Shell Commands**: NEVER execute commands like `Remove-Item`, `del`, `rmdir`, `rm -rf`, or `git clean` targeting external paths (such as `C:\`, `C:\flutter`, `C:\Users\koi`, `~`, or user home directories).
* **External Tools & SDKs are Read-Only**: Third-party tools such as Flutter SDK (`C:\flutter`), Dart SDK, Java JDK, and Android SDK must remain strictly read-only.

### 2. Zero Whole-Folder Deletions
* Core directories (`lib/`, `test/`, `android/`, `ios/`, `assets/`) must NEVER be wiped or deleted as a whole.
* Single-file surgical modifications must always be used instead of batch folder operations.

### 3. Protected Reference Immutability
* Files in `referenceonly/` (e.g., `layout.tsx`, `Project.sql`) are strictly **READ-ONLY** reference materials. Never delete, mutate, or rename them.
