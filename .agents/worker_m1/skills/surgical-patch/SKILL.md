---
name: surgical-patch
description: Fix bugs and small behavior changes at the narrowest responsible layer.
---

# surgical-patch local copy
- Trace symptom to responsible mechanism.
- Change narrowest layer that owns incorrect behavior.
- Preserve unrelated behavior and user changes.
- Avoid cleanup, renaming, and abstraction outside fix.
- Add only regression proof relevant to task.
