# CleanMD Demo Document

CleanMD is a native macOS Markdown editor built for a fast, clean writing workflow.

---

## Text Formatting

This paragraph includes **bold text**, *italic text*, ***bold italic text***, ~~strikethrough~~, and `inline code`.

You can also include [links](https://github.com/hosioobo/CleanMD) and plain text that reads naturally in the live preview.

### Blockquote

> Clean writing tools should stay out of the way.
>
> CleanMD keeps the editing surface simple while still supporting rich Markdown preview features.

## Lists

### Unordered List

- Fast native editing
- Live preview
- Syntax highlighting
- Math rendering
- Optional synchronized scrolling

### Ordered List

1. Open a Markdown file
2. Edit in the left pane
3. Watch the preview update on the right
4. Export screenshots for the README

### Task List

- [x] Split editor and preview
- [x] Offline bundled rendering
- [x] Markdown file support
- [ ] Notarized public release

## Code Blocks

```swift
import SwiftUI

struct DemoView: View {
    var body: some View {
        Text("CleanMD")
            .font(.title)
            .padding()
    }
}
```

```javascript
function renderPreview(markdown) {
  console.log("Rendering:", markdown.length);
}
```

## Table

| Feature | Supported | Notes |
|---|---:|---|
| Live preview | Yes | Updates while typing |
| Math rendering | Yes | Powered by KaTeX |
| Code highlighting | Yes | Bundled offline assets |
| Notarization | Not yet | Planned later |

## Math

Inline math works like $E = mc^2$.

Display math:

$$
\int_{0}^{1} x^2 \, dx = \frac{1}{3}
$$

$$
\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}
$$

## Mixed Content

### Nested Structure

1. Writing
   - Notes
   - Drafts
   - Documentation
2. Review
   - Preview styling
   - Link rendering
   - Code formatting

### Horizontal Rule

---

### Final Note

Use this file to capture:

- the full split-view layout
- code highlighting
- table rendering
- math rendering
- typography and spacing
