import SwiftUI

// MARK: - Detail Tab Picker

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case yaml = "YAML"
    var id: String { rawValue }
}

struct DetailTabPicker: View {
    @Binding var selection: DetailTab

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(DetailTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Raw Resource View

struct RawResourceView<T: KubernetesResource>: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let resource: T

    @State private var rawText = ""
    @State private var highlightedText = AttributedString()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var format: Format = .yaml
    @State private var jsonData: Data?
    @State private var loadedResourceName: String?
    @State private var searchText = ""
    @State private var matchCount = 0

    enum Format: String, CaseIterable {
        case yaml = "YAML"
        case json = "JSON"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Format", selection: $format) {
                    ForEach(Format.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(width: 120)
                    if !searchText.isEmpty {
                        Text("\(matchCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(rawText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(rawText.isEmpty)
            }
            .padding(8)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(highlightedText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: resource.name) { loadIfNeeded() }
        .onChange(of: format) { convertToFormat() }
        .onChange(of: searchText) { applyHighlighting() }
    }

    private func loadIfNeeded() {
        let key = "\(resource.namespace ?? "")_\(resource.name)"
        guard key != loadedResourceName else { return }
        loadedResourceName = key
        Task { await loadRawJSON() }
    }

    @MainActor
    private func loadRawJSON() async {
        isLoading = true
        errorMessage = nil
        do {
            let data = try await viewModel.fetchRawJSON(for: resource)
            jsonData = data
            convertToFormat()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Strip noisy Kubernetes metadata (managedFields, etc.) for cleaner output.
    private func cleanObject(_ obj: Any) -> Any {
        guard var dict = obj as? [String: Any] else { return obj }
        if var metadata = dict["metadata"] as? [String: Any] {
            metadata.removeValue(forKey: "managedFields")
            dict["metadata"] = metadata
        }
        return dict
    }

    private func prettyJSON(_ data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) {
            let cleaned = cleanObject(obj)
            if let pretty = try? JSONSerialization.data(withJSONObject: cleaned, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                return str
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func convertToFormat() {
        guard let data = jsonData else { return }
        switch format {
        case .json:
            rawText = prettyJSON(data)
        case .yaml:
            if let obj = try? JSONSerialization.jsonObject(with: data) {
                let cleaned = cleanObject(obj)
                var lines: [String] = []
                emitYAML(cleaned, indent: 0, into: &lines)
                rawText = lines.joined(separator: "\n")
            } else {
                rawText = prettyJSON(data)
            }
        }
        applyHighlighting()
    }

    private func applyHighlighting() {
        var result = format == .json ? highlightJSON(rawText) : highlightYAML(rawText)
        if !searchText.isEmpty {
            matchCount = applySearchHighlight(to: &result, query: searchText)
        } else {
            matchCount = 0
        }
        highlightedText = result
    }

    /// Adds yellow background to all case-insensitive matches; returns match count.
    private func applySearchHighlight(to text: inout AttributedString, query: String) -> Int {
        var count = 0
        let plain = String(text.characters)
        let lowerPlain = plain.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerPlain.startIndex
        while let range = lowerPlain.range(of: lowerQuery, range: searchStart..<lowerPlain.endIndex) {
            let startOffset = lowerPlain.distance(from: lowerPlain.startIndex, to: range.lowerBound)
            let length = lowerPlain.distance(from: range.lowerBound, to: range.upperBound)
            let attrStart = text.index(text.startIndex, offsetByCharacters: startOffset)
            let attrEnd = text.index(attrStart, offsetByCharacters: length)
            text[attrStart..<attrEnd].backgroundColor = .yellow
            text[attrStart..<attrEnd].foregroundColor = .black
            count += 1
            searchStart = range.upperBound
        }
        return count
    }

    // MARK: - JSON → YAML emitter

    private func emitYAML(_ value: Any, indent: Int, into lines: inout [String]) {
        let pad = String(repeating: "  ", count: indent)
        switch value {
        case let dict as [String: Any]:
            for key in dict.keys.sorted() {
                let val = dict[key]!
                if let sub = val as? [String: Any], !sub.isEmpty {
                    lines.append("\(pad)\(yamlKey(key)):")
                    emitYAML(sub, indent: indent + 1, into: &lines)
                } else if let arr = val as? [Any], !arr.isEmpty {
                    lines.append("\(pad)\(yamlKey(key)):")
                    emitYAMLArray(arr, indent: indent, into: &lines)
                } else {
                    lines.append("\(pad)\(yamlKey(key)): \(yamlScalar(val))")
                }
            }
        case let arr as [Any]:
            emitYAMLArray(arr, indent: indent, into: &lines)
        default:
            lines.append("\(pad)\(yamlScalar(value))")
        }
    }

    private func emitYAMLArray(_ array: [Any], indent: Int, into lines: inout [String]) {
        let pad = String(repeating: "  ", count: indent)
        for item in array {
            if let dict = item as? [String: Any] {
                let keys = dict.keys.sorted()
                for (i, key) in keys.enumerated() {
                    let val = dict[key]!
                    let prefix = i == 0 ? "\(pad)- " : "\(pad)  "
                    if let sub = val as? [String: Any], !sub.isEmpty {
                        lines.append("\(prefix)\(yamlKey(key)):")
                        emitYAML(sub, indent: indent + 2, into: &lines)
                    } else if let arr = val as? [Any], !arr.isEmpty {
                        lines.append("\(prefix)\(yamlKey(key)):")
                        emitYAMLArray(arr, indent: indent + 2, into: &lines)
                    } else {
                        lines.append("\(prefix)\(yamlKey(key)): \(yamlScalar(val))")
                    }
                }
            } else {
                lines.append("\(pad)- \(yamlScalar(item))")
            }
        }
    }

    private func yamlKey(_ key: String) -> String {
        if key.contains(":") || key.contains("#") || key.contains("{") ||
           key.contains("}") || key.contains("[") || key.contains("]") ||
           key.contains(",") || key.contains("&") || key.contains("*") ||
           key.contains("!") || key.contains("|") || key.contains(">") ||
           key.contains("'") || key.contains("\"") || key.contains("%") ||
           key.contains("@") || key.contains("`") || key.isEmpty {
            return "\"\(key.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return key
    }

    private func yamlScalar(_ value: Any) -> String {
        switch value {
        case is NSNull:
            return "null"
        case let num as NSNumber where CFBooleanGetTypeID() == CFGetTypeID(num):
            return num.boolValue ? "true" : "false"
        case let num as NSNumber:
            return "\(num)"
        case let str as String:
            if str.isEmpty { return "''" }
            if str.contains("\n") {
                return "|\n" + str.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "  \($0)" }.joined(separator: "\n")
            }
            let needsQuoting = str.contains(": ") || str.contains("#") ||
                str.contains("\"") || str.hasPrefix("{") || str.hasPrefix("[") ||
                str.hasPrefix("- ") || str.hasPrefix("? ") ||
                ["true","false","null","yes","no","~"].contains(str.lowercased())
            if needsQuoting {
                return "\"\(str.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return str
        default:
            return "\(value)"
        }
    }

    // MARK: - Syntax highlighting

    private var keyColor: Color { .blue }
    private var stringColor: Color { .green }
    private var numberColor: Color { .purple }
    private var keywordColor: Color { .orange }

    private func highlightYAML(_ text: String) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            if i > 0 { result.append(AttributedString("\n")) }
            result.append(highlightYAMLLine(line))
        }
        return result
    }

    private func highlightYAMLLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        let trimmed = String(line.drop(while: { $0 == " " }))
        let indentCount = line.count - trimmed.count
        if indentCount > 0 {
            result.append(AttributedString(String(repeating: " ", count: indentCount)))
        }

        var rest = trimmed

        // Handle array dash prefix
        if rest.hasPrefix("- ") {
            var dash = AttributedString("- ")
            dash.foregroundColor = .secondary
            result.append(dash)
            rest = String(rest.dropFirst(2))
        }

        // key: value | key: | bare value
        if let colonSpace = rest.range(of: ": ", options: .literal) {
            let key = String(rest[rest.startIndex..<colonSpace.lowerBound])
            let value = String(rest[colonSpace.upperBound...])
            result.append(styledKey(key))
            var colon = AttributedString(": ")
            colon.foregroundColor = .secondary
            result.append(colon)
            result.append(styledValue(value))
        } else if rest.hasSuffix(":") {
            let key = String(rest.dropLast())
            result.append(styledKey(key))
            var colon = AttributedString(":")
            colon.foregroundColor = .secondary
            result.append(colon)
        } else {
            result.append(styledValue(rest))
        }

        return result
    }

    private func styledKey(_ key: String) -> AttributedString {
        var attr = AttributedString(key)
        attr.foregroundColor = keyColor
        return attr
    }

    private func styledValue(_ value: String) -> AttributedString {
        var attr = AttributedString(value)
        let lower = value.lowercased()
        if lower == "true" || lower == "false" || lower == "null" {
            attr.foregroundColor = keywordColor
        } else if value == "''" || value.hasPrefix("\"") || value.hasPrefix("|") {
            attr.foregroundColor = stringColor
        } else if !value.isEmpty, value.first?.isNumber == true || value.first == "-",
                  Double(value) != nil {
            attr.foregroundColor = numberColor
        } else {
            attr.foregroundColor = stringColor
        }
        return attr
    }

    private func highlightJSON(_ text: String) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            if i > 0 { result.append(AttributedString("\n")) }
            result.append(highlightJSONLine(line))
        }
        return result
    }

    private func highlightJSONLine(_ line: String) -> AttributedString {
        var result = AttributedString()
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indentCount = line.count - line.drop(while: { $0 == " " }).count
        if indentCount > 0 {
            result.append(AttributedString(String(repeating: " ", count: indentCount)))
        }

        // Apple's prettyPrinted JSON uses " : " between key and value
        if trimmed.hasPrefix("\""), let sep = trimmed.range(of: "\" : ") {
            let key = String(trimmed[trimmed.startIndex...sep.lowerBound])
            let value = String(trimmed[sep.upperBound...])

            var keyAttr = AttributedString(key)
            keyAttr.foregroundColor = keyColor
            result.append(keyAttr)

            var sepAttr = AttributedString(" : ")
            sepAttr.foregroundColor = .secondary
            result.append(sepAttr)

            result.append(styledJSONValue(value))
        } else if trimmed.hasPrefix("\"") {
            // String value (not a key)
            result.append(styledJSONValue(trimmed))
        } else {
            result.append(styledJSONValue(trimmed))
        }

        return result
    }

    private func styledJSONValue(_ value: String) -> AttributedString {
        let cleaned = value.hasSuffix(",") ? String(value.dropLast()) : value
        let comma = value.hasSuffix(",")
        var attr = AttributedString(cleaned)

        if cleaned.hasPrefix("\"") {
            attr.foregroundColor = stringColor
        } else if cleaned == "true" || cleaned == "false" || cleaned == "null" {
            attr.foregroundColor = keywordColor
        } else if !cleaned.isEmpty, Double(cleaned) != nil {
            attr.foregroundColor = numberColor
        } else {
            attr.foregroundColor = .secondary
        }

        if comma {
            var c = AttributedString(",")
            c.foregroundColor = .secondary
            attr.append(c)
        }
        return attr
    }
}
