import Foundation

enum MarkdownTableNormalizer {
    static func normalize(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return text }

        var normalized: [String] = []
        var index = 0

        while index < lines.count {
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
