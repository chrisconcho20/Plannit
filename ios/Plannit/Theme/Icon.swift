import SwiftUI

// Bridges the design system's (lucide-style) icon names to native SF Symbols,
// so the app stays fully native instead of bundling the SVGs in assets/icons.

struct PIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = .textBody
    var weight: Font.Weight = .medium

    init(_ name: String, size: CGFloat = 20, color: Color = .textBody, weight: Font.Weight = .medium) {
        self.name = name; self.size = size; self.color = color; self.weight = weight
    }

    var body: some View {
        Image(systemName: Self.symbol(name))
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }

    static func symbol(_ name: String) -> String {
        map[name] ?? "circle"
    }

    private static let map: [String: String] = [
        // calendar
        "calendar": "calendar", "calendar-days": "calendar",
        "calendar-check": "calendar.badge.checkmark", "calendar-plus": "calendar.badge.plus",
        "calendar-heart": "calendar", "clock": "clock", "hourglass": "hourglass", "repeat": "repeat",
        // people
        "users": "person.2.fill", "user": "person.fill", "user-plus": "person.badge.plus",
        // actions / nav
        "plus": "plus", "check": "checkmark", "circle-check": "checkmark.circle.fill",
        "chevron-right": "chevron.right", "chevron-left": "chevron.left", "chevron-down": "chevron.down",
        "arrow-left": "arrow.left", "arrow-right": "arrow.right",
        "x": "xmark", "ellipsis": "ellipsis", "pencil": "pencil", "trash-2": "trash",
        "search": "magnifyingglass", "share-2": "square.and.arrow.up", "link": "link", "send": "paperplane.fill",
        "settings": "gearshape.fill", "bell": "bell.fill", "lock": "lock.fill",
        "eye": "eye", "eye-off": "eye.slash", "info": "info.circle", "inbox": "tray.fill",
        "list": "list.bullet", "map-pin": "mappin.and.ellipse", "house": "house.fill",
        "message-circle": "message.fill", "sun": "sun.max.fill", "moon": "moon.fill",
        // the wedge / delight
        "sparkles": "sparkles", "wand-sparkles": "wand.and.stars", "star": "star.fill",
        "heart": "heart.fill", "thumbs-up": "hand.thumbsup.fill", "party-popper": "party.popper.fill",
        "apple": "applelogo",
        // activity glyphs (event hue tiles)
        "dumbbell": "dumbbell.fill", "utensils": "fork.knife", "cake": "birthday.cake.fill",
        "coffee": "cup.and.saucer.fill", "beer": "mug.fill", "film": "film.fill", "plane": "airplane",
    ]
}
