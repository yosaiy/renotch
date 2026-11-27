import SwiftUI

struct CompactFaceIDView: View {
     @Environment(\.accessibilityReduceMotion) private var reduceMotion
     let auth: AuthGlance
     @State private var isPulsing = false
     @State private var showCheck = false

     var body: some View {
         HStack(spacing: 12) {
             ZStack {
                 Circle()
                     .fill(auth.isSuccess ? Color.notchAccent.opacity(0.16) : Color.white.opacity(0.12))

                 if showCheck && auth.isSuccess {
                     Image(systemName: "checkmark")
                         .font(.system(size: 13, weight: .bold))
                         .foregroundStyle(Color.notchAccent)
                         .transition(.scale.combined(with: .opacity))
                 } else {
                     Image(systemName: "faceid")
                         .font(.system(size: 14, weight: .medium))
                         .foregroundStyle(auth.isSuccess ? Color.notchAccent : .white)
                         .scaleEffect(isPulsing ? 1.08 : 0.95)
                         .transition(.scale.combined(with: .opacity))
                 }
             }
             .frame(width: 28, height: 28)

             VStack(alignment: .leading, spacing: 1) {
                 Text(auth.title)
                     .font(.system(size: 11.5, weight: .semibold))
                     .foregroundStyle(.white)
                     .lineLimit(1)

                 Text(auth.subtitle)
                     .font(.system(size: 9, weight: .medium))
                     .foregroundStyle(Color.notchMuted)
                     .lineLimit(1)
             }

             Spacer(minLength: 6)

             if auth.isSuccess {
                 Capsule()
                     .fill(Color.notchAccent.opacity(0.15))
                     .overlay(
                         Capsule()
                             .stroke(Color.notchAccent.opacity(0.3), lineWidth: 0.8)
                     )
                     .frame(width: 6, height: 18)
             }
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .onAppear {
             if reduceMotion {
                 showCheck = auth.isSuccess
             } else {
                 withAnimation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)) {
                     isPulsing = true
                 }
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                     withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                         showCheck = true
                     }
                 }
             }
         }
     }
 }
