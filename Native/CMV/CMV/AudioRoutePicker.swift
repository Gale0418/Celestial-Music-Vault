#if os(iOS)
import AVKit
import SwiftUI

/// System route selection for the app's current audio session.
/// AVAudioEngine already plays through AVAudioSession's selected route.
struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.accessibilityLabel = AppLanguage.localized("選擇音訊輸出裝置")
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.tintColor = UIColor.label
        picker.activeTintColor = UIColor.label
        picker.accessibilityLabel = AppLanguage.localized("選擇音訊輸出裝置")
    }
}
#endif
