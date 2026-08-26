import PhotosUI
import SwiftUI

// Editing how you appear to everyone else: your name, and the avatar next to it.
//
// Two ways to set the avatar, and the order here is deliberate. A colour is
// free — instant, offline, and nothing about you leaves the phone. A photo is
// personal data that everyone in your groups can fetch, so it sits below the
// colours, states plainly who can see it, and can be removed again in one tap.
//
// The photo is downscaled and re-encoded on device before it goes anywhere:
// a modern iPhone photo is several megabytes and carries EXIF, including,
// often, the location it was taken. A 512px JPEG re-encoded from raw pixels
// carries none of that.

struct ProfileSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var hue: GroupHue?
    @State private var avatarURL: String?
    @State private var pickedItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Your profile") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    preview

                    fieldLabel("Name")
                    PTextField(placeholder: "Your name", text: $name, icon: "user")
                    Text("This is how you appear to everyone in your groups.")
                        .textStyle(.footnote, color: .textMuted)

                    fieldLabel("Colour")
                    colours

                    fieldLabel("Photo")
                    photoRow

                    if let errorText {
                        Text(errorText).textStyle(.footnote, color: .statusDanger)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(Space.gutter)
            }
            footer
        }
        .background(Color.appBg)
        .presentationDetents([.large])
        .onAppear {
            name = model.displayName
            hue = model.avatarHue
            avatarURL = model.avatarURL
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            load(item)
        }
    }

    // MARK: Pieces

    private var preview: some View {
        HStack(spacing: 16) {
            Avatar(name: trimmed.isEmpty ? model.displayName : trimmed,
                   size: 72, hue: hue, imageURL: avatarURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(trimmed.isEmpty ? "Your name" : trimmed)
                    .textStyle(.headline, color: .textStrong)
                Text(avatarURL == nil ? "Initials on a colour" : "Your photo")
                    .textStyle(.caption, color: .textMuted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.card)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(Color.hairline, lineWidth: 1))
    }

    private var colours: some View {
        HStack(spacing: 10) {
            ForEach(GroupHue.allCases, id: \.self) { option in
                let on = hue == option
                Circle()
                    .fill(option.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().strokeBorder(Color.actionPrimary, lineWidth: on ? 3 : 0)
                            .padding(-3)
                    )
                    .overlay(on ? PIcon("check", size: 16, color: .white) : nil)
                    .contentShape(Circle())
                    .onTapGesture { withAnimation(Motion.fast) { hue = on ? nil : option } }
                    .accessibilityLabel("\(option.rawValue.capitalized)\(on ? ", selected" : "")")
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var photoRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickedItem, matching: .images,
                             photoLibrary: .shared()) {
                    Label(uploading ? "Uploading…" : (avatarURL == nil ? "Choose a photo"
                                                                       : "Change photo"),
                          systemImage: "photo")
                        .textStyle(.subhead, color: .textBody)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.actionSecondary)
                        .clipShape(Capsule())
                }
                .disabled(uploading)

                if avatarURL != nil {
                    Button { withAnimation(Motion.fast) { avatarURL = nil } } label: {
                        Text("Remove").textStyle(.subhead, color: .statusDanger)
                            .frame(minHeight: 44).padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Everyone in your groups can see your photo. It's resized on your "
                 + "phone first, so nothing else from the original — including where "
                 + "it was taken — is sent.")
                .textStyle(.caption, color: .textFaint)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.hairline)
            PlannitButton(title: saving ? "Saving…" : "Save", variant: .primary,
                          size: .lg, fullWidth: true) { save() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .padding(Space.gutter)
        }
        .barSurface()
    }

    // MARK: State

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var changed: Bool {
        trimmed != model.displayName || hue != model.avatarHue || avatarURL != model.avatarURL
    }
    private var canSave: Bool { !saving && !uploading && !trimmed.isEmpty && changed }

    // MARK: Actions

    /// Downscale, re-encode, upload. All three matter: the first two keep the
    /// upload small and strip the metadata, the third is the only part anyone
    /// else sees.
    private func load(_ item: PhotosPickerItem) {
        uploading = true
        errorText = nil
        Task {
            defer { uploading = false; pickedItem = nil }
            guard let raw = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw),
                  let jpeg = Self.square(image, side: 512) else {
                errorText = "Couldn’t read that photo. Try another."
                return
            }
            if let url = await model.uploadAvatar(jpeg) {
                avatarURL = url
            } else {
                errorText = "Couldn’t upload that photo. Try again."
            }
        }
    }

    /// Centre-cropped square, re-encoded as JPEG — which is also what drops the
    /// EXIF, since this draws pixels rather than copying the file.
    static func square(_ image: UIImage, side: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let size = CGSize(width: side, height: side)
        let scale = max(side / image.size.width, side / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }.jpegData(compressionQuality: 0.8)
    }

    private func save() {
        saving = true
        errorText = nil
        Task {
            let ok = await model.updateProfile(name: trimmed, hue: hue, avatarURL: avatarURL)
            saving = false
            if ok { dismiss() } else { errorText = "Couldn’t save your profile. Try again." }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).textStyle(.overline, color: .textFaint)
    }
}
