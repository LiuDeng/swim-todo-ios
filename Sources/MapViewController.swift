//
//  MapViewController.swift
//  SwimTodo
//
//  Created by Ewan Mellor on 5/10/16.
//  Copyright © 2016 swim.it. All rights reserved.
//

import CCHMapClusterController
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
    var vehicle: VehicleModel

    // Note that this is a cache of vehicle.coordinate rather than a
    // direct call, because we only want to change this when we're ready
    // to animate a batch of changes.
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        return vehicle.routeId
    }

    var subtitle: String? {
        if let speed = vehicle.speedMph {
            return "\(speed) mph"
        }
        else {
            return "Stationary"
        }
    }

    init(vehicle: VehicleModel) {
        self.vehicle = vehicle
        coordinate = vehicle.coordinate
    }

    override func isEqual(object: AnyObject?) -> Bool {
        return object === self
    }
}


class MapViewController: UIViewController, MKMapViewDelegate, MapDownlinkDelegate, CCHMapClusterControllerDelegate {
    @IBOutlet private weak var mapView: MKMapView!

    private var mapClusterController: CCHMapClusterController!

    private var agenciesDownlink: MapDownlink!
    private var routeDownlinks = [String: MapDownlink]()
    private var vehicleDownlinks = [String: MapDownlink]()
    private var vehicleAnnotations = [String: VehicleAnnotation]()

    private var changesInProgress = 0
    private var pendingChanges = [VehicleAnnotation]()
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

        mapClusterController = CCHMapClusterController(mapView: mapView)
        mapClusterController.delegate = self
        mapClusterController.cellSize = 20

        laneProperties.isClientReadOnly = true
        laneProperties.isTransient = true

        let initialLocation = CLLocation(latitude: 37.6547, longitude: -122.4077)
        let initialRadius = CLLocationDistance(11000)
        centerMap(initialLocation, initialRadius, animated: false)

        linkAgencies()
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.navigationBarHidden = false
    }


    private func linkAgencies() {
        let swimClient = SwimTodoGlobals.instance.cityClient
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

        let swimClient = SwimTodoGlobals.instance.cityClient
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

        let swimClient = SwimTodoGlobals.instance.cityClient
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
            pendingChanges.append(anno)
        }
        else {
            let anno = VehicleAnnotation(vehicle: vehicle)
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
            mapClusterController.addAnnotations(pendingAdds, withCompletionHandler: nil)
            pendingAdds.removeAll()
        }
        if pendingRemoves.count > 0 {
            mapClusterController.removeAnnotations(pendingRemoves, withCompletionHandler: nil)
            pendingRemoves.removeAll()
        }

        if pendingChanges.count > 0 {
            let changes = pendingChanges
            pendingChanges.removeAll()
            UIView.animateWithDuration(0.3) {
                for anno in changes {
                    anno.coordinate = anno.vehicle.coordinate
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


    // MARK: - CCHMapClusterControllerDelegate

    func mapClusterController(mapClusterController: CCHMapClusterController!, titleForMapClusterAnnotation mapClusterAnnotation: CCHMapClusterAnnotation!) -> String! {
        let n = mapClusterAnnotation.annotations.count
        if n == 1 {
            let anno = mapClusterAnnotation.annotations.first as! VehicleAnnotation
            return anno.title
        }
        else {
            return nil
        }
    }

    func mapClusterController(mapClusterController: CCHMapClusterController!, subtitleForMapClusterAnnotation mapClusterAnnotation: CCHMapClusterAnnotation!) -> String! {
        let n = mapClusterAnnotation.annotations.count
        if n == 1 {
            let anno = mapClusterAnnotation.annotations.first as! VehicleAnnotation
            return anno.subtitle
        }
        else {
            return nil
        }
    }

    func mapClusterController(mapClusterController: CCHMapClusterController!, willReuseMapClusterAnnotation mapClusterAnnotation: CCHMapClusterAnnotation!) {
        guard let v = mapView.viewForAnnotation(mapClusterAnnotation) as? MapAnnotationView else {
            return
        }
        configureAnnoView(v, mapClusterAnnotation)
    }

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if let clusterAnno = annotation as? CCHMapClusterAnnotation {
            let identifier = "annotationView"
            var v = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MapAnnotationView
            if v == nil {
                v = MapAnnotationView(annotation: clusterAnno, reuseIdentifier: identifier)
                v!.canShowCallout = true
            }
            else {
                v!.annotation = clusterAnno
            }

            configureAnnoView(v!, clusterAnno)

            return v
        }
        else {
            return nil
        }
    }


    private func configureAnnoView(v: MapAnnotationView, _ anno: CCHMapClusterAnnotation) {
        let n = anno.annotations.count
        if n > 1 {
            v.count = n
            v.vehicle = nil
        }
        else {
            v.vehicle = (anno.annotations.first as! VehicleAnnotation).vehicle
        }

    }
}
