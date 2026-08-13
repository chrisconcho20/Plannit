import SwiftUI

// AvailabilityBar — from design-system/components/calendar/AvailabilityBar.jsx.
// A per-person free/busy strip across a day window; busy blocks over a free track.

struct BusyRange { let start: Double; let end: Double }

struct AvailabilityBar: View {
    var name: String? = nil
    var blocks: [BusyRange] = []
    var from: Double = 8
    var to: Double = 22
    var height: CGFloat = 12

    private var span: Double { to - from }

    var body: some View {
        HStack(spacing: 10) {
            if let name {
                Text(name).textStyle(.footnote, color: .textMuted)
                    .frame(width: 64, alignment: .leading).lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.teal100)
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                        let x = (b.start - from) / span * geo.size.width
                        let w = (b.end - b.start) / span * geo.size.width
                        Rectangle()
                            .fill(Color.statusBusy)
                            .frame(width: Swift.max(0, w))
                            .offset(x: Swift.max(0, x))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: height)
        }
    }
}
