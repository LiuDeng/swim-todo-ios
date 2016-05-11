//
//  MapViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import MapKit
import SwiftyBeaver
import SwimSwift
import UIKit


private let countryNodeUri: SwimUri = "country/us"
private let agenciesLaneUri: SwimUri = "country/agencies"
private let routesLaneUri: SwimUri = "agency/routes"
private let vehiclesLaneUri: SwimUri = "route/vehicles"

private let log = SwiftyBeaver.self


class VehicleAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    override func isEqual(object: AnyObject?) -> Bool {
        return object === self
    }
}


class MapViewController: UIViewController, MKMapViewDelegate, MapDownlinkDelegate {
    @IBOutlet private weak var mapView: MKMapView!

    private var agenciesDownlink: MapDownlink!
    private var routeDownlinks = [String: MapDownlink]()
    private var vehicleDownlinks = [String: MapDownlink]()
    private var vehicleAnnotations = [String: VehicleAnnotation]()

    private var changesInProgress = 0
    private var pendingChanges = [VehicleAnnotation: CLLocationCoordinate2D]()
    private var pendingAdds = [VehicleAnnotation]()
    private var pendingRemoves = [VehicleAnnotation]()

    private let laneProperties = LaneProperties()

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        laneProperties.isClientReadOnly = true
        laneProperties.isTransient = true

        let initialLocation = CLLocation(latitude: 37.6547, longitude: -122.4077)
        let initialRadius = CLLocationDistance(11000)
        centerMap(initialLocation, initialRadius, animated: false)

        linkAgencies()
    }


    private func linkAgencies() {
        let swimClient = SwimClient.sharedInstance
        let countryScope = swimClient.scope(node: countryNodeUri)

        let downlink = countryScope.scope(lane: agenciesLaneUri).syncMap(properties: laneProperties, objectMaker: {
            return AgencyModel(swimValue: $0)
        }, primaryKey: {
            let id = ($0 as! AgencyModel).swimId ?? ""
            return SwimValue(id)
        })
        downlink.addDelegate(self)
        agenciesDownlink = downlink
    }


    private func centerMap(location: CLLocation, _ radius: CLLocationDistance, animated: Bool) {
        let radius2 = radius * 2
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, radius2, radius2)
        mapView.setRegion(coordinateRegion, animated: animated)
    }


    private func linkAgency(agency: AgencyModel) {
        SwimAssertOnMainThread()
        log.debug("Linking with agency \(agency.swimId ?? "Missing ID") \(agency.name ?? "")")

        let swimClient = SwimClient.sharedInstance
        let agencyScope = swimClient.scope(node: SwimUri("agency/\(agency.swimId)")!)

        let downlink = agencyScope.scope(lane: routesLaneUri).syncMap(properties: laneProperties, objectMaker: {
            return RouteModel(swimValue: $0)
        }, primaryKey: {
            let id = ($0 as! RouteModel).swimId ?? ""
            return SwimValue(id)
        })
        downlink.addDelegate(self)

        routeDownlinks[agency.swimId] = downlink
    }


    private func linkRoute(route: RouteModel) {
        SwimAssertOnMainThread()
        log.debug("Linking with route \(route.swimId ?? "Missing ID")")

        let swimClient = SwimClient.sharedInstance
        let routeScope = swimClient.scope(node: SwimUri("route/\(route.swimId)")!)

        let downlink = routeScope.scope(lane: vehiclesLaneUri).syncMap(properties: laneProperties, objectMaker: {
            return VehicleModel(swimValue: $0)
        }, primaryKey: {
            let id = ($0 as! VehicleModel).swimId ?? ""
            return SwimValue(id)
        })
        downlink.addDelegate(self)

        vehicleDownlinks[route.swimId] = downlink
    }


    private func updateVehicleMarker(vehicle: VehicleModel) {
        SwimAssertOnMainThread()

        addChangeToPending(vehicle)

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }

    private func addChangeToPending(vehicle: VehicleModel) {
        guard let lat = vehicle.latitude, long = vehicle.longitude else {
            return
        }
        log.verbose("Vehicle \(vehicle.swimId) moved to \(lat), \(long)")

        let coord = CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(long))
        guard CLLocationCoordinate2DIsValid(coord) else {
            log.warning("Ignoring invalid location \(coord) for vehicle \(vehicle.swimId)")
            return
        }
        if let anno = vehicleAnnotations[vehicle.swimId] {
            pendingChanges[anno] = coord
        }
        else {
            let anno = VehicleAnnotation(coordinate: coord)
            vehicleAnnotations[vehicle.swimId] = anno
            pendingAdds.append(anno)
        }
    }


    private func removeVehicleMarker(vehicle: VehicleModel) {
        SwimAssertOnMainThread()

        savePendingRemove(vehicle)

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }


    private func savePendingRemove(vehicle: VehicleModel) {
        SwimAssertOnMainThread()

        if let anno = vehicleAnnotations[vehicle.swimId] {
            pendingRemoves.append(anno)
        }
    }


    private func applyAllChanges() {
        SwimAssertOnMainThread()

        if pendingAdds.count > 0 {
            mapView.addAnnotations(pendingAdds)
            pendingAdds.removeAll()
        }
        if pendingRemoves.count > 0 {
            mapView.removeAnnotations(pendingRemoves)
            pendingRemoves.removeAll()
        }

        if pendingChanges.count > 0 {
            let changes = pendingChanges
            pendingChanges.removeAll()
            UIView.animateWithDuration(0.3) {
                for (anno, coord) in changes {
                    anno.coordinate = coord
                }
            }
        }
    }


    // MARK: - MapDownlinkDelegate

    func swimMapDownlinkWillChange(downlink: MapDownlink) {
        SwimAssertOnMainThread()

        if vehicleDownlinks.contains({ (_, d) in d === downlink }) {
            changesInProgress += 1
        }
    }

    func swimMapDownlinkDidChange(downlink: MapDownlink) {
        SwimAssertOnMainThread()

        if vehicleDownlinks.contains({ (_, d) in d === downlink }) {
            changesInProgress -= 1
        }

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }

    func swimMapDownlink(_: MapDownlink, didSet object: SwimModelProtocolBase, forKey _: SwimValue) {
        SwimAssertOnMainThread()

        if let agency = object as? AgencyModel {
            linkAgency(agency)
        }
        else if let route = object as? RouteModel {
            linkRoute(route)
        }
        else if let vehicle = object as? VehicleModel {
            updateVehicleMarker(vehicle)
        }
    }

    func swimMapDownlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue) {
        SwimAssertOnMainThread()

        if let vehicle = object as? VehicleModel {
            updateVehicleMarker(vehicle)
        }
    }

    func swimMapDownlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue) {
        SwimAssertOnMainThread()

        if let vehicle = object as? VehicleModel {
            removeVehicleMarker(vehicle)
        }
    }
}
