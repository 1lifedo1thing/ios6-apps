import SwiftUI

struct ClassicDateWheel: View {
  @Binding var date: Date
  var body: some View {
    DatePicker(
      L10n.text("Due date"), selection: $date, displayedComponents: [.date, .hourAndMinute]
    )
    .datePickerStyle(.wheel).labelsHidden().frame(height: 170).clipped()
    .background(
      LinearGradient(
        stops: [
          .init(color: Color(white: 0.55), location: 0),
          .init(color: Color(white: 0.95), location: 0.3),
          .init(color: Color(white: 0.98), location: 0.5),
          .init(color: Color(white: 0.9), location: 0.7),
          .init(color: Color(white: 0.5), location: 1),
        ], startPoint: .top, endPoint: .bottom)
    )
    .overlay {
      ZStack {
        LinearGradient(
          colors: [.black.opacity(0.25), .clear, .clear, .black.opacity(0.3)], startPoint: .top,
          endPoint: .bottom)
        Rectangle().fill(Color(red: 0.73, green: 0.77, blue: 0.84).opacity(0.25)).blendMode(
          .multiply
        )
        .frame(height: 34)
        .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.4)).frame(height: 1) }
        .overlay(alignment: .top) {
          Rectangle().fill(.white.opacity(0.75)).frame(height: 1).offset(y: 1)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.4)).frame(height: 1) }
        GeometryReader { geometry in
          let divisions: [CGFloat] =
            AppLanguage.current == .english ? [0.44, 0.62, 0.8] : [0.59, 0.8]
          ForEach(divisions, id: \.self) { division in
            Rectangle().fill(
              LinearGradient(
                colors: [Color(white: 0.3), Color(white: 0.8), .white.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: 2, height: geometry.size.height)
            .position(x: geometry.size.width * division, y: geometry.size.height / 2)
          }
        }
      }.accessibilityHidden(true).allowsHitTesting(false)
    }
    .overlay(Rectangle().strokeBorder(.black.opacity(0.55), lineWidth: 1).allowsHitTesting(false))
    .padding(5)
    .background(
      LinearGradient(
        colors: [Color(white: 0.75), Color(white: 0.35)], startPoint: .top, endPoint: .bottom)
    )
    .overlay(Rectangle().strokeBorder(.black.opacity(0.45), lineWidth: 1).allowsHitTesting(false))
    .padding(.horizontal, 8).padding(.vertical, 6)
  }
}
