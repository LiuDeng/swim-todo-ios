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

private let log = SwiftyBeaver.self


class MapAnnotation: NSObject, MKAnnotation {
    var thing: LocatableModel

    // Note that this is a cache of vehicle.coordinate rather than a
    // direct call, because we only want to change this when we're ready
    // to animate a batch of changes.
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        if let vehicle = thing as? VehicleModel {
            return vehicle.routeId
        }
        else if let atm = thing as? ATMModel {
            return atm.name
        }
        else {
            return nil
        }
    }

    var subtitle: String? {
        if let vehicle = thing as? VehicleModel {
            if let speed = vehicle.speedMph {
                return "\(speed) mph"
            }
            else {
                return "Stationary"
            }
        }
        else if let atm = thing as? ATMModel {
            return atm.address
        }
        else {
            return nil
        }
    }

    init(thing: LocatableModel) {
        self.thing = thing
        coordinate = thing.coordinate
    }
}


class ATMAnnotation: NSObject, MKAnnotation {
    var atm: ATMModel

    // Note that this is a cache of atm.coordinate rather than a
    // direct call, because we only want to change this when we're ready
    // to animate a batch of changes.
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        return atm.name
    }

    var subtitle: String? {
        return atm.address
    }

    init(atm: ATMModel) {
        self.atm = atm
        coordinate = atm.coordinate
    }
}


class MapViewController: UIViewController, MKMapViewDelegate, MapDownlinkDelegate, CCHMapClusterControllerDelegate {
    @IBOutlet private weak var mapView: MKMapView!

    private var mapClusterController: CCHMapClusterController!

    private var agenciesDownlink: MapDownlink!
    private var banksDownlink: MapDownlink!
    private var atms = [String: ATMModel]()
    private var bankDownlinks = [String: MapDownlink]()
    private var atmInfoDownlinks = [String: Downlink]()
    private var routeDownlinks = [String: MapDownlink]()
    private var vehicleDownlinks = [String: MapDownlink]()
    private var mapAnnotations = [String: MapAnnotation]()

    private var changesInProgress = 0
    private var pendingChanges = [MapAnnotation]()
    private var pendingAdds = [MapAnnotation]()
    private var pendingRemoves = [MapAnnotation]()

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
        linkBanks()
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


    private func linkBanks() {
        let swimClient = SwimTodoGlobals.instance.cityClient
        let countryScope = swimClient.scope(node: countryNodeUri)

        let downlink = countryScope.scope(lane: banksLaneUri).syncMap(properties: laneProperties, objectMaker: {
            return BankModel(swimValue: $0)
            }, primaryKey: {
                let id = ($0 as! BankModel).swimId ?? ""
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


    private func linkATM(atm: ATMModel) {
        atms[atm.swimId] = atm

        let swimClient = SwimTodoGlobals.instance.cityClient
        let scope = swimClient.scope(node: SwimUri("atm/\(atm.swimId)")!)

        let downlink = scope.scope(lane: atmInfoLaneUri).sync(properties: laneProperties)
        downlink.addDelegate(self)

        atmInfoDownlinks[atm.swimId] = downlink
    }


    private func linkBank(bank: BankModel) {
        let swimClient = SwimTodoGlobals.instance.cityClient
        let scope = swimClient.scope(node: SwimUri("bank/\(bank.swimId)")!)

        let downlink = scope.scope(lane: atmsLaneUri).syncMap(properties: laneProperties, objectMaker: {
            return ATMModel(swimValue: $0)
            }, primaryKey: {
                let id = ($0 as! ATMModel).swimId ?? ""
                return SwimValue(id)
        })
        downlink.addDelegate(self)

        bankDownlinks[bank.swimId] = downlink
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


    private func updateMapMarker(thing: LocatableModel) {
        SwimAssertOnMainThread()

        addChangeToPending(thing)

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }

    private func addChangeToPending(thing: LocatableModel) {
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


    private func removeMapMarker(thing: LocatableModel) {
        SwimAssertOnMainThread()

        savePendingRemove(thing)

        if changesInProgress == 0 {
            applyAllChanges()
        }
    }


    private func savePendingRemove(vehicle: LocatableModel) {
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


    // MARK: - DownlinkDelegate

    func swimDownlink(downlink: Downlink, events: [EventMessage]) {
        guard downlink.laneUri == atmInfoLaneUri else {
            return
        }

        for event in events {
            let atmId = String(event.node.path).componentsSeparatedByString("/").last!
            guard let atm = atms[atmId] else {
                log.warning("Ignoring ATM event for ATM that we don't have \(event)!")
                continue
            }

            atm.swim_updateWithSwimValue(event.body)
            updateMapMarker(atm)
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
        else if let thing = object as? LocatableModel {
            updateMapMarker(thing)
        }
    }

    func swimMapDownlink(downlink: MapDownlink, didUpdate object: SwimModelProtocolBase, forKey key: SwimValue) {
        SwimAssertOnMainThread()

        if let thing = object as? LocatableModel {
            updateMapMarker(thing)
        }
    }

    func swimMapDownlink(downlink: MapDownlink, didRemove object: SwimModelProtocolBase, forKey key: SwimValue) {
        SwimAssertOnMainThread()

        if let thing = object as? LocatableModel {
            removeMapMarker(thing)
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
}
