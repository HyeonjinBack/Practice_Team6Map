//  AppleMapEngine.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

struct AppleMapEngine: WalkingMapEngine {
    func makeMapView(state: MapPresentationState) -> some View {
        AppleMapRouteView(state: state)
    }
}
