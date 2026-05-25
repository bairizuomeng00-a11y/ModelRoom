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
                case let .heading(level, text):
                    HeadingBlockView(level: level, text: text)
                case let .paragraph(text):
                    ParagraphBlockView(text: text)
                case let .list(ordered, items):
                    MarkdownListView(ordered: ordered, items: items)
                case let .quote(text):
                    QuoteBlockView(text: text)
                case .divider:
                    DividerBlockView()
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
    case heading(level: Int, text: String)
    case paragraph(String)
    case list(ordered: Bool, items: [String])
    case quote(String)
    case divider
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

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isDivider(trimmed) {
                flushParagraph()
                blocks.append(.divider)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                let parsed = parseQuote(lines: lines, startIndex: index)
                blocks.append(.quote(parsed.text))
                index = parsed.nextIndex
                continue
            }

            if unorderedListItem(in: line) != nil {
                flushParagraph()
                let parsed = parseList(lines: lines, startIndex: index, ordered: false)
                blocks.append(.list(ordered: false, items: parsed.items))
                index = parsed.nextIndex
                continue
            }

            if orderedListItem(in: line) != nil {
                flushParagraph()
                let parsed = parseList(lines: lines, startIndex: index, ordered: true)
                blocks.append(.list(ordered: true, items: parsed.items))
                index = parsed.nextIndex
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

    private static func parseHeading(_ trimmed: String) -> (level: Int, text: String)? {
        let level = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(level),
              trimmed.dropFirst(level).first == " " else {
            return nil
        }

        let text = String(trimmed.dropFirst(level))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : (level, text)
    }

    private static func isDivider(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let characters = Set(trimmed)
        return characters == ["-"] || characters == ["*"] || characters == ["_"]
    }

    private static func parseQuote(lines: [String], startIndex: Int) -> (text: String, nextIndex: Int) {
        var quoteLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(">") else { break }
            let stripped = String(trimmed.dropFirst())
                .trimmingCharacters(in: .whitespaces)
            quoteLines.append(stripped)
            index += 1
        }

        return (quoteLines.joined(separator: "\n"), index)
    }

    private static func parseList(lines: [String], startIndex: Int, ordered: Bool) -> (items: [String], nextIndex: Int) {
        var items: [String] = []
        var index = startIndex

        while index < lines.count {
            let item = ordered ? orderedListItem(in: lines[index]) : unorderedListItem(in: lines[index])
            guard let item else { break }
            items.append(item)
            index += 1
        }

        return (items, index)
    }

    private static func unorderedListItem(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return nil }
        let markers = ["- ", "* ", "+ "]
        guard let marker = markers.first(where: { trimmed.hasPrefix($0) }) else { return nil }
        let item = String(trimmed.dropFirst(marker.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return item.isEmpty ? nil : item
    }

    private static func orderedListItem(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var cursor = trimmed.startIndex
        var hasDigit = false

        while cursor < trimmed.endIndex, trimmed[cursor].isNumber {
            hasDigit = true
            cursor = trimmed.index(after: cursor)
        }

        guard hasDigit,
              cursor < trimmed.endIndex,
              trimmed[cursor] == "." || trimmed[cursor] == ")" else {
            return nil
        }

        cursor = trimmed.index(after: cursor)
        guard cursor < trimmed.endIndex, trimmed[cursor].isWhitespace else { return nil }

        let item = String(trimmed[cursor...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return item.isEmpty ? nil : item
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
        MarkdownInlineText(text)
            .font(.system(size: 15.5))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeadingBlockView: View {
    var level: Int
    var text: String

    var body: some View {
        MarkdownInlineText(text)
            .font(.system(size: fontSize, weight: .semibold))
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 4 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fontSize: CGFloat {
        switch level {
        case 1: 22
        case 2: 19
        case 3: 17
        default: 15.8
        }
    }
}

private struct MarkdownListView: View {
    var ordered: Bool
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: ordered ? 28 : 18, alignment: .trailing)

                    MarkdownInlineText(item)
                        .font(.system(size: 15.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QuoteBlockView: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.accentColor.opacity(0.38))
                .frame(width: 3)

            MarkdownInlineText(text)
                .font(.system(size: 15.5))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DividerBlockView: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(height: 1)
            .padding(.vertical, 4)
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
    @State private var selectedCell: TableCellDetail?

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                TableRowView(cells: headers, headers: headers, isHeader: true, rowIndex: nil) { detail in
                    selectedCell = detail
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    TableRowView(cells: row, headers: headers, isHeader: false, rowIndex: rowIndex) { detail in
                        selectedCell = detail
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
        }
        .popover(item: $selectedCell, arrowEdge: .bottom) { detail in
            TableCellDetailView(detail: detail)
        }
    }
}

private struct TableCellDetail: Identifiable {
    let id = UUID()
    var title: String
    var content: String
}

private struct TableRowView: View {
    var cells: [String]
    var headers: [String]
    var isHeader: Bool
    var rowIndex: Int?
    var onSelect: (TableCellDetail) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { columnIndex, cell in
                Button {
                    onSelect(detail(for: cell, columnIndex: columnIndex))
                } label: {
                    MarkdownInlineText(softWrapped(cell))
                        .font(isHeader ? .system(size: 15.5, weight: .semibold) : .system(size: 15.5))
                        .lineLimit(isHeader ? 2 : 3)
                        .truncationMode(.tail)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(width: 190, height: isHeader ? 48 : 74, alignment: .topLeading)
                        .background(isHeader ? Color.primary.opacity(0.07) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
                        .border(Color.primary.opacity(0.08), width: 0.5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(cell)
            }
        }
    }

    private func detail(for content: String, columnIndex: Int) -> TableCellDetail {
        let fallbackTitle = rowIndex.map { "Row \($0 + 1), Column \(columnIndex + 1)" } ?? "Header \(columnIndex + 1)"
        let title = headers.indices.contains(columnIndex) && !headers[columnIndex].isEmpty
            ? headers[columnIndex]
            : fallbackTitle
        return TableCellDetail(title: title, content: content)
    }
}

private struct TableCellDetailView: View {
    var detail: TableCellDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail.title)
                .font(.headline)
                .lineLimit(2)

            ScrollView {
                MarkdownInlineText(softWrapped(detail.content))
                    .font(.system(size: 15.5))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            }
            .frame(width: 420, height: 240)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
        }
        .padding(14)
        .frame(width: 450)
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

private func MarkdownInlineText(_ text: String) -> Text {
    var result = Text("")
    var remaining = text[...]

    while let range = nextInlineMathRange(in: remaining) {
        let before = String(remaining[..<range.lowerBound])
        if !before.isEmpty {
            result = result + markdownText(before)
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
        result = result + markdownText(tail)
    }
    return result
}

private func markdownText(_ text: String) -> Text {
    do {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        let attributed = try AttributedString(markdown: text, options: options)
        return Text(attributed)
    } catch {
        return Text(text)
    }
}

private func softWrapped(_ text: String) -> String {
    var result = ""
    var runLength = 0

    for character in text {
        if character.isWhitespace {
            runLength = 0
            result.append(character)
            continue
        }

        if runLength > 0 && runLength.isMultiple(of: 34) {
            result.append("\u{200B}")
        }
        result.append(character)
        runLength += 1
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
