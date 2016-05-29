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
private let banksLaneUri: SwimUri = "country/banks"
private let atmsLaneUri: SwimUri = "bank/atms"
private let atmInfoLaneUri: SwimUri = "atm/info"
private let routesLaneUri: SwimUri = "agency/routes"
private let vehiclesLaneUri: SwimUri = "route/vehicles"
private let routeConfigLaneUri: SwimUri = "route/config"

private func agencyUri(agency: AgencyModel) -> SwimUri {
    return SwimUri("agency/\(agency.swimId)")!
}

private func atmUri(atm: ATMModel) -> SwimUri {
    return SwimUri("atm/\(atm.swimId)")!
}

private func bankUri(bank: BankModel) -> SwimUri {
    return SwimUri("bank/\(bank.swimId)")!
}

private func routeUri(route: RouteModel) -> SwimUri {
    return SwimUri("route/\(route.swimId)")!
}


private let log = SwiftyBeaver.self


class MapViewController: UIViewController, MKMapViewDelegate, MapDownlinkDelegate, ValueDownlinkDelegate, CCHMapClusterControllerDelegate {
    @IBOutlet private weak var mapView: MKMapView!

    private var mapClusterController: CCHMapClusterController!

    private var mapAnnotations = [String: MapAnnotation]()

    private var mapRoutes = [String: MKPolyline]()
    private var selectedRoute: String?
    private var visibleRouteOverlay: MKPolyline?

    private var changesInProgress = 0
    private var pendingChanges = [MapAnnotation]()
    private var pendingAdds = [MapAnnotation]()
    private var pendingRemoves = [MapAnnotation]()

    private var agenciesDownlink: MapDownlink!
    private var banksDownlink: MapDownlink!
    private var bankDownlinks = [String: MapDownlink]()
    private var atmInfoDownlinks = [String: ValueDownlink]()
    private var routeDownlinks = [String: MapDownlink]()
    private var routeConfigDownlinks = [String: ValueDownlink]()
    private var vehicleDownlinks = [String: MapDownlink]()

    private var atms = [String: ATMModel]()
    private var routes = [String: RouteModel]()
    private var routeDetail = [String: RouteDetailModel]()

    private let laneProperties = LaneProperties()

    private var swimClient: SwimClient {
        return SwimTodoGlobals.instance.cityClient
    }

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
        linkBanks()
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.navigationBarHidden = false
    }


    private func linkAgencies() {
        let scope = swimClient.scope(node: countryNodeUri, lane: agenciesLaneUri)
        let downlink = scope.syncMap(properties: laneProperties, objectMaker: {
            return AgencyModel(swimValue: $0)
        })
        downlink.addDelegate(self)
        agenciesDownlink = downlink
    }


    private func linkBanks() {
        let scope = swimClient.scope(node: countryNodeUri,lane: banksLaneUri)
        let downlink = scope.syncMap(properties: laneProperties, objectMaker: {
            return BankModel(swimValue: $0)
        })
        downlink.addDelegate(self)
        agenciesDownlink = downlink
    }


    private func linkAgency(agency: AgencyModel) {
        let scope = swimClient.scope(node: agencyUri(agency), lane: routesLaneUri)
        let downlink = scope.syncMap(properties: laneProperties, objectMaker: {
            return RouteModel(swimValue: $0)
        })
        downlink.addDelegate(self)

        routeDownlinks[agency.swimId] = downlink
    }


    private func linkATM(atm: ATMModel) {
        atms[atm.swimId] = atm

        let scope = swimClient.scope(node: atmUri(atm), lane: atmInfoLaneUri)
        let downlink = scope.syncValue(properties: laneProperties) {
            return ATMModel(swimValue: $0)
        }
        downlink.addDelegate(self)

        atmInfoDownlinks[atm.swimId] = downlink
    }


    private func linkBank(bank: BankModel) {
        let scope = swimClient.scope(node: bankUri(bank), lane: atmsLaneUri)
        let downlink = scope.syncMap(properties: laneProperties, objectMaker: {
            return ATMModel(swimValue: $0)
        })
        downlink.addDelegate(self)

        bankDownlinks[bank.swimId] = downlink
    }


    private func linkRoute(route: RouteModel) {
        routes[route.swimId] = route

        linkRouteVehicles(route)
    }

    private func linkRouteVehicles(route: RouteModel) {
        let scope = swimClient.scope(node: routeUri(route), lane: vehiclesLaneUri)
        let downlink = scope.syncMap(properties: laneProperties, objectMaker: {
            return VehicleModel(swimValue: $0)
        })
        downlink.addDelegate(self)

        vehicleDownlinks[route.swimId] = downlink
    }


    private func linkRouteConfig(route: RouteModel) {
        log.verbose("Linking to \(route.swimId) config")

        let scope = swimClient.scope(node: routeUri(route), lane: routeConfigLaneUri)
        let downlink = scope.syncValue(properties: laneProperties, objectMaker: {
            return RouteDetailModel(swimValue: $0)
        })
        downlink.addDelegate(self)

        routeConfigDownlinks[route.swimId] = downlink
    }


    private func centerMap(location: CLLocation, _ radius: CLLocationDistance, animated: Bool) {
        let radius2 = radius * 2
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, radius2, radius2)
        mapView.setRegion(coordinateRegion, animated: animated)
    }


    private func updateMapMarker(thing: SwimLatLongModel) {
        SwimAssertOnMainThread()

        addChangeToPending(thing)

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }

    private func addChangeToPending(thing: SwimLatLongModel) {
        guard let lat = thing.latitude, long = thing.longitude else {
            return
        }
        log.verbose("Thing \(thing.swimId) moved to \(lat), \(long)")

        let coord = CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(long))
        guard CLLocationCoordinate2DIsValid(coord) else {
            log.warning("Ignoring invalid location \(coord) for vehicle \(thing.swimId)")
            return
        }
        if let anno = mapAnnotations[thing.swimId] {
            pendingChanges.append(anno)
        }
        else {
            let anno = MapAnnotation(thing: thing)
            mapAnnotations[thing.swimId] = anno
            pendingAdds.append(anno)
        }
    }


    private func removeMapMarker(thing: SwimLatLongModel) {
        SwimAssertOnMainThread()

        savePendingRemove(thing)

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }


    private func savePendingRemove(vehicle: SwimLatLongModel) {
        SwimAssertOnMainThread()

        if let anno = mapAnnotations[vehicle.swimId] {
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
                    anno.coordinate = anno.thing.coordinate
                }
            }
        }
    }


    private func toggleVisibleRoute(route: RouteModel) {
        let routeId = route.swimId

        if selectedRoute == routeId {
            if visibleRouteOverlay == nil {
                // Second tap on the same route before we've managed to
                // load the data.  Ignore.
            }
            else {
                // Toggle the visible overlay off.

                mapView.removeOverlay(visibleRouteOverlay!)
                selectedRoute = nil
                visibleRouteOverlay = nil
            }
        }
        else {
            // Switching from one route to another, or selecting one
            // for the first time.

            selectedRoute = routeId

            if let _ = routeConfigDownlinks[routeId] {
                // We're linked, we just need to show the line if we already
                // have the data.  Otherwise, it's coming any moment now.
                if let detail = routeDetail[routeId] {
                    setRouteOverlay(detail)
                }
            }
            else {
                // We're not linked, so link.
                linkRouteConfig(route)
            }
        }
    }


    private func setRouteOverlay(route: RouteDetailModel) {
        if visibleRouteOverlay != nil {
            mapView.removeOverlay(visibleRouteOverlay!)
            visibleRouteOverlay = nil
        }

        if route.stops.count == 0 {
            return
        }
        var points = route.stops.map { return $0.coordinate }
        let poly = MKPolyline(coordinates: &points, count: points.count)
        mapView.addOverlay(poly)
        visibleRouteOverlay = poly
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
        else if let atm = object as? ATMModel {
            linkATM(atm)
            updateMapMarker(atm)
        }
        else if let bank = object as? BankModel {
            linkBank(bank)
        }
        else if let route = object as? RouteModel {
            linkRoute(route)
        }
        else if let thing = object as? SwimLatLongModel {
            updateMapMarker(thing)
        }
    }

    func swimMapDownlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue) {
        if let thing = object as? SwimLatLongModel {
            updateMapMarker(thing)
        }
    }

    func swimMapDownlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue) {
        if let thing = object as? SwimLatLongModel {
            removeMapMarker(thing)
        }
    }


    // MARK: - ValueDownlinkDelegate

    func swimValueDownlink(downlink: ValueDownlink, didUpdate object: SwimModelProtocolBase) {
        if let route = object as? RouteDetailModel {
            log.verbose("Received route detail \(route.swimId)")

            routeDetail[route.swimId] = route

            let routeId = String(downlink.nodeUri).componentsSeparatedByString("/").last!
            if selectedRoute == routeId {
                setRouteOverlay(route)
            }
        }
        else if let obj = object as? SwimLatLongModel {
            updateMapMarker(obj)
        }
        else {
            preconditionFailure()
        }
    }


    // MARK: - CCHMapClusterControllerDelegate

    func mapClusterController(mapClusterController: CCHMapClusterController!, titleForMapClusterAnnotation mapClusterAnnotation: CCHMapClusterAnnotation!) -> String! {
        let n = mapClusterAnnotation.annotations.count
        if n == 1 {
            let anno = mapClusterAnnotation.annotations.first as! MapAnnotation
            return anno.title
        }
        else {
            return nil
        }
    }

    func mapClusterController(mapClusterController: CCHMapClusterController!, subtitleForMapClusterAnnotation mapClusterAnnotation: CCHMapClusterAnnotation!) -> String! {
        let n = mapClusterAnnotation.annotations.count
        if n == 1 {
            let anno = mapClusterAnnotation.annotations.first as! MapAnnotation
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
        }
        else {
            let thing = (anno.annotations.first as! MapAnnotation).thing
            if let vehicle = thing as? VehicleModel {
                v.vehicle = vehicle
            }
            else if let atm = thing as? ATMModel {
                v.atm = atm
            }
            else {
                preconditionFailure()
            }
        }
    }


    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        guard let view = view as? MapAnnotationView else {
            preconditionFailure()
        }

        guard let vehicle = view.vehicle else {
            return
        }

        let fullRouteId = "\(vehicle.agencyId!)-\(vehicle.routeId!)"
        toggleVisibleRoute(routes[fullRouteId]!)
    }


    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.st_route()
        return renderer
    }
}
