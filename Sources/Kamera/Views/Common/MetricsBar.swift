import SwiftUI

struct MetricsBar: View {
    let label: String
    let usedText: String
    let totalText: String
    let fraction: Double  // 0.0–1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                Text(usedText).monospacedDigit()
                Text("/").foregroundStyle(.tertiary)
                Text(totalText).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Text("\(Int(fraction * 100))%").monospacedDigit().foregroundStyle(barColor)
            }
            .font(.callout)
            GeometryReader { geo in
                Capsule().fill(Color.secondary.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(barColor)
                            .frame(width: max(2, geo.size.width * fraction))
                    }
            }
            .frame(height: 5)
        }
    }

    private var barColor: Color {
        fraction >= 0.9 ? .red : fraction >= 0.7 ? .orange : .green
    }
}
