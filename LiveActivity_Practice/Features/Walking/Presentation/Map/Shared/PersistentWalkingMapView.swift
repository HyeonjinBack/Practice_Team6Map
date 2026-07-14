//  PersistentWalkingMapView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import SwiftUI

/// 지도 SDK의 네이티브 뷰를 최초 한 번만 만들고 재사용한다.
/// 특히 TMap/VSM은 TMapView 재생성 시 내부 그래픽 캐시가 즉시 반환되지 않으므로
/// 런타임 전환은 뷰 교체가 아닌 표시 상태 변경으로 처리한다.
struct PersistentWalkingMapView<AppleEngine: WalkingMapEngine, TMapEngine: WalkingMapEngine, NaverEngine: WalkingMapEngine>: View {
    let selectedProvider: MapProviderKind
    let state: MapPresentationState
    let appleEngine: AppleEngine
    let tmapEngine: TMapEngine
    let naverEngine: NaverEngine

    @State private var loadedProviders: Set<MapProviderKind>

    init(
        selectedProvider: MapProviderKind,
        state: MapPresentationState,
        appleEngine: AppleEngine,
        tmapEngine: TMapEngine,
        naverEngine: NaverEngine
    ) {
        self.selectedProvider = selectedProvider
        self.state = state
        self.appleEngine = appleEngine
        self.tmapEngine = tmapEngine
        self.naverEngine = naverEngine
        _loadedProviders = State(initialValue: [selectedProvider])
    }

    var body: some View {
        ZStack {
            if loadedProviders.contains(.apple) || selectedProvider == .apple {
                appleEngine.makeMapView(state: state)
                    .opacity(selectedProvider == .apple ? 1 : 0)
                    .allowsHitTesting(selectedProvider == .apple)
                    .accessibilityHidden(selectedProvider != .apple)
                    .zIndex(selectedProvider == .apple ? 1 : 0)
            }

            if loadedProviders.contains(.tmap) || selectedProvider == .tmap {
                tmapEngine.makeMapView(state: state)
                    .opacity(selectedProvider == .tmap ? 1 : 0)
                    .allowsHitTesting(selectedProvider == .tmap)
                    .accessibilityHidden(selectedProvider != .tmap)
                    .zIndex(selectedProvider == .tmap ? 1 : 0)
            }

            if loadedProviders.contains(.naver) || selectedProvider == .naver {
                naverEngine.makeMapView(state: state)
                    .opacity(selectedProvider == .naver ? 1 : 0)
                    .allowsHitTesting(selectedProvider == .naver)
                    .accessibilityHidden(selectedProvider != .naver)
                    .zIndex(selectedProvider == .naver ? 1 : 0)
            }
        }
        .onChange(of: selectedProvider) { _, provider in
            loadedProviders.insert(provider)
        }
    }
}
