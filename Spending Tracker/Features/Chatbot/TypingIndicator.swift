import SwiftUI
import Combine

struct TypingIndicator: View {
    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.25)).frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile").foregroundStyle(.purple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Assistant")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .opacity(phase == i ? 1.0 : 0.3)
                            .scaleEffect(phase == i ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 0.25), value: phase)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.background.secondary, in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
