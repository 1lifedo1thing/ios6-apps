import SwiftUI
import UIKit

/// An app-owned cylindrical picker, using public scroll APIs for inertia and row snapping.
struct CalendarDatePicker: View {
  @Binding var selection: Date
  let calendar: Calendar
  var dateOnly = false
  var minimum: Date?
  var today = Date.now
  @ScaledMetric(relativeTo: .title2) private var rowHeight = 43.0

  private var twelveHour: Bool { AppLanguage.current == .english }
  private var components: [CalendarPickerComponent] {
    if dateOnly {
      return AppLanguage.current == .chinese ? [.year, .month, .day] : [.month, .day, .year]
    }
    return twelveHour ? [.date, .hour, .minute, .period] : [.date, .hour, .minute]
  }
  private var drumHeight: CGFloat { min(rowHeight, 60) * 4.5 }

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 3) {
        ForEach(components, id: \.self) { component in
          CalendarDrum(
            selection: $selection, component: component, calendar: calendar,
            twelveHour: twelveHour, minimum: minimum, today: today,
            rowHeight: min(rowHeight, 60)
          )
          .frame(
            width: (geometry.size.width - CGFloat(components.count - 1) * 3) * fraction(component)
          )
          .background {
            LinearGradient(
              stops: [
                .init(color: Color(white: 0.40), location: 0),
                .init(color: Color(white: 0.91), location: 0.23),
                .init(color: Color(white: 0.99), location: 0.48),
                .init(color: Color(white: 0.90), location: 0.76),
                .init(color: Color(white: 0.36), location: 1),
              ], startPoint: .top, endPoint: .bottom)
          }
          .overlay {
            LinearGradient(
              stops: [
                .init(color: .black.opacity(0.65), location: 0),
                .init(color: .clear, location: 0.035),
                .init(color: .clear, location: 0.965),
                .init(color: .black.opacity(0.65), location: 1),
              ], startPoint: .leading, endPoint: .trailing
            )
            .allowsHitTesting(false).accessibilityHidden(true)
          }
          .overlay {
            Rectangle().stroke(.black.opacity(0.85), lineWidth: 1)
              .allowsHitTesting(false).accessibilityHidden(true)
          }
        }
      }
      .overlay { glassSelection.allowsHitTesting(false).accessibilityHidden(true) }
      .clipped()
      .overlay {
        Rectangle().stroke(Color(white: 0.13), lineWidth: 1)
          .shadow(color: .white.opacity(0.45), radius: 0, y: 1)
          .allowsHitTesting(false).accessibilityHidden(true)
      }
    }
    .frame(height: drumHeight)
    .padding(.horizontal, 15).padding(.vertical, 12)
    .background {
      LinearGradient(
        stops: [
          .init(color: Color(red: 0.58, green: 0.60, blue: 0.66), location: 0),
          .init(color: Color(red: 0.32, green: 0.35, blue: 0.43), location: 0.49),
          .init(color: Color(red: 0.08, green: 0.09, blue: 0.13), location: 0.50),
          .init(color: Color(red: 0.15, green: 0.17, blue: 0.23), location: 1),
        ], startPoint: .top, endPoint: .bottom
      )
      .overlay(alignment: .top) { Color(white: 0.25).frame(height: 1) }
      .overlay(alignment: .top) { Color.white.opacity(0.45).frame(height: 1).offset(y: 1) }
    }
    .accessibilityElement(children: .contain)
  }

  private func fraction(_ component: CalendarPickerComponent) -> CGFloat {
    if dateOnly {
      if AppLanguage.current == .chinese { return component == .year ? 0.46 : 0.27 }
      return component == .month ? 0.46 : component == .day ? 0.20 : 0.34
    }
    if twelveHour { return component == .date ? 0.49 : component == .period ? 0.19 : 0.16 }
    return component == .date ? 0.64 : 0.18
  }

  private var glassSelection: some View {
    LinearGradient(
      stops: [
        .init(color: Color(red: 0.88, green: 0.91, blue: 1).opacity(0.38), location: 0),
        .init(color: Color(red: 0.66, green: 0.73, blue: 0.92).opacity(0.27), location: 0.48),
        .init(color: Color(red: 0.38, green: 0.46, blue: 0.72).opacity(0.36), location: 0.50),
        .init(color: Color(red: 0.45, green: 0.53, blue: 0.81).opacity(0.30), location: 1),
      ], startPoint: .top, endPoint: .bottom
    )
    .frame(height: min(rowHeight, 60))
    .overlay(alignment: .top) { Color(red: 0.35, green: 0.41, blue: 0.57).frame(height: 1) }
    .overlay(alignment: .top) { Color.white.opacity(0.85).frame(height: 1).offset(y: 1) }
    .overlay(alignment: .bottom) { Color(red: 0.28, green: 0.33, blue: 0.50).frame(height: 1) }
    .shadow(color: .black.opacity(0.24), radius: 1, y: 1)
  }
}

private struct CalendarDrum: UIViewRepresentable {
  @Binding var selection: Date
  let component: CalendarPickerComponent
  let calendar: Calendar
  let twelveHour: Bool
  let minimum: Date?
  let today: Date
  let rowHeight: CGFloat

  func makeUIView(context: Context) -> CalendarDrumView { CalendarDrumView() }
  func updateUIView(_ view: CalendarDrumView, context: Context) {
    let range = CalendarPickerDate.range(
      component, date: selection, calendar: calendar,
      twelveHour: twelveHour)
    let selected = CalendarPickerDate.value(
      component, in: selection, calendar: calendar,
      twelveHour: twelveHour)
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = AppLanguage.current.locale
    formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
    let first = calendar.date(from: DateComponents(year: 1, month: 1, day: 1))!
    view.configure(
      range: range, selected: selected,
      repeating: component != .date && component != .year && component != .period,
      rowHeight: rowHeight, identifier: "wheel-" + component.rawValue, label: component.label,
      text: { value in
        switch component {
        case .date:
          let date = calendar.date(byAdding: .day, value: value, to: first)!
          return calendar.isDate(date, inSameDayAs: today)
            ? L10n.text("Today") : formatter.string(from: date)
        case .month:
          return AppLanguage.current == .chinese ? "\(value)月" : formatter.monthSymbols[value - 1]
        case .year: return String(value)
        case .day: return AppLanguage.current == .chinese ? "\(value)日" : String(value)
        case .hour: return String(value)
        case .minute: return String(format: "%02d", value)
        case .period: return value == 0 ? formatter.amSymbol : formatter.pmSymbol
        }
      },
      onChange: { value in
        selection = CalendarPickerDate.replacing(
          component, with: value, in: selection, calendar: calendar,
          twelveHour: twelveHour, minimum: minimum)
        return CalendarPickerDate.value(
          component, in: selection, calendar: calendar,
          twelveHour: twelveHour)
      })
  }
  static func dismantleUIView(_ view: CalendarDrumView, coordinator: ()) { view.stop() }
}

private final class CalendarDrumView: UIView, UIScrollViewDelegate {
  private let scroll = UIScrollView()
  private let labels = (0..<11).map { _ in UILabel() }
  private var range = 0..<1
  private var repeating = false
  private var rowHeight: CGFloat = 43
  private var rowCount = 1
  private var selectedRow = 0
  private var requestedValue = 0
  private var configuring = false
  private var text: (Int) -> String = { String($0) }
  private var onChange: (Int) -> Int = { $0 }

  override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = true
    isAccessibilityElement = true
    accessibilityTraits = [.adjustable]
    scroll.showsVerticalScrollIndicator = false
    scroll.showsHorizontalScrollIndicator = false
    scroll.contentInsetAdjustmentBehavior = .never
    scroll.decelerationRate = .fast
    scroll.isDirectionalLockEnabled = true
    scroll.delegate = self
    scroll.accessibilityElementsHidden = true
    addSubview(scroll)
    for label in labels {
      label.textAlignment = .center
      label.textColor = UIColor(white: 0.04, alpha: 1)
      label.shadowColor = .white
      label.shadowOffset = CGSize(width: 0, height: 1)
      label.adjustsFontSizeToFitWidth = true
      label.minimumScaleFactor = 0.65
      label.isUserInteractionEnabled = false
      label.isAccessibilityElement = false
      addSubview(label)
    }
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  func configure(
    range: Range<Int>, selected: Int, repeating: Bool, rowHeight: CGFloat,
    identifier: String, label: String, text: @escaping (Int) -> String,
    onChange: @escaping (Int) -> Int
  ) {
    configuring = true
    let changed = self.range != range || self.rowHeight != rowHeight
    self.range = range
    self.repeating = repeating
    self.rowHeight = rowHeight
    self.text = text
    self.onChange = onChange
    rowCount = range.count * (repeating ? 200 : 1)
    requestedValue = selected
    accessibilityIdentifier = identifier
    accessibilityLabel = label
    accessibilityValue = text(selected)
    if changed || (!scroll.isDragging && !scroll.isDecelerating && value(selectedRow) != selected) {
      selectedRow = (repeating ? range.count * 100 : 0) + selected - range.lowerBound
      scroll.setContentOffset(CGPoint(x: 0, y: CGFloat(selectedRow) * rowHeight), animated: false)
    }
    configuring = false
    setNeedsLayout()
    render()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    configuring = true
    scroll.frame = bounds
    scroll.contentSize = CGSize(
      width: bounds.width, height: CGFloat(rowCount - 1) * rowHeight + bounds.height)
    if !scroll.isDragging && !scroll.isDecelerating {
      scroll.contentOffset.y = CGFloat(selectedRow) * rowHeight
    }
    configuring = false
    render()
  }
  private func value(_ row: Int) -> Int { range.lowerBound + max(0, row) % range.count }
  private func render() {
    let offset = scroll.contentOffset.y / rowHeight
    let nearest = Int(offset.rounded())
    let radius = max(1, bounds.height / 2)
    for (index, label) in labels.enumerated() {
      let row = nearest + index - labels.count / 2
      let angle = (CGFloat(row) - offset) * rowHeight / radius * 1.2
      label.isHidden = row < 0 || row >= rowCount || abs(angle) > .pi / 2
      if label.isHidden { continue }
      label.text = text(value(row))
      label.font = UIFont(name: "HelveticaNeue-Bold", size: rowHeight * 0.60)
      label.bounds = CGRect(x: 0, y: 0, width: max(0, bounds.width - 12), height: rowHeight)
      label.center = CGPoint(x: bounds.midX, y: bounds.midY + sin(angle) * radius)
      label.transform = CGAffineTransform(scaleX: 1, y: max(0.08, cos(angle)))
      label.alpha = max(0.13, 1 - pow(abs(angle) / (.pi / 2), 2) * 0.87)
    }
  }
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    render()
    guard !configuring else { return }
    let row = min(rowCount - 1, max(0, Int((scrollView.contentOffset.y / rowHeight).rounded())))
    guard row != selectedRow else { return }
    selectedRow = row
    requestedValue = onChange(value(row))
    accessibilityValue = text(requestedValue)
  }
  func scrollViewWillEndDragging(
    _ scrollView: UIScrollView, withVelocity velocity: CGPoint,
    targetContentOffset: UnsafeMutablePointer<CGPoint>
  ) {
    let row = min(
      CGFloat(rowCount - 1), max(0, (targetContentOffset.pointee.y / rowHeight).rounded()))
    targetContentOffset.pointee.y = row * rowHeight
  }
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate { snap() }
  }
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { snap() }
  private func snap() {
    if value(selectedRow) != requestedValue {
      selectedRow =
        (repeating ? (selectedRow / range.count) * range.count : 0)
        + requestedValue - range.lowerBound
    }
    scroll.setContentOffset(
      CGPoint(x: 0, y: CGFloat(selectedRow) * rowHeight),
      animated: !UIAccessibility.isReduceMotionEnabled)
  }
  override func accessibilityIncrement() { adjust(1) }
  override func accessibilityDecrement() { adjust(-1) }
  private func adjust(_ delta: Int) {
    selectedRow = min(rowCount - 1, max(0, selectedRow + delta))
    requestedValue = onChange(value(selectedRow))
    accessibilityValue = text(requestedValue)
    snap()
  }
  func stop() {
    scroll.delegate = nil
    onChange = { $0 }
  }
}
