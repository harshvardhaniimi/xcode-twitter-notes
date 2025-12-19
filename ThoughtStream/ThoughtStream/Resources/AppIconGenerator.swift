import SwiftUI

/// A view that generates the app icon design
/// This can be used to export the icon at various sizes
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.5, blue: 1.0),
                    Color(red: 0.4, green: 0.3, blue: 0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Brain/thought icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)

            // Small sparkle/thought bubbles
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: size * 0.08, height: size * 0.08)
                        .offset(x: -size * 0.15, y: size * 0.1)
                }
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: size * 0.05, height: size * 0.05)
                        .offset(x: -size * 0.08, y: size * 0.2)
                }
                Spacer()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237)) // iOS icon corner radius
    }
}

/// Generates app icon images at required sizes
class AppIconGenerator {
    static func generateIcons() {
        let sizes: [(CGFloat, String)] = [
            (1024, "AppIcon-1024"),
            (180, "AppIcon-60@3x"),
            (120, "AppIcon-60@2x"),
            (167, "AppIcon-83.5@2x"),
            (152, "AppIcon-76@2x"),
            (76, "AppIcon-76"),
            (40, "AppIcon-40"),
            (80, "AppIcon-40@2x"),
            (120, "AppIcon-40@3x"),
            (58, "AppIcon-29@2x"),
            (87, "AppIcon-29@3x"),
            (20, "AppIcon-20"),
            (40, "AppIcon-20@2x"),
            (60, "AppIcon-20@3x")
        ]

        for (size, name) in sizes {
            let view = AppIconView(size: size)
            // In a real implementation, you would render this to a UIImage and save it
            print("Generate \(name) at \(size)x\(size)")
        }
    }
}

#Preview {
    AppIconView(size: 200)
}
