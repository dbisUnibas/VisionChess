//
//  GameViewModel.swift
//  VisionChess
//
//  Created by Tim Bachmann on 10.03.2025.
//

import SwiftUI
import ARKit
import RealityKit
import RealityKitContent
import Combine
import GroupActivities

@MainActor
class GameViewModel {
    var dataSource: PlaneAnchoringDataSource?
    var appModel: AppModel?
    
    private(set) var currentPixelBuffer: CVPixelBuffer?
    private var objectDetectionManager: ChessPieceDetectionManager?
    private var objectDetectionPredictionSubscription: AnyCancellable?

    private let cameraFrameProvider = CameraFrameProvider()
    private let worldTracking = WorldTrackingProvider()
    private let planeDetection = PlaneDetectionProvider()
    
    private var arInterface: ARKitInterface
    private var planeAnchorHandler: PlaneAnchorHandler?
    private var worldAnchors: [UUID:WorldAnchor] = [:]
    private let placedObjectsOffsetOnPlanes: Float = 0.0001
    
    var deviceAnchorPresent = false
    var planeAnchorsPresent = false
    var boardPlaced: Bool = false
    var pointersPlaced: Int = 0
    

    init(appModel: AppModel, dataSource: PlaneAnchoringDataSource) {
        print("Initializing GameViewModel")
        self.appModel = appModel
        self.dataSource = dataSource
        
        if let activeController = appModel.activeController {
            planeAnchorHandler = .init(rootEntity: activeController.contentEntity)
        }
        arInterface = .init()
        
        self.objectDetectionManager = .init()
        
        objectDetectionPredictionSubscription = objectDetectionManager?.predictionsSubject
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
            .sink(receiveValue: { prediction in
                self.appModel?.activeController?.update(prediction: prediction)
            })
    }

    func prepare() {
        Task {
            await runARKitSession()
        }
    }

    func toggle(entity: Entity, isEnabled: Bool, animated: Bool = true) {
        if isEnabled {
            entity.isEnabled = true
        }
    }

    func runARKitSession() async {
        if let activeController = appModel?.activeController {
            if activeController.game.mode == .mixed {
                guard CameraFrameProvider.isSupported else {
                    print("CameraFrameProvider not supported.")
                    return
                }
                let formats = CameraVideoFormat.supportedVideoFormats(for: .main, cameraPositions: [.left])
                await arInterface.beginSession(world: worldTracking, plane: planeDetection, camera: cameraFrameProvider)
                
                if let updates = cameraFrameProvider.cameraFrameUpdates(for: formats.last!) {
                    for await update in updates {
                        guard
                            appModel?.activeController?.localPlayer.isPlaying ?? false,
                            let mainCameraSample = update.sample(for: .left)
                        else {
                            continue
                        }
                        let currentPixelBuffer = mainCameraSample.pixelBuffer
                        objectDetectionManager?.detectUsingVision(
                            pixelBuffer: currentPixelBuffer,
                            isARKitBuffer: true
                        )
                    }
                }
            } else {
                await arInterface.beginSession(world: worldTracking, plane: planeDetection)
            }
        }
    }

    func processDeviceAnchorUpdates() async {
        await run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }

    func processWorldAnchorUpdates() async {
        for await anchorUpdate in worldTracking.anchorUpdates {
            process(anchorUpdate)
        }
    }

    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        
        deviceAnchorPresent = deviceAnchor != nil
        planeAnchorsPresent = !(planeAnchorHandler?.planeAnchors.isEmpty ?? false)
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        
        await updatePlacementLocation(deviceAnchor)
    }

    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        if !boardPlaced {
            if let activeController = appModel?.activeController {
                activeController.deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
                let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform.gravityAligned
                
                // Determine a placement location on planes in front of the device by casting a ray.
                
                // Cast the ray from the device origin.
                let origin: SIMD3<Float> = activeController.raycastOrigin.transformMatrix(relativeTo: nil).translation
                
                // Cast the ray along the negative z-axis of the device anchor, but with a slight downward angle.
                // (The downward angle is configurable using the `raycastOrigin` orientation.)
                let direction: SIMD3<Float> =  -activeController.raycastOrigin.transformMatrix(relativeTo: nil).zAxis
                
                // Only consider raycast results that are within 0.2 to 3 meters from the device.
                let minDistance: Float = 0.2
                let maxDistance: Float = 3
                
                // Only raycast against horizontal planes.
                let collisionMask = PlaneAnchor.allPlanesCollisionGroup
                
                var originFromPointOnPlaneTransform: float4x4? = nil
                if let result = activeController.contentEntity.scene?.raycast(origin: origin, direction: direction, length: maxDistance, query: .nearest, mask: collisionMask)
                    .first, result.distance > minDistance {
                    if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                        // If the raycast hit a horizontal plane, use that result with a small, fixed offset.
                        originFromPointOnPlaneTransform = originFromUprightDeviceAnchorTransform
                        originFromPointOnPlaneTransform?.translation = result.position + [0.0, placedObjectsOffsetOnPlanes, 0.0]
                    }
                }
                
                if let originFromPointOnPlaneTransform {
                    activeController.setPlacementLocationTransform(value: Transform(matrix: originFromPointOnPlaneTransform))
                    activeController.setPlaneToProjectOnFound(value: true)
                }
            }
        }
    }

    func processPlaneDetectionUpdates() async {
        for await anchorUpdate in planeDetection.anchorUpdates {
            await planeAnchorHandler?.process(anchorUpdate)
        }
    }

    func placeBoard(_ entity: AnchorableEntity) {
        
        if let activeController = appModel?.activeController, activeController.game.mode == .mixed {
            if pointersPlaced == 0 {
                entity.renderContent?.position = activeController.placementLocation.position
                entity.renderContent?.orientation = activeController.placementLocation.orientation
                
                Task {
                    let anchorId = UUID()
                    dataSource?.insertInstance(entity, id: anchorId)
                    if let contentToRender = dataSource?.renderContentForAnchor(anchorId) {
                        contentToRender.position = activeController.placementLocation.position
                        contentToRender.orientation = activeController.placementLocation.orientation
                        contentToRender.isEnabled = true
                        activeController.contentEntity.addChild(contentToRender)
                    }
                    
                    print("Pointer1 placed!")
                    pointersPlaced += 1
                }
            } else {
                entity.renderContent?.position = activeController.placementLocation.position
                entity.renderContent?.orientation = activeController.placementLocation.orientation
                
                Task {
                    let newWorldAnchor = await attachEntityToWorldAnchor(entity)
                    if let existingWorldAnchorID = newWorldAnchor?.id {
                        worldAnchors[existingWorldAnchorID] = newWorldAnchor
                    }
                    print("Pointer2 placed!")
                    pointersPlaced += 1
                    activeController.placementLocation.removeFromParent()
                    boardPlaced = true
                }
            }
        } else {
            if let activeController = appModel?.sessionController {
    #if targetEnvironment(simulator)
                entity.renderContent?.position = activeController.placementLocation.position
                entity.renderContent?.orientation = activeController.placementLocation.orientation
                
                Task {
                    let anchorId = UUID()
                    dataSource?.insertInstance(entity, id: anchorId)
                    if let contentToRender = dataSource?.renderContentForAnchor(anchorId) {
                        contentToRender.position = .init(x: 0, y: 0.88, z: 0.5)
                        contentToRender.orientation = .init()
                        contentToRender.isEnabled = true
                        activeController.contentEntity.addChild(contentToRender)
                    }
                    
                    print("Board placed!")
                    boardPlaced = true
                    activeController.placementLocation.removeFromParent()
                }
    #else
                entity.renderContent?.position = activeController.placementLocation.position
                entity.renderContent?.orientation = activeController.placementLocation.orientation
                
                Task {
                    let newWorldAnchor = await attachEntityToWorldAnchor(entity)
                    if let existingWorldAnchorID = newWorldAnchor?.id {
                        worldAnchors[existingWorldAnchorID] = newWorldAnchor
                    }
                    print("Board placed!")
                    boardPlaced = true
                    activeController.placementLocation.removeFromParent()
                }
                
    #endif
            }
            if let activeController = appModel?.gameController {

    #if targetEnvironment(simulator)
                entity.renderContent?.position = activeController.placementLocation.position
                entity.renderContent?.orientation = activeController.placementLocation.orientation
                
                Task {
                    let anchorId = UUID()
                    dataSource?.insertInstance(entity, id: anchorId)
                    if let contentToRender = dataSource?.renderContentForAnchor(anchorId) {
                        contentToRender.position = .init(x: 0, y: 0.88, z: -0.5)
                        contentToRender.orientation = .init()
                        contentToRender.isEnabled = true
                        activeController.contentEntity.addChild(contentToRender)
                    }
                    
                    print("Board placed!")
                    boardPlaced = true
                    activeController.placementLocation.removeFromParent()
                }
    #else
                entity.renderContent?.position = activeController.placementLocation.position
                entity.renderContent?.orientation = activeController.placementLocation.orientation
                
                Task {
                    let newWorldAnchor = await attachEntityToWorldAnchor(entity)
                    if let existingWorldAnchorID = newWorldAnchor?.id {
                        worldAnchors[existingWorldAnchorID] = newWorldAnchor
                    }
                    print("Board placed!")
                    boardPlaced = true
                    activeController.placementLocation.removeFromParent()
                }
    #endif

            }
        }
    }

    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled {
                return
            }
            
            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }
            
            await function()
        }
    }

    func process(_ anchorUpdate: AnchorUpdate<WorldAnchor>) {
        
        print("Handling anchor update: \(anchorUpdate.anchor.id)")
        
        let anchor = anchorUpdate.anchor
        
        if anchorUpdate.event != .removed {
            worldAnchors[anchor.id] = anchor
        } else {
            worldAnchors.removeValue(forKey: anchor.id)
        }
        
        switch anchorUpdate.event {
        case .added:
            // Check whether there’s a persisted object attached to this added anchor -
            // it could be a world anchor from a previous run of the app.
            // ARKit surfaces all of the world anchors associated with this app
            // when the world tracking provider starts.
            if let contentToRender = dataSource?.renderContentForAnchor(anchor), let activeController = appModel?.activeController {
                contentToRender.position = anchor.originFromAnchorTransform.translation
                contentToRender.orientation = anchor.originFromAnchorTransform.rotation
                contentToRender.isEnabled = anchor.isTracked
                activeController.contentEntity.addChild(contentToRender)
            } else {
                if dataSource?.shouldRemoveEntity(for: anchor.id) == true {
                    Task {
                        // Immediately delete world anchors for which no placed object is known.
                        print("No object is attached to anchor \(anchor.id) - it can be deleted.")
                        await removeAnchorWithID(anchor.id)
                    }
                }
            }
            fallthrough
        case .updated:
            // Keep the position of placed objects in sync with their corresponding
            // world anchor, and hide the object if the anchor isn’t tracked.
            if let object = dataSource?.renderContentForAnchor(anchor), let activeController = appModel?.activeController {
                object.position = anchor.originFromAnchorTransform.translation
                object.orientation = anchor.originFromAnchorTransform.rotation
                object.isEnabled = anchor.isTracked
                activeController.contentEntity.addChild(object)
            }
        case .removed:
            // Remove the placed object if the corresponding world anchor was removed.
            dataSource?.renderContentForAnchor(anchor)?.removeFromParent()
        }
    }

    func attachEntityToWorldAnchor(_ entity: AnchorableEntity) async -> WorldAnchor? {
        // First, create a new world anchor and try to add it to the world tracking provider.
        guard let renderContent = entity.renderContent else {
            print("no render content")
            return nil
        }
        let anchor = WorldAnchor(originFromAnchorTransform: renderContent.transformMatrix(relativeTo: nil))
        
        do {
            dataSource?.insertInstance(entity, id: anchor.id)
            try await worldTracking.addAnchor(anchor)
        } catch {
            // Adding world anchors can fail, such as when you reach the limit
            // for total world anchors per app. Keep track
            // of all world anchors and delete any that no longer have
            // an object attached.
            
            if let worldTrackingError = error as? WorldTrackingProvider.Error, worldTrackingError.code == .worldAnchorLimitReached {
                print(
                    """
                    Unable to place object "\(entity.debugDescription)". You’ve placed the maximum number of objects.
                    Remove old objects before placing new ones.
                    """
                )
            } else {
                print("Failed to add world anchor \(anchor.id) with error: \(error).")
            }
            
            entity.renderContent?.removeFromParent()
            return nil
        }
        
        return anchor
    }

    func removeAnchorWithID(_ uuid: UUID) async {
        do {
            try await worldTracking.removeAnchor(forID: uuid)
        } catch {
            print("Failed to delete world anchor \(uuid) with error \(error).")
        }
    }

    
}
