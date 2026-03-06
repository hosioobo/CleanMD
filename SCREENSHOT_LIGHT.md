# CleanMD Light Mode

CleanMD keeps writing and preview side by side, with a layout that stays readable at a glance.

## Text

This line shows **bold**, *italic*, ~~strikethrough~~, `inline code`, and a [project link](https://github.com/hosioobo/CleanMD).

> Native, fast, and clean. The editor stays simple while the preview remains expressive.

## Lists

- Live preview
- Offline bundled assets
- Syntax highlighting
- Math rendering

1. Open a Markdown file
2. Type in the editor
3. Review the live preview

- [x] Split editor and preview
- [x] Markdown file support
- [ ] Notarized release

## Code

```swift
import SwiftUI

struct DemoCard: View {
    var body: some View {
        Text("CleanMD")
            .font(.title2.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}
```

```javascript
const renderPreview = (markdown) => {
  console.log(`Rendering ${markdown.length} characters`);
};
```

## Table

| Feature | Status | Note |
|---|---:|---|
| Preview | Yes | Live while typing |
| Code highlight | Yes | Offline bundled |
| Math | Yes | KaTeX |

Use this document for the bright, text-heavy README screenshot.
