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

    /// One square of the grid. The blanks before the 1st are cells too, and they
    /// carry the same kind of id as the days — two sibling ForEach views in one
    /// lazy grid share an identity space, so ids 1, 2 and 3 belonged to both the
    /// blanks and the first days of the month, and SwiftUI dropped the
    /// collisions. That is why the 1st was missing from every month.
    struct Cell: Identifiable {
        let id: Int          // position in the grid, so it is unique either way
        let day: Int?        // nil for a leading blank
    }

    /// The month laid out Sunday-first, blanks included. Static and calendar-
    /// injectable so the offsets can be tested without a view.
    static func cells(year: Int, month: Int, calendar: Calendar = .current) -> [Cell] {
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        guard let first = calendar.date(from: c),
              let range = calendar.range(of: .day, in: .month, for: first)
        else { return [] }
        let blanks = calendar.component(.weekday, from: first) - 1   // 1=Sun -> 0 blanks
        let days = range.count
        return (0..<(blanks + days)).map { index in
            Cell(id: index, day: index < blanks ? nil : index - blanks + 1)
        }
    }

    private var cells: [Cell] { Self.cells(year: year, month: month) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).textStyle(.overline, color: .textFaint)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(cells) { cell in
                    if let day = cell.day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
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
        // Without this a swipe through the month reads "1, 2, 3…" with no dates
        // and no idea which days have anything on them.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(day))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func spoken(_ day: Int) -> String {
        var parts: [String] = []
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        if let date = Calendar.current.date(from: c) {
            let f = DateFormatter(); f.dateFormat = "EEEE d MMMM"
            parts.append(f.string(from: date))
        } else {
            parts.append("\(day)")
        }
        if today == day { parts.append("today") }
        let count = marks[day]?.count ?? 0
        if count > 0 { parts.append(count == 1 ? "1 event" : "\(count) events") }
        return parts.joined(separator: ", ")
    }
}
