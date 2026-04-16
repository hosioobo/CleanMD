# CleanMD Demo Folder

CleanMD is for Markdown and adjacent plain-text files that already live in normal folders and repos.

## What this folder shows

- Markdown editing with rendered preview beside the source
- A neighboring YAML file in the same sidebar
- Code fences, tables, links, and math in one native window


## Quick checks

| Item | Why it matters |
| --- | --- |
| File list | Work from a normal folder instead of a vault |
| Code block | Verify formatting before commit or publish |
| Table | Catch alignment issues quickly |
| Math | Review technical notes without plugins |
| YAML | Keep config files close to docs |

## Code

```swift
struct DemoChecklist: View {
    let items = ["Open folder", "Edit Markdown", "Check preview"]
}
```

## Math

Inline math: \(E = mc^2\)

$$
\int_0^1 x^2 dx = \frac{1}{3}
$$

## Next file

Open `settings.yaml` in the same folder to show YAML rendering.
