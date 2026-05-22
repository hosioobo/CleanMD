# CleanMD Demo Folder

CleanMD is strongest when Markdown already lives in normal folders and repos.

## What this demo shows

- a real Markdown file in a normal folder
- split source and rendered preview
- links, code fences, tables, and math
- a neighboring YAML file in the same workspace

## Quick checks

| Item | Why it matters |
| --- | --- |
| Code block | Verify fenced formatting before commit |
| Table | Catch broken column alignment fast |
| Math | Review technical notes without plugins |
| YAML | Keep config files in the same workspace |

## Code

```swift
struct DemoChecklist: View {
    let items = ["Open folder", "Edit Markdown", "Check preview"]
}
```

## Math

Inline math: \(E = mc^2\)

Block math:

$$
\int_0^1 x^2 dx = \frac{1}{3}
$$

## Neighbor file

Open `settings.yaml` in the same folder to verify YAML preview and preserved indentation.
