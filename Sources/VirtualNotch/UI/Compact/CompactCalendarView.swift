import SwiftUI

struct CompactCalendarView: View {
    @ObservedObject var service: AppleCalendarService

    var body: some View {
        let event = service.nextEvent
        return HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.98, green: 0.36, blue: 0.36).opacity(0.16))
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.48, blue: 0.45))
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(event?.title ?? "Calendar")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(service.compactStatus)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(Color.notchMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let event {
                Text(event.shortTime)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.notchAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
