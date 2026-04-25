import SwiftUI
import UIKit

struct CountdownPickerView: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)),
                         for: .valueChanged)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        uiView.countDownDuration = duration
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: CountdownPickerView
        init(_ parent: CountdownPickerView) { self.parent = parent }

        @objc func changed(_ sender: UIDatePicker) {
            parent.duration = sender.countDownDuration
        }
    }
}
