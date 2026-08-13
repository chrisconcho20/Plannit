import SwiftUI

// MonthGrid — a month calendar with per-day hue marks and a selected day.

struct MonthGrid: View {
    let year: Int
    let month: Int              // 1...12
    var marks: [Int: [Color]] = [:]
    var today: Int? = nil
    @Binding var selected: Int?

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var daysInMonth: Int {
        var c = DateComponents(); c.year = year; c.month = month
        guard let date = Calendar.current.date(from: c),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }
    private var leadingBlanks: Int {
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        guard let date = Calendar.current.date(from: c) else { return 0 }
        return Calendar.current.component(.weekday, from: date) - 1  // 1=Sun -> 0 blanks
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).textStyle(.overline, color: .textFaint)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 44) }
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Int) -> some View {
        let isSelected = selected == day
        let isToday = today == day
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.system(size: 16, weight: isToday || isSelected ? .bold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : (isToday ? Color.actionPrimary : Color.textBody))
                .frame(width: 34, height: 34)
                .background(isSelected ? Color.actionPrimary : .clear)
                .clipShape(Circle())
            HStack(spacing: 3) {
                ForEach(Array((marks[day] ?? []).prefix(3).enumerated()), id: \.offset) { _, c in
                    Circle().fill(c).frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Motion.fast) { selected = (selected == day ? nil : day) } }
    }
}
