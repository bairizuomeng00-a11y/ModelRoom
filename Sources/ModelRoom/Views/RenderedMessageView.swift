import SwiftUI

struct RenderedMessageView: View {
    var content: String

    private var blocks: [RenderedMessageBlock] {
        RenderedMessageParser.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case let .paragraph(text):
                    ParagraphBlockView(text: text)
                case let .code(language, code):
                    CodeBlockView(language: language, code: code)
                case let .table(headers, rows):
                    MarkdownTableView(headers: headers, rows: rows)
                case let .math(formula):
                    MathBlockView(formula: formula)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum RenderedMessageBlock {
    case paragraph(String)
    case code(language: String?, code: String)
    case table(headers: [String], rows: [[String]])
    case math(String)
}

private enum RenderedMessageParser {
    static func parse(_ content: String) -> [RenderedMessageBlock] {
        let lines = content.components(separatedBy: .newlines)
        var blocks: [RenderedMessageBlock] = []
        var paragraph: [String] = []
        var index = 0

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraph.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                let fence = String(trimmed.prefix(3))
                let language = String(trimmed.dropFirst(3)).trimmedNil
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    let current = lines[index]
                    if current.trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                        index += 1
                        break
                    }
                    codeLines.append(current)
                    index += 1
                }
                blocks.append(.code(language: language, code: codeLines.joined(separator: "\n")))
                continue
            }

            if trimmed.hasPrefix("$$") {
                flushParagraph()
                let parsed = parseDollarMath(lines: lines, startIndex: index)
                blocks.append(.math(parsed.formula))
                index = parsed.nextIndex
                continue
            }

            if trimmed.hasPrefix("\\[") {
                flushParagraph()
                let parsed = parseBracketMath(lines: lines, startIndex: index)
                blocks.append(.math(parsed.formula))
                index = parsed.nextIndex
                continue
            }

            if isTableStart(lines: lines, index: index) {
                flushParagraph()
                let parsed = parseTable(lines: lines, startIndex: index)
                blocks.append(.table(headers: parsed.headers, rows: parsed.rows))
                index = parsed.nextIndex
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
            } else {
                paragraph.append(line)
            }
            index += 1
        }

        flushParagraph()
        return blocks.isEmpty ? [.paragraph(content)] : blocks
    }

    private static func parseDollarMath(lines: [String], startIndex: Int) -> (formula: String, nextIndex: Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        var formulaLines: [String] = []

        let firstBody = String(firstLine.dropFirst(2))
        if firstBody.hasSuffix("$$"), firstBody.count > 2 {
            return (String(firstBody.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines), startIndex + 1)
        }

        if !firstBody.isEmpty {
            formulaLines.append(firstBody)
        }

        var index = startIndex + 1
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("$$") {
                formulaLines.append(String(line.dropLast(2)))
                index += 1
                break
            }
            formulaLines.append(line)
            index += 1
        }

        return (formulaLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), index)
    }

    private static func parseBracketMath(lines: [String], startIndex: Int) -> (formula: String, nextIndex: Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        var formulaLines: [String] = []
        let firstBody = String(firstLine.dropFirst(2))

        if firstBody.hasSuffix("\\]"), firstBody.count > 2 {
            return (String(firstBody.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines), startIndex + 1)
        }

        if !firstBody.isEmpty {
            formulaLines.append(firstBody)
        }

        var index = startIndex + 1
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).hasSuffix("\\]") {
                formulaLines.append(String(line.dropLast(2)))
                index += 1
                break
            }
            formulaLines.append(line)
            index += 1
        }

        return (formulaLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), index)
    }

    private static func isTableStart(lines: [String], index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        return tableCells(in: lines[index]).count > 1 && isSeparatorRow(lines[index + 1])
    }

    private static func parseTable(lines: [String], startIndex: Int) -> (headers: [String], rows: [[String]], nextIndex: Int) {
        let headers = tableCells(in: lines[startIndex])
        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count {
            let cells = tableCells(in: lines[index])
            guard cells.count > 1 else { break }
            rows.append(normalizedRow(cells, count: headers.count))
            index += 1
        }

        return (headers, rows, index)
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        let cells = tableCells(in: line)
        guard cells.count > 1 else { return false }
        return cells.allSatisfy { cell in
            let text = cell.trimmingCharacters(in: .whitespaces)
            return text.contains("-") && text.allSatisfy { "-: ".contains($0) }
        }
    }

    private static func tableCells(in line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") {
            text.removeFirst()
        }
        if text.hasSuffix("|") {
            text.removeLast()
        }
        return text.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private static func normalizedRow(_ cells: [String], count: Int) -> [String] {
        if cells.count == count {
            return cells
        }
        if cells.count > count {
            return Array(cells.prefix(count))
        }
        return cells + Array(repeating: "", count: count - cells.count)
    }
}

private struct ParagraphBlockView: View {
    var text: String

    var body: some View {
        InlineMathText(text)
            .font(.system(size: 15.5))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CodeBlockView: View {
    var language: String?
    var code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                Text(language)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: 15.5, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .opacity(0.74)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct MarkdownTableView: View {
    var headers: [String]
    var rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                TableRowView(cells: headers, isHeader: true)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    TableRowView(cells: row, isHeader: false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
        }
    }
}

private struct TableRowView: View {
    var cells: [String]
    var isHeader: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(isHeader ? .system(size: 15.5, weight: .semibold) : .system(size: 15.5))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minWidth: 130, maxWidth: 260, alignment: .leading)
                    .background(isHeader ? Color.primary.opacity(0.07) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
                    .border(Color.primary.opacity(0.08), width: 0.5)
            }
        }
    }
}

private struct MathBlockView: View {
    var formula: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Image(systemName: "function")
                    .foregroundStyle(.secondary)
                Text(formula)
                    .font(.system(size: 15.5, design: .serif))
                    .italic()
                    .textSelection(.enabled)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
        }
    }
}

private func InlineMathText(_ text: String) -> Text {
    var result = Text("")
    var remaining = text[...]

    while let range = nextInlineMathRange(in: remaining) {
        let before = String(remaining[..<range.lowerBound])
        if !before.isEmpty {
            result = result + Text(before)
        }

        let rawMath = String(remaining[range])
        let math: String
        if rawMath.hasPrefix("\\("), rawMath.hasSuffix("\\)") {
            math = String(rawMath.dropFirst(2).dropLast(2))
        } else {
            math = rawMath.trimmingCharacters(in: CharacterSet(charactersIn: "$"))
        }
        result = result + Text(math)
            .font(.system(size: 15.5, design: .serif))
            .italic()
            .foregroundColor(.accentColor)

        remaining = remaining[range.upperBound...]
    }

    let tail = String(remaining)
    if !tail.isEmpty {
        result = result + Text(tail)
    }
    return result
}

private func nextInlineMathRange(in text: Substring) -> Range<String.Index>? {
    if let dollarStart = text.firstIndex(of: "$") {
        let afterStart = text.index(after: dollarStart)
        if afterStart < text.endIndex,
           let dollarEnd = text[afterStart...].firstIndex(of: "$"),
           dollarEnd > afterStart {
            return dollarStart..<text.index(after: dollarEnd)
        }
    }

    if let slashStart = text.range(of: #"\\\("#, options: .regularExpression),
       let slashEnd = text[slashStart.upperBound...].range(of: #"\\\)"#, options: .regularExpression) {
        return slashStart.lowerBound..<slashEnd.upperBound
    }

    return nil
}

private extension String {
    var trimmedNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
