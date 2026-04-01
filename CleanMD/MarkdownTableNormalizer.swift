import Foundation

enum MarkdownTableNormalizer {
    static func normalize(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return text }

        var normalized: [String] = []
        var index = 0

        while index < lines.count {
            if isIndentedCodeBlockLine(lines[index]) {
                repeat {
                    let line = lines[index]
                    normalized.append(line)
                    index += 1
                } while index < lines.count && (isIndentedCodeBlockLine(lines[index]) || lines[index].trimmingCharacters(in: .whitespaces).isEmpty)
                continue
            }

            if let fence = fencedCodeBlockStart(for: lines[index]) {
                repeat {
                    let line = lines[index]
                    normalized.append(line)
                    index += 1
                    if isClosingFence(line, matching: fence) {
                        break
                    }
                } while index < lines.count
                continue
            }

            if let htmlBlock = htmlBlockStart(for: lines[index]) {
                repeat {
                    let line = lines[index]
                    normalized.append(line)
                    index += 1
                    if isClosingHTMLBlock(line, tagName: htmlBlock) {
                        break
                    }
                } while index < lines.count
                continue
            }

            guard index + 1 < lines.count else {
                normalized.append(lines[index])
                break
            }

            let headerLine = lines[index]
            let separatorLine = lines[index + 1]
            let expectedColumnCount = splitTableCells(headerLine).count

            guard expectedColumnCount >= 2,
                  isTableSeparatorLine(separatorLine, expectedColumnCount: expectedColumnCount) else {
                normalized.append(headerLine)
                index += 1
                continue
            }

            normalized.append(headerLine)
            normalized.append(separatorLine)
            index += 2

            var pendingRow: String?

            while index < lines.count {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.isEmpty {
                    if let currentPendingRow = pendingRow {
                        normalized.append(currentPendingRow)
                        pendingRow = nil
                    }
                    break
                }

                if let currentPendingRow = pendingRow {
                    if splitTableCells(currentPendingRow).count < expectedColumnCount {
                        self.pendingRowMerge(&pendingRow, with: line)
                        index += 1
                        continue
                    }

                    normalized.append(currentPendingRow)

                    guard hasUnescapedPipe(line) else {
                        pendingRow = nil
                        break
                    }

                    self.pendingRowSet(&pendingRow, to: line)
                    index += 1
                    continue
                }

                guard hasUnescapedPipe(line) else {
                    break
                }

                self.pendingRowSet(&pendingRow, to: line)
                index += 1
            }

            if let pendingRow {
                normalized.append(pendingRow)
            }
        }

        return normalized.joined(separator: "\n")
    }

    private static func splitTableCells(_ line: String) -> [String] {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard !trimmedLine.isEmpty else { return [] }

        var working = trimmedLine
        if working.first == "|" { working.removeFirst() }
        if working.last == "|" { working.removeLast() }

        var cells: [String] = []
        var current = ""
        var isEscaped = false

        for character in working {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                current.append(character)
                isEscaped = true
                continue
            }

            if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current.removeAll(keepingCapacity: true)
                continue
            }

            current.append(character)
        }

        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private struct Fence {
        let marker: Character
        let length: Int
    }

    private static func isIndentedCodeBlockLine(_ line: String) -> Bool {
        if line.hasPrefix("\t") { return true }

        var spaceCount = 0
        for character in line {
            if character == " " {
                spaceCount += 1
                if spaceCount >= 4 { return true }
                continue
            }
            break
        }
        return false
    }

    private static func fencedCodeBlockStart(for line: String) -> Fence? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let marker = trimmed.first, marker == "`" || marker == "~" else { return nil }

        let fenceLength = trimmed.prefix { $0 == marker }.count
        guard fenceLength >= 3 else { return nil }
        return Fence(marker: marker, length: fenceLength)
    }

    private static func isClosingFence(_ line: String, matching fence: Fence) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == fence.marker else { return false }

        let fenceLength = trimmed.prefix { $0 == fence.marker }.count
        guard fenceLength >= fence.length else { return false }

        let remainder = trimmed.dropFirst(fenceLength)
        return remainder.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func htmlBlockStart(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "<",
              !trimmed.hasPrefix("</"),
              !trimmed.hasPrefix("<!--"),
              let match = trimmed.range(of: #"^<([A-Za-z][A-Za-z0-9:-]*)\b[^>]*?>$"#, options: .regularExpression) else {
            return nil
        }

        let token = String(trimmed[match])
        guard !token.hasSuffix("/>"),
              let tagMatch = token.range(of: #"^<([A-Za-z][A-Za-z0-9:-]*)"#, options: .regularExpression) else {
            return nil
        }

        return String(token[tagMatch]).dropFirst().lowercased()
    }

    private static func isClosingHTMLBlock(_ line: String, tagName: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "</\(tagName)>"
    }

    private static func isTableSeparatorLine(_ line: String, expectedColumnCount: Int) -> Bool {
        let cells = splitTableCells(line)
        guard cells.count == expectedColumnCount else { return false }

        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            return trimmed.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil
        }
    }

    private static func hasUnescapedPipe(_ line: String) -> Bool {
        var isEscaped = false

        for character in line {
            if isEscaped {
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if character == "|" {
                return true
            }
        }

        return false
    }

    private static func pendingRowMerge(_ pendingRow: inout String?, with line: String) {
        guard let current = pendingRow else {
            pendingRow = line
            return
        }

        let separator = current.last.map(\.isWhitespace) == true ? "" : " "
        pendingRow = current + separator + line.trimmingCharacters(in: .whitespaces)
    }

    private static func pendingRowSet(_ pendingRow: inout String?, to line: String) {
        pendingRow = line
    }
}
