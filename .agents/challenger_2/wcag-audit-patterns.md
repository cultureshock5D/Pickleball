# WCAG Audit Patterns

Comprehensive guide to auditing web content and mobile applications against WCAG 2.2 guidelines with actionable remediation strategies.

## Touch Targets (WCAG 2.2 SC 2.5.8 & SC 2.5.5)
- WCAG 2.5.8 Target Size (Minimum) (Level AA): Touch target size is at least 24 by 24 CSS pixels / dp, or spacing exception applies.
- WCAG 2.5.5 Target Size (Enhanced) (Level AAA) & Material/iOS Guidelines: Minimum 48x48dp interactive touch target size.
- Ensure all interactive widgets (buttons, icon buttons, chips, tabs, list tiles, switches) have effective touch target dimensions of >= 48x48dp.
- In Flutter, verify via RenderBox size (`tester.getSize(finder)`), hit test behavior, or `kMinInteractiveDimension` (48.0).

## Screen Reader Accessibility & Semantics Tree (WCAG 4.1.2 & 1.3.1)
- WCAG 4.1.2 Name, Role, Value: Every interactive element must expose its accessible name, role (e.g. button, tab, checkbox), and state (e.g. selected, expanded).
- In Flutter, inspect Semantics tree using `tester.getSemantics(finder)`.
- Verify `Semantics(button: true, label: ..., selected: ...)` or semantic properties on gestures and custom cards.
- Non-text elements (icons, charts, indicators) must have text alternatives or be marked as decorative (`excludeFromSemantics: true`).
