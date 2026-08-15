import SwiftUI

struct FileDropSuccessView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didSettle = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.notchAccent)
                .offset(y: reduceMotion ? 0 : (didSettle ? 8 : -8))
                .scaleEffect(reduceMotion ? 1 : (didSettle ? 0.72 : 1))

            Text("Added to Shelf")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82).delay(0.08)) {
                didSettle = true
            }
        }
    }
}
