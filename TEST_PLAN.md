# CleanMD Test Plan

## P0 (must-have)

- `ScrollSyncController` forwards scroll only when linked.
- `ScrollSyncController` suppresses immediate feedback loop between panes.
- Preview renderer escapes raw HTML (no executable inline handlers/script tags).
- Preview renderer strips unsafe URL schemes (`javascript:`, `data:`).

## P1 (next)

- Color panel visibility is window-local while palette edits are app-global.
- Clicking preview links opens external browser/mail client and does not navigate in-place.
- Markdown open/save round-trip preserves UTF-8 content exactly.

## P2 (performance confidence)

- Large markdown render benchmark (10k+ lines) stays under target latency.
- Typing benchmark confirms debounce path does not re-render unchanged text.
- Math-disabled documents skip KaTeX work and remain responsive.
