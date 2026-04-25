//
//  ContentView.swift
//  Timers
//
//  Created by David McKenzie on 4/25/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        MainListView()
    }
}
