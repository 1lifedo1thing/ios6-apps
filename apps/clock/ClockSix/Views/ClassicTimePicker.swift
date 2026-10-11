import SwiftUI
import UIKit

struct ClassicTimePicker: View {
  @Binding var hour: Int
  @Binding var minute: Int
  var duration = false

  var body: some View {
    NativeClockPicker(hour: $hour, minute: $minute, duration: duration)
      .frame(height: 164)
      .background {
        LinearGradient(
          stops: [
            .init(color: Color(hex: 0xA0A3AA), location: 0),
            .init(color: Color(hex: 0xECEDEF), location: 0.22),
            .init(color: Color(hex: 0xFAFAF8), location: 0.5),
            .init(color: Color(hex: 0xE6E7E9), location: 0.78),
            .init(color: Color(hex: 0x8A8E98), location: 1),
          ], startPoint: .top, endPoint: .bottom)
      }
      .overlay {
        cylinderShading.allowsHitTesting(false).accessibilityHidden(true)
      }
      .overlay {
        selectionBand.allowsHitTesting(false).accessibilityHidden(true)
      }
      .overlay {
        columnSeparators.allowsHitTesting(false).accessibilityHidden(true)
      }
      .clipShape(RoundedRectangle(cornerRadius: 3))
      .overlay {
        RoundedRectangle(cornerRadius: 3).stroke(Color(hex: 0x343B4B), lineWidth: 1)
          .shadow(color: .white.opacity(0.55), radius: 0, y: 1)
          .allowsHitTesting(false).accessibilityHidden(true)
      }
      .padding(.horizontal, 8).padding(.vertical, 8)
      .frame(maxWidth: 370)
      .background {
        LinearGradient(
          stops: [
            .init(color: Color(hex: 0xBCC2D0), location: 0),
            .init(color: Color(hex: 0x929BAD), location: 0.08),
            .init(color: Color(hex: 0x636E85), location: 0.5),
            .init(color: Color(hex: 0x4D576E), location: 0.92),
            .init(color: Color(hex: 0x30394B), location: 1),
          ], startPoint: .top, endPoint: .bottom)
      }
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay {
        RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.8), lineWidth: 1)
          .allowsHitTesting(false).accessibilityHidden(true)
      }
      .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
      .padding(.horizontal, 15)
  }

  private var cylinderShading: some View {
    LinearGradient(
      stops: [
        .init(color: Color(hex: 0x3E4451).opacity(0.55), location: 0),
        .init(color: .white.opacity(0.65), location: 0.25),
        .init(color: .clear, location: 0.4),
        .init(color: .clear, location: 0.6),
        .init(color: .white.opacity(0.55), location: 0.75),
        .init(color: Color(hex: 0x303646).opacity(0.6), location: 1),
      ], startPoint: .top, endPoint: .bottom)
  }

  private var columnSeparators: some View {
    GeometryReader { geometry in
      let count = !duration && AppLanguage.current == .english ? 3 : 2
      ForEach(1..<count, id: \.self) { column in
        Rectangle()
          .fill(
            LinearGradient(
              stops: [
                .init(color: Color(hex: 0x31394B), location: 0),
                .init(color: Color(hex: 0x68748A), location: 0.2),
                .init(color: Color(hex: 0xA3ACBC), location: 0.65),
                .init(color: Color(hex: 0xD4D9E1), location: 1),
              ], startPoint: .leading, endPoint: .trailing)
          )
          .frame(width: 6, height: geometry.size.height)
          .shadow(color: .black.opacity(0.25), radius: 2, x: 1)
          .position(
            x: geometry.size.width * CGFloat(column) / CGFloat(count),
            y: geometry.size.height / 2)
      }
    }
  }

  private var selectionBand: some View {
    ZStack {
      LinearGradient(
        colors: [Color(hex: 0xD9E1F0).opacity(0.4), Color(hex: 0xA6B2CB).opacity(0.35)],
        startPoint: .top, endPoint: .bottom
      )
      .blendMode(.multiply)
      if duration {
        HStack(spacing: 0) {
          ForEach(["hours", "min"], id: \.self) { unit in
            Text(L10n.text(unit)).font(.custom("HelveticaNeue-Bold", size: 18))
              .foregroundStyle(Color(hex: 0x172032))
              .shadow(color: .white.opacity(0.8), radius: 0, y: 1)
              .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 15)
          }
        }
      }
    }.frame(height: 36)
      .overlay(alignment: .top) { Color(hex: 0x72819E).opacity(0.7).frame(height: 1) }
      .overlay(alignment: .top) { Color.white.opacity(0.8).frame(height: 1).offset(y: 1) }
      .overlay(alignment: .bottom) { Color(hex: 0x5F6D89).opacity(0.7).frame(height: 1) }
  }
}

private struct NativeClockPicker: UIViewRepresentable {
  @Binding var hour: Int
  @Binding var minute: Int
  var duration: Bool
  private var twelveHour: Bool { !duration && AppLanguage.current == .english }

  func makeUIView(context: Context) -> UIPickerView {
    let picker = UIPickerView()
    picker.dataSource = context.coordinator
    picker.delegate = context.coordinator
    picker.overrideUserInterfaceStyle = .light
    picker.backgroundColor = .clear
    picker.accessibilityIdentifier = "time-picker"
    return picker
  }
  func updateUIView(_ picker: UIPickerView, context: Context) {
    context.coordinator.parent = self
    let rows = [twelveHour ? (hour % 12 == 0 ? 11 : hour % 12 - 1) : hour, minute, hour / 12]
    for component in 0..<(twelveHour ? 3 : 2) {
      let row = rows[component]
      guard
        row >= 0 && row < context.coordinator.pickerView(picker, numberOfRowsInComponent: component)
      else { continue }
      if picker.selectedRow(inComponent: component) != row {
        picker.selectRow(row, inComponent: component, animated: false)
      }
    }
  }
  static func dismantleUIView(_ picker: UIPickerView, coordinator: Coordinator) {
    picker.delegate = nil
    picker.dataSource = nil
  }
  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    var parent: NativeClockPicker
    init(parent: NativeClockPicker) { self.parent = parent }
    func numberOfComponents(in pickerView: UIPickerView) -> Int { parent.twelveHour ? 3 : 2 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
      component == 0 ? (parent.twelveHour ? 12 : 24) : component == 1 ? 60 : 2
    }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
      36
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int)
      -> String?
    {
      guard row >= 0 && row < self.pickerView(pickerView, numberOfRowsInComponent: component) else {
        return nil
      }
      if component == 2 { return row == 0 ? "AM" : "PM" }
      let value = component == 0 && parent.twelveHour ? row + 1 : row
      let number =
        component == 0 && (parent.twelveHour || parent.duration)
        ? String(value) : String(format: "%02d", value)
      return parent.duration ? number + " " + L10n.text(component == 0 ? "hours" : "min") : number
    }
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
      pickerView.bounds.width / CGFloat(numberOfComponents(in: pickerView))
    }
    func pickerView(
      _ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int,
      reusing view: UIView?
    ) -> UIView {
      let label = view as? UILabel ?? UILabel()
      let title = self.pickerView(pickerView, titleForRow: row, forComponent: component) ?? ""
      label.text = parent.duration ? title.components(separatedBy: " ").first : title
      label.accessibilityLabel = title
      label.font = UIFont(name: "HelveticaNeue-Bold", size: 27) ?? UIFont.boldSystemFont(ofSize: 27)
      label.textColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
      label.textAlignment = .center
      label.shadowColor = .white
      label.shadowOffset = CGSize(width: 0, height: 1)
      let width = self.pickerView(pickerView, widthForComponent: component)
      label.frame = CGRect(x: 0, y: 0, width: parent.duration ? width * 0.6 : width, height: 36)
      return label
    }
    func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int)
      -> String?
    {
      component == 2 ? "AM, PM" : L10n.text(component == 0 ? "hours" : "min")
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
      guard row >= 0 && row < self.pickerView(pickerView, numberOfRowsInComponent: component) else {
        return
      }
      if component == 0 {
        parent.hour = parent.twelveHour ? ((row + 1) % 12) + (parent.hour / 12) * 12 : row
      } else if component == 1 {
        parent.minute = row
      } else {
        parent.hour = parent.hour % 12 + row * 12
      }
    }
  }
}
