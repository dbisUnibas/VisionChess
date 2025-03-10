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


@Observable
class GameViewModel {
    let contentContainerEntity = Entity()
    let cameraFeedVisualizationEntity: CameraFeedVisualizationEntity = {
        CameraFeedVisualizationComponent.registerComponent()
        return .init()
    }()

    var enableDebugging = false

    private var content: RealityViewContent?
    private weak var scene: RealityKit.Scene?
    private(set) var gameManager: GameManager?
    private(set) var predictions: [ChessPieceDetectionManager.PredictionResult]?
    private(set) var error: Error?
    private(set) var gameEntityResources: [GameEntityResource: ModelEntity] = [:]
    private(set) var gameAudioResources: [GameAudioResource: AudioResource] = [:]
    //    private(set) var currentPixelBuffer: CVPixelBuffer?

    private var cameraFrameProvider: CameraFrameProvider?
    private var sceneUpdateSubscription: EventSubscription?
    private var objectDetectionManager: ChessPieceDetectionManager?
    private var objectDetectionPredictionSubscription: AnyCancellable?
    private var scoreChangeSubscription: AnyCancellable?
    private var ballVisualizationTimer: AnyCancellable?

    let worldTracking = WorldTrackingProvider()
    let planeDetection = PlaneDetectionProvider()
    var utilityEntities: UtilityEntities
    private var arInterface: ARKitInterface
    private var planeAnchorHandler: PlaneAnchorHandler
    var deviceAnchorPresent = false
    var planeAnchorsPresent = false
    var boardPlaced: Bool = false
    private var worldAnchors: [UUID:WorldAnchor] = [:]
    static private let placedObjectsOffsetOnPlanes: Float = 0.0001
    var dataSource: PlaneAnchoringDataSource?

    var currentTargetField: [Entity] = []
    var currentlyMovingChessPiece: Entity? = nil
    var currentlyMovingChessPieceInitialField: Entity? = nil
    var currentlyMovingChessPieceCollisionSubscription: EventSubscription? = nil
    var currentlyMovingChessPieceCollisionSubscriptionEnd: EventSubscription? = nil

    var uiRightEntity: Entity? = nil
    var uiLeftEntity: Entity? = nil

    var errorMessage: String? = nil

    struct UtilityEntities {
        var contentEntity = Entity()
        let deviceLocation: Entity = .init()
        let raycastOrigin: Entity = .init()
        let placementLocation: Entity = .init()
        
        init() {
            contentEntity.addChild(placementLocation)
            deviceLocation.addChild(raycastOrigin)
            
            // Angle raycasts 15 degrees down.
            let raycastDownwardAngle = 15.0 * (Float.pi / 180)
            raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
        }
    }

    /// When the user is gazing at a valid plane target, insert the placement cursor
    var planeToProjectOnFound = false {
        didSet {
            if planeToProjectOnFound {
                utilityEntities.contentEntity.addChild(utilityEntities.placementLocation)
            } else {
                utilityEntities.placementLocation.removeFromParent()
            }
        }
    }

    init(dataSource: PlaneAnchoringDataSource) {
        print("Initializing GameViewModel")
        self.dataSource = dataSource
        let entities = UtilityEntities()
        self.utilityEntities = entities
        
        planeAnchorHandler = .init(rootEntity: entities.contentEntity)
        arInterface = .init()
        
        Task {
            let cursor = try await ModelEntity(named: "PlacementCursor")
            await utilityEntities.placementLocation.addChild(cursor)
        }
        
        self.gameManager = .init(viewModel: self)
        //self.objectDetectionManager = .init()
        
        //        objectDetectionPredictionSubscription = objectDetectionManager?.predictionsSubject
        //            .receive(on: DispatchQueue.main)
        //            .throttle(for: .seconds(0.025), scheduler: RunLoop.main, latest: true)
        //            .sink(receiveValue: { predictions in
        //                self.predictions = predictions
        //                self.gameManager.update(predictions: predictions)
        //            })
    }

    func prepare(withContent content: RealityViewContent, andScene scene: RealityKit.Scene) {
        self.content = content
        self.scene = scene

        contentContainerEntity.position = [0, 1.2, -1]
        content.add(contentContainerEntity)
        
        #if !targetEnvironment(simulator)
        Task {
            await runARKitSession()
        }
        #endif
        runTrackingProviders()
    }

    func toggle(entity: Entity, isEnabled: Bool, animated: Bool = true) {
        if isEnabled {
            entity.isEnabled = true
        }
    }

    func getEntityResource(ofKind kind: GameEntityResource) -> Entity {
        guard let entity = gameEntityResources[kind] else {
            fatalError("Entity Assets not yet loaded.")
        }
        return entity.clone(recursive: true)
    }

    private func runTrackingProviders() {
    #if !targetEnvironment(simulator)
        guard CameraFrameProvider.isSupported else {
            print("CameraFrameProvider not supported.")
            return
        }
        let formats = CameraVideoFormat.supportedVideoFormats(for: .main, cameraPositions: [.left])
    #endif
        
        let authorizationTypes: [ARKitSession.AuthorizationType] = {
    #if targetEnvironment(simulator)
            return [.worldSensing]
    #else
            return [.cameraAccess, .worldSensing]
    #endif
        }()
        
        Task {
            let _ = await arInterface.arkitSession.requestAuthorization(for: authorizationTypes)
            let authorizationResult = await arInterface.arkitSession.queryAuthorization(for: authorizationTypes)
            
            for (authorizationType, authorizationStatus) in authorizationResult {
                print("Authorization Status for: \(authorizationType): \(authorizationStatus)")
                if authorizationStatus == .denied {
                    print("Authorization denied")
                    return
                }
            }
            
            do {
    #if !targetEnvironment(simulator)
                let cameraFrameProvider = CameraFrameProvider()
                self.cameraFrameProvider = cameraFrameProvider
                
                try await arInterface.arkitSession.run([cameraFrameProvider, worldTracking])
                
                print("cameraFrameUpdates:")
                if let updates = cameraFrameProvider.cameraFrameUpdates(for: formats[0]) {
                    for await update in updates {
                        guard
                            // appModel?.sessionController?.game.stage.isInGame ?? false,
                            let mainCameraSample = update.sample(for: .left)
                        else {
                            continue
                        }
                        let currentPixelBuffer = mainCameraSample.pixelBuffer
                        print("pixelBuffer")
                        print(currentPixelBuffer)
                        objectDetectionManager?.predictUsingVision(
                            pixelBuffer: currentPixelBuffer,
                            isARKitBuffer: true
                        )
                        
                        Task { @MainActor in
                            cameraFeedVisualizationEntity.update(withCameraFramePixelBuffer: mainCameraSample.pixelBuffer)
                        }
                    }
                }
    #else
                try await arInterface.arkitSession.run([worldTracking])
    #endif
            } catch {
                print("Error: \(error)")
                self.error = error
            }
        }
    }

    @MainActor
    func runARKitSession() async {
        await arInterface.beginSession(world: worldTracking, plane: planeDetection)
    }

    @MainActor
    func processDeviceAnchorUpdates() async {
        await run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }

    @MainActor
    func processWorldAnchorUpdates() async {
        for await anchorUpdate in worldTracking.anchorUpdates {
            process(anchorUpdate)
        }
    }

    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        
        deviceAnchorPresent = deviceAnchor != nil
        planeAnchorsPresent = !planeAnchorHandler.planeAnchors.isEmpty
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        
        await updatePlacementLocation(deviceAnchor)
    }

    @MainActor
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        if !boardPlaced {
            utilityEntities.deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
            let originFromUprightDeviceAnchorTransform = deviceAnchor.originFromAnchorTransform.gravityAligned
            
            // Determine a placement location on planes in front of the device by casting a ray.
            
            // Cast the ray from the device origin.
            let origin: SIMD3<Float> = utilityEntities.raycastOrigin.transformMatrix(relativeTo: nil).translation
            
            // Cast the ray along the negative z-axis of the device anchor, but with a slight downward angle.
            // (The downward angle is configurable using the `raycastOrigin` orientation.)
            let direction: SIMD3<Float> =  -utilityEntities.raycastOrigin.transformMatrix(relativeTo: nil).zAxis
            
            // Only consider raycast results that are within 0.2 to 3 meters from the device.
            let minDistance: Float = 0.2
            let maxDistance: Float = 3
            
            // Only raycast against horizontal planes.
            let collisionMask = PlaneAnchor.allPlanesCollisionGroup
            
            var originFromPointOnPlaneTransform: float4x4? = nil
            if let result = utilityEntities.contentEntity.scene?.raycast(origin: origin, direction: direction, length: maxDistance, query: .nearest, mask: collisionMask)
                .first, result.distance > minDistance {
                if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                    // If the raycast hit a horizontal plane, use that result with a small, fixed offset.
                    originFromPointOnPlaneTransform = originFromUprightDeviceAnchorTransform
                    originFromPointOnPlaneTransform?.translation = result.position + [0.0, Self.placedObjectsOffsetOnPlanes, 0.0]
                }
            }
            
            if let originFromPointOnPlaneTransform {
                utilityEntities.placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
                planeToProjectOnFound = true
            }
        }
    }

    func processPlaneDetectionUpdates() async {
        for await anchorUpdate in planeDetection.anchorUpdates {
            await planeAnchorHandler.process(anchorUpdate)
        }
    }

    @MainActor
    func placeBoard(_ entity: AnchorableEntity) {
        
        #if targetEnvironment(simulator)
            entity.renderContent?.position = utilityEntities.placementLocation.position
            entity.renderContent?.orientation = utilityEntities.placementLocation.orientation
            
            Task {
                let anchorId = UUID()
                dataSource?.insertInstance(entity, id: anchorId)
                if let contentToRender = dataSource?.renderContentForAnchor(anchorId) {
                    contentToRender.position = .init(x: 0, y: 0.68, z: -2)
                    contentToRender.orientation = .init()
                    contentToRender.isEnabled = true
                    utilityEntities.contentEntity.addChild(contentToRender)
                }
                
                print("Board placed!")
                boardPlaced = true
                utilityEntities.placementLocation.removeFromParent()
            }
        #else
            entity.renderContent?.position = utilityEntities.placementLocation.position
            entity.renderContent?.orientation = utilityEntities.placementLocation.orientation
            
            Task {
                let newWorldAnchor = await attachEntityToWorldAnchor(entity)
                if let existingWorldAnchorID = newWorldAnchor?.id {
                    worldAnchors[existingWorldAnchorID] = newWorldAnchor
                }
                print("Board placed!")
                boardPlaced = true
                utilityEntities.placementLocation.removeFromParent()
            }
        #endif
    }

    @MainActor
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

    @MainActor
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
            if let contentToRender = dataSource?.renderContentForAnchor(anchor) {
                contentToRender.position = anchor.originFromAnchorTransform.translation
                contentToRender.orientation = anchor.originFromAnchorTransform.rotation
                contentToRender.isEnabled = anchor.isTracked
                utilityEntities.contentEntity.addChild(contentToRender)
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
            if let object = dataSource?.renderContentForAnchor(anchor) {
                object.position = anchor.originFromAnchorTransform.translation
                object.orientation = anchor.originFromAnchorTransform.rotation
                object.isEnabled = anchor.isTracked
                utilityEntities.contentEntity.addChild(object)
            }
        case .removed:
            // Remove the placed object if the corresponding world anchor was removed.
            dataSource?.renderContentForAnchor(anchor)?.removeFromParent()
        }
    }

    @MainActor
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

    func moveCube(entity: Entity, to: SIMD3<Float>) async {
        await entity.setPosition(to, relativeTo: nil)
    }

    func isValidChessField(field: String) -> Bool {
        let validFiles = "abcdefgh"
        let validRanks = "12345678"
        
        guard field.count == 2 else { return false }
        
        let file = field.first!
        let rank = field.last!
        
        return validFiles.contains(file) && validRanks.contains(rank)
    }

    func isValidChessPiece(piece: String) -> Bool {
        return ChessPiece(rawValue: piece) != nil
    }

    func deactivateInput() {
        let pieces = utilityEntities.contentEntity.findEntity(named: "white")?.children
        pieces?.forEach{ piece in
            if var inputComponent = piece.component(forType: InputTargetComponent.self) {
                inputComponent.isEnabled = false
            }
        }
    }

    func activateInput() {
        let pieces = utilityEntities.contentEntity.findEntity(named: "white")?.children
        pieces?.forEach{ piece in
            if var inputComponent = piece.component(forType: InputTargetComponent.self) {
                inputComponent.isEnabled = true
            }
        }
    }


    func handleCollisions(content: RealityViewContent) {
        if let currentChessPiece = currentlyMovingChessPiece {
            if (currentlyMovingChessPieceCollisionSubscription == nil) {
                let subscription = content.subscribe(to: CollisionEvents.Began.self, on: currentChessPiece) { collisionEvent in
                    print("Collision with \(collisionEvent.entityB.name)")
                    
                    if self.isValidChessField(field: collisionEvent.entityB.name) {
                        self.currentTargetField.append(collisionEvent.entityB)
                        collisionEvent.entityB.components[OpacityComponent.self]?.opacity = 0.4
                        
                    } else if self.isValidChessPiece(piece: collisionEvent.entityB.name) {
                        print("Chess Piece Collision")
                        
                        let targetPieceEntity = collisionEvent.entityB
                        let currentTargetPiece = ChessPiece(rawValue: targetPieceEntity.name)!
                        
                        if (currentChessPiece.name.hasPrefix("white") && targetPieceEntity.name.hasPrefix("black"))
                            || (currentChessPiece.name.hasPrefix("black") && targetPieceEntity.name.hasPrefix("white")) {
                            
                            self.gameManager?.lastKnownPosition[currentTargetPiece] = .defeated
                            targetPieceEntity.removeFromParent()
                        }
                    }
                }
                
                let subscriptionEnd = content.subscribe(to: CollisionEvents.Ended.self, on: currentChessPiece) { collisionEvent in
                    if self.isValidChessField(field: collisionEvent.entityB.name) {
                        if self.currentlyMovingChessPieceInitialField == nil {
                            print("Initial Field: \(collisionEvent.entityB.name)")
                            self.currentlyMovingChessPieceInitialField = collisionEvent.entityB
                        }
                        self.currentTargetField.removeAll(where: {$0.name == collisionEvent.entityB.name})
                        collisionEvent.entityB.components[OpacityComponent.self]?.opacity = 0.0
                    }
                }
                
                DispatchQueue.main.async {
                    self.currentlyMovingChessPieceCollisionSubscription = subscription
                    self.currentlyMovingChessPieceCollisionSubscriptionEnd = subscriptionEnd
                }
            }
        }
    }
}
