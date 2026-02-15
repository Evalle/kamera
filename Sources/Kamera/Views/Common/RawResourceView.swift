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
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var format: Format = .yaml
    @State private var jsonData: Data?
    @State private var loadedResourceName: String?

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
                    Text(rawText)
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
}
