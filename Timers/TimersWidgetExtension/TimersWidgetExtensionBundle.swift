//
//  TimersWidgetExtensionBundle.swift
//  TimersWidgetExtension
//
//  Created by David McKenzie on 4/25/26.
//

import WidgetKit
import SwiftUI

@main
struct TimersWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        TimersWidgetExtension()
        TimersWidgetExtensionControl()
        TimersLiveActivity()
    }
}
