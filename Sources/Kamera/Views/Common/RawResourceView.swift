import SwiftUI
import Yams

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

    private func convertToFormat() {
        guard let data = jsonData else { return }
        switch format {
        case .json:
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                rawText = str
            } else {
                rawText = String(data: data, encoding: .utf8) ?? ""
            }
        case .yaml:
            if let obj = try? JSONSerialization.jsonObject(with: data) {
                let native = toSwiftNative(obj)
                if let yamlStr = try? Yams.dump(object: native, sortKeys: true) {
                    rawText = yamlStr
                } else {
                    rawText = String(data: data, encoding: .utf8) ?? ""
                }
            } else {
                rawText = String(data: data, encoding: .utf8) ?? ""
            }
        }
    }

    private func toSwiftNative(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]:
            return dict.mapValues { toSwiftNative($0) }
        case let array as [Any]:
            return array.map { toSwiftNative($0) }
        case let number as NSNumber:
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return number.boolValue
            }
            if number.objCType.pointee == CChar(UInt8(ascii: "d")) ||
               number.objCType.pointee == CChar(UInt8(ascii: "f")) {
                return number.doubleValue
            }
            return number.intValue
        case is NSNull:
            return Optional<String>.none as Any
        default:
            return value
        }
    }
}
