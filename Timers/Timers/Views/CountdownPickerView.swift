import SwiftUI
import UIKit

struct CountdownPickerView: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        let total = Int(duration)
        let h = min(total / 3600, 23)
        let m = min((total % 3600) / 60, 59)
        let s = total % 60
        uiView.selectRow(h, inComponent: 0, animated: false)
        uiView.selectRow(m, inComponent: 1, animated: false)
        uiView.selectRow(s, inComponent: 2, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: CountdownPickerView
        private let units = ["hours", "min", "sec"]
        private let counts = [24, 60, 60]

        init(_ parent: CountdownPickerView) { self.parent = parent }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 3 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            counts[component]
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 40 }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int,
                        reusing view: UIView?) -> UIView {
            let container = UIView()

            let numLabel = UILabel()
            numLabel.text = "\(row)"
            numLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
            numLabel.textAlignment = .right
            numLabel.translatesAutoresizingMaskIntoConstraints = false

            let unitLabel = UILabel()
            unitLabel.text = units[component]
            unitLabel.font = .systemFont(ofSize: 17, weight: .regular)
            unitLabel.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(numLabel)
            container.addSubview(unitLabel)

            NSLayoutConstraint.activate([
                numLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                unitLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                numLabel.widthAnchor.constraint(equalToConstant: 40),
                numLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                unitLabel.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 6),
                unitLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
            ])

            return container
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let h = pickerView.selectedRow(inComponent: 0)
            let m = pickerView.selectedRow(inComponent: 1)
            let s = pickerView.selectedRow(inComponent: 2)
            parent.duration = TimeInterval(h * 3600 + m * 60 + s)
        }
    }
}
