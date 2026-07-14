//  NaverMapRouteView.swift
//  LiveActivity_Practice
//
//  Created by 현진백 on 2026/07/14.
//

import CoreLocation
import NMapsMap
import SwiftUI
import UIKit

struct NaverMapRouteView: UIViewRepresentable {
    let state: MapPresentationState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)
        let mapView = naverMapView.mapView
        naverMapView.showCompass = false
        naverMapView.showScaleBar = false
        naverMapView.showZoomControls = false
        naverMapView.showLocationButton = false
        mapView.positionMode = .normal

        let locationButton = NMFLocationButton()
        locationButton.mapView = mapView
        locationButton.translatesAutoresizingMaskIntoConstraints = false
        locationButton.accessibilityLabel = "내 위치 찾기"
        naverMapView.addSubview(locationButton)
        NSLayoutConstraint.activate([
            locationButton.trailingAnchor.constraint(equalTo: naverMapView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            locationButton.widthAnchor.constraint(equalToConstant: 48),
            locationButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        context.coordinator.locationButtonBottomConstraint = locationButton.bottomAnchor.constraint(
            equalTo: naverMapView.safeAreaLayoutGuide.bottomAnchor,
            constant: state.route == nil ? -24 : -250
        )
        context.coordinator.locationButtonBottomConstraint?.isActive = true
        context.coordinator.locationButton = locationButton
        context.coordinator.prepareInitialCamera(location: state.currentLocation, on: mapView)
        return naverMapView
    }

    func updateUIView(_ naverMapView: NMFNaverMapView, context: Context) {
        context.coordinator.update(state: state, on: naverMapView.mapView)
    }

    static func dismantleUIView(_ naverMapView: NMFNaverMapView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class Coordinator {
        weak var locationButton: NMFLocationButton?
        var locationButtonBottomConstraint: NSLayoutConstraint?
        private var renderedRoute: WalkingRoute?
        private var lastCameraCommandID: Int?
        private var hasCenteredInitialLocation = false
        private var routePath: NMFPath?
        private var routeMarkers: [NMFMarker] = []
        private var landmarkAreas: [NMFCircleOverlay] = []
        private var landmarkConnectors: [NMFPolylineOverlay] = []

        func update(state: MapPresentationState, on mapView: NMFMapView) {
            updateLocationOverlay(
                location: state.currentLocation,
                heading: state.currentHeading,
                on: mapView
            )

            if !hasCenteredInitialLocation, let location = state.currentLocation {
                moveCamera(to: location, zoom: 15, on: mapView, animated: false)
                hasCenteredInitialLocation = true
            }

            if renderedRoute != state.route {
                render(route: state.route, on: mapView)
            }
            updateLocationButtonLayout(hasRoute: state.route != nil)

            guard let command = state.cameraCommand, command.id != lastCameraCommandID else { return }
            switch command.target {
            case .userLocation:
                guard let location = state.currentLocation else { return }
                moveCamera(to: location, zoom: 15, on: mapView, animated: true)
                hasCenteredInitialLocation = true
            case .route:
                if let route = state.route, route.path.count >= 2 {
                    let points = route.path.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }
                    let update = NMFCameraUpdate(fit: NMGLatLngBounds(latLngs: points), paddingInsets: UIEdgeInsets(top: 180, left: 45, bottom: 230, right: 45))
                    update.animation = .easeOut
                    mapView.moveCamera(update)
                }
            }
            lastCameraCommandID = command.id
        }

        func prepareInitialCamera(location: Coordinate?, on mapView: NMFMapView) {
            guard let location else { return }
            moveCamera(to: location, zoom: 15, on: mapView, animated: false)
            hasCenteredInitialLocation = true
        }

        func tearDown() {
            locationButton?.mapView = nil
            locationButtonBottomConstraint?.isActive = false
            routePath?.mapView = nil
            routeMarkers.forEach { $0.mapView = nil }
            landmarkAreas.forEach { $0.mapView = nil }
            landmarkConnectors.forEach { $0.mapView = nil }
            routePath = nil
            routeMarkers.removeAll()
            landmarkAreas.removeAll()
            landmarkConnectors.removeAll()
        }

        private func updateLocationButtonLayout(hasRoute: Bool) {
            let targetConstant: CGFloat = hasRoute ? -250 : -24
            guard locationButtonBottomConstraint?.constant != targetConstant else { return }
            locationButtonBottomConstraint?.constant = targetConstant
            locationButton?.superview?.layoutIfNeeded()
        }

        private func render(route: WalkingRoute?, on mapView: NMFMapView) {
            routePath?.mapView = nil
            routeMarkers.forEach { $0.mapView = nil }
            landmarkAreas.forEach { $0.mapView = nil }
            landmarkConnectors.forEach { $0.mapView = nil }
            routePath = nil
            routeMarkers.removeAll()
            landmarkAreas.removeAll()
            landmarkConnectors.removeAll()
            renderedRoute = route

            guard let route, route.path.count >= 2 else { return }
            let points = route.path.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }
            let path = NMFPath(points: points)
            path?.color = .systemBlue
            path?.outlineColor = .white
            path?.width = 8
            path?.outlineWidth = 2
            path?.mapView = mapView
            routePath = path

            if let start = route.path.first {
                addMarker(title: "출발지", coordinate: start, color: .systemGreen, on: mapView)
            }
            if let destination = route.path.last {
                addMarker(title: "목적지", coordinate: destination, color: .systemRed, on: mapView)
            }

            for (offset, selection) in route.mapLandmarkSelections().enumerated() {
                addLandmark(
                    index: offset + 1,
                    selection: selection,
                    on: mapView
                )
            }
        }

        private func addMarker(title: String, coordinate: Coordinate, color: UIColor, on mapView: NMFMapView) {
            let marker = NMFMarker(position: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
            marker.captionText = title
            marker.iconTintColor = color
            marker.mapView = mapView
            routeMarkers.append(marker)
        }

        private func addLandmark(
            index: Int,
            selection: MapLandmarkSelection,
            on mapView: NMFMapView
        ) {
            let landmarkPosition = NMGLatLng(
                lat: selection.landmark.coordinate.latitude,
                lng: selection.landmark.coordinate.longitude
            )
            let maneuverPosition = NMGLatLng(
                lat: selection.maneuver.coordinate.latitude,
                lng: selection.maneuver.coordinate.longitude
            )

            let area = NMFCircleOverlay()
            area.center = landmarkPosition
            area.radius = 15
            area.fillColor = UIColor.systemOrange.withAlphaComponent(0.32)
            area.outlineColor = UIColor.systemOrange.withAlphaComponent(0.9)
            area.outlineWidth = 2
            area.mapView = mapView
            landmarkAreas.append(area)

            if let connector = NMFPolylineOverlay([maneuverPosition, landmarkPosition]) {
                connector.color = UIColor.systemOrange.withAlphaComponent(0.75)
                connector.width = 2
                connector.pattern = [4, 4]
                connector.capType = .round
                connector.joinType = .round
                connector.mapView = mapView
                landmarkConnectors.append(connector)
            }

            let turnMarker = NMFMarker(position: maneuverPosition)
            let turnConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            if let turnImage = UIImage(
                systemName: selection.maneuver.turn.symbolName,
                withConfiguration: turnConfiguration
            )?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal) {
                turnMarker.iconImage = NMFOverlayImage(image: turnImage)
            }
            turnMarker.width = 24
            turnMarker.height = 24
            turnMarker.anchor = CGPoint(x: 0.5, y: 0.5)
            turnMarker.zIndex = 9_000
            turnMarker.mapView = mapView
            routeMarkers.append(turnMarker)

            let landmarkMarker = NMFMarker(position: landmarkPosition)
            landmarkMarker.iconImage = NMFOverlayImage(
                image: Self.landmarkBubbleImage(index: index, name: selection.landmark.name),
                reuseIdentifier: "naver-landmark-\(selection.landmark.id)-\(index)"
            )
            landmarkMarker.width = 148
            landmarkMarker.height = 45
            landmarkMarker.anchor = CGPoint(x: 0.5, y: 1)
            landmarkMarker.isForceShowIcon = true
            landmarkMarker.isHideCollidedSymbols = true
            landmarkMarker.zIndex = 10_000 + index
            landmarkMarker.mapView = mapView
            routeMarkers.append(landmarkMarker)
        }

        private static func landmarkBubbleImage(index: Int, name: String) -> UIImage {
            let bubble = LandmarkBubbleView(index: index, name: name)
            bubble.layoutIfNeeded()
            return UIGraphicsImageRenderer(bounds: bubble.bounds).image { context in
                bubble.layer.render(in: context.cgContext)
            }
        }

        private func updateLocationOverlay(
            location: Coordinate?,
            heading: CLLocationDirection?,
            on mapView: NMFMapView
        ) {
            let overlay = mapView.locationOverlay
            guard let location else {
                overlay.hidden = true
                return
            }

            overlay.hidden = false
            overlay.location = NMGLatLng(lat: location.latitude, lng: location.longitude)
            overlay.heading = CGFloat(heading ?? 0)
        }

        func moveCamera(
            to coordinate: Coordinate,
            zoom: Double,
            on mapView: NMFMapView,
            animated: Bool
        ) {
            let update = NMFCameraUpdate(
                scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude),
                zoomTo: zoom
            )
            update.animation = animated ? .easeOut : .none
            mapView.moveCamera(update)
        }

    }
}
