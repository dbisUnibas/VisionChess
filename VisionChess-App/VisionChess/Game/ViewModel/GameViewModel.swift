//
//  GameViewModel.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

protocol AnchorableEntity {
    var worldAnchorID: UUID? { get set }
    var renderContent: RealityKit.Entity? { get }
    var debugDescription: String { get }
}

protocol PlaneAnchoringDataSource {
    func renderContentForAnchor(_ worldAnchor: WorldAnchor) -> Entity?
    func insertInstance(_ entity: AnchorableEntity, id: UUID)
    func shouldRemoveEntity(for id: UUID) -> Bool
}

enum GameEntityResource {
    case blackKing
    case blackQueen
    case blackBishop
    case blackKnight
    case blackRook
    case blackPawn
    case whiteKing
    case whiteQueen
    case whiteBishop
    case whiteKnight
    case whiteRook
    case whitePawn
}

enum GameMode {
    case physical, mixed, virtual
    var description : String {
        switch self {
            case .physical: return "physical"
            case .mixed: return "mixed"
            case .virtual: return "virtual"
        }
      }
}

enum ViewState: CaseIterable {
    case initializing, preGame, inModeSelection, inGameMenu, setup, playing, gameOver
}

enum GameAudioResource {
    case backgroundMusic
    case pop
    case ping
    case highscore
}

#if os(visionOS)
import SwiftUI
import ARKit
import RealityKit
import RealityKitContent
import Combine
import GroupActivities

@Observable
class GameViewModel {
    
    enum BallThrowDirection: CaseIterable {
        case right
        case left
        
        var opposite: BallThrowDirection {
            switch self {
            case .right:
                return .left
            case .left:
                return .right
            }
        }
    }
    
    let contentContainerEntity = Entity()
    let ballsContainerEntity = Entity()
    let cameraFeedVisualizationEntity: CameraFeedVisualizationEntity = {
        CameraFeedVisualizationComponent.registerComponent()
        return .init()
    }()
    
    var enableDebugging = false
    
    private var content: RealityViewContent?
    private weak var scene: RealityKit.Scene?
    private(set) var gameManager: GameManager?
    private(set) var viewState: ViewState = .initializing
    private(set) var predictions: [ChessPieceDetectionManager.PredictionResult]?
    private(set) var error: Error?
    private(set) var gameEntityResources: [GameEntityResource: ModelEntity] = [:]
    private(set) var gameAudioResources: [GameAudioResource: AudioResource] = [:]
    //    private(set) var currentPixelBuffer: CVPixelBuffer?
    private var lastBallThrowDirection: BallThrowDirection?
    
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
    
    var sharePlayEnabled = false
    var sharePlaySession: GroupSession<ChessGroupActivity>?
    var tasks = Set<Task<Void, Never>>()
    var subscriptions: Set<AnyCancellable> = []
    var sharePlayMessenger: GroupSessionMessenger?
    
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
    
    init() {
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
    
    @MainActor
    func loadResources() async {
        do {
            // load entities
            let blackKing = try await ModelEntity(
                named: "black-king"
            )
            let blackQueen = try await ModelEntity(
                named: "black-queen"
            )
            let blackBishop = try await ModelEntity(
                named: "black-bishop"
            )
            let blackKnight = try await ModelEntity(
                named: "black-knight"
            )
            let blackRook = try await ModelEntity(
                named: "black-rook"
            )
            let blackPawn = try await ModelEntity(
                named: "black-pawn"
            )
            self.gameEntityResources[.blackKing] = blackKing
            self.gameEntityResources[.blackQueen] = blackQueen
            self.gameEntityResources[.blackBishop] = blackBishop
            self.gameEntityResources[.blackKnight] = blackKnight
            self.gameEntityResources[.blackRook] = blackRook
            self.gameEntityResources[.blackPawn] = blackPawn
            
            
            let whiteKing = try await ModelEntity(
                named: "white-king"
            )
            let whiteQueen = try await ModelEntity(
                named: "white-queen"
            )
            let whiteBishop = try await ModelEntity(
                named: "white-bishop"
            )
            let whiteKnight = try await ModelEntity(
                named: "white-knight"
            )
            let whiteRook = try await ModelEntity(
                named: "white-rook"
            )
            let whitePawn = try await ModelEntity(
                named: "white-pawn"
            )
            self.gameEntityResources[.whiteKing] = whiteKing
            self.gameEntityResources[.whiteQueen] = whiteQueen
            self.gameEntityResources[.whiteBishop] = whiteBishop
            self.gameEntityResources[.whiteKnight] = whiteKnight
            self.gameEntityResources[.whiteRook] = whiteRook
            self.gameEntityResources[.whitePawn] = whitePawn
        } catch {
            print(error)
            fatalError("Could not load assets.")
        }
    }
    
    func prepare(withContent content: RealityViewContent, andScene scene: RealityKit.Scene) {
        self.content = content
        self.scene = scene
        
        cameraFeedVisualizationEntity.isEnabled = false
        contentContainerEntity.position = [0, 1.2, -1]
        content.add(contentContainerEntity)
        content.add(ballsContainerEntity)
        
        Task {
            await runARKitSession()
        }
        runTrackingProviders()
        
        sceneUpdateSubscription?.cancel()
        sceneUpdateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.handleSceneUpdate(event: event)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.startBallVisualization()
        }
    }
    
    func startBallVisualization() {
        ballVisualizationTimer = Timer.publish(every: 1, tolerance: 0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] time in
                self?.addBall()
            }
    }
    
    func stopBallVisualization() {
        ballVisualizationTimer?.cancel()
    }
    
    func switchViewState(to: ViewState) {
        guard
            viewState.next() == to
        else {
            return
        }
        viewState = to
    }
    
    func goToPreviousState() {
        guard
            ![.gameOver].contains(where: {$0 == viewState})
        else {
            return
        }
        viewState = viewState.previous()
    }
    
    func startGame() {
        guard
            viewState != .playing
        else {
            return
        }
        viewState = .playing
        gameManager?.reset()
        gameManager?.startGame()
        cameraFeedVisualizationEntity.isEnabled = true
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
    
    func getRandomEntityResource() -> Entity {
        guard let entity = gameEntityResources.randomElement()?.value else {
            fatalError("Entity Assets not yet loaded.")
        }
        entity.scale = .init(x: 2, y: 2, z: 2)
        return entity.clone(recursive: true)
    }
    
    func addTestEntity(content: RealityViewContent) {
        ballsContainerEntity.addChild(getRandomEntityResource())
    }
    
    func addBall() {
        guard
            let scene,
            viewState == .preGame
        else {
            return
        }
        
        let throwDirection: BallThrowDirection = {
            if let lastBallThrowDirection {
                return lastBallThrowDirection.opposite
            }
            return BallThrowDirection.allCases.randomElement()!
        }()
        
        lastBallThrowDirection = throwDirection
        
        let ballEntity = ChessPieceEntity(
            particleEntity: getRandomEntityResource()
        )
        //        var targetPosition = contentContainerEntity.position(relativeTo: nil)
        //        targetPosition.z -= 0.1
        //        print("Target pos: \(targetPosition)")
        //        ballEntity.worldPosition = targetPosition
        
        ballEntity.position.z = -0.1
        
        ballsContainerEntity.addChild(ballEntity)
        
        var simulationComponent = PhysicsSimulationComponent()
        simulationComponent.gravity = [0, -1, 0]
        ballsContainerEntity.components.set(simulationComponent)
        
        let impulseXOffsetIntensity: Float = 0.025
        let impulseXOffset: Float = throwDirection == .right ? impulseXOffsetIntensity : -impulseXOffsetIntensity
        
        let ballXOffset: Float = 0.1
        ballEntity.position.x = throwDirection == .right ? -ballXOffset : ballXOffset
        ballEntity.applyLinearImpulse([impulseXOffset, 0.1, 0], relativeTo: ballEntity.parent)
        ballEntity.opacity = 0
        
        Task { @MainActor in
            await ballEntity.fadeOpacity(
                to: 1,
                duration: 0.5,
                delay: 0,
                timing: .linear,
                scene: scene
            )
            await ballEntity.fadeOpacity(
                to: 0,
                duration: 0.5 ,
                delay: 0.5,
                timing: .linear,
                scene: scene
            )
            ballEntity.removeFromParent()
        }
    }
    
    func endGame(data: GameOverData) {
        viewState = .gameOver
        //gameManager.setGameOverData(data: data)
        
        cameraFeedVisualizationEntity.isEnabled = false
        
        var trophy: TrophyEntity?
        
        if data.isNewHighscore {
            let trophyEntity = TrophyEntity(
                sourceEntity: getEntityResource(ofKind: .whiteKing),
                confettiOneEntity: getEntityResource(ofKind: .whiteKing),
                confettiTwoEntity: getEntityResource(ofKind: .whiteKing)
            )
            contentContainerEntity.addChild(trophyEntity)
            trophyEntity.reveal()
            trophy = trophyEntity
        }
        
        let waitTime: TimeInterval = data.isNewHighscore ? 5 : 3
        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
            if let trophy {
                trophy.remove()
            }
            self.viewState = .preGame
        }
    }
    
    func handleViewDidAppear() {
        guard viewState == .initializing else {
            return
        }
        viewState = .preGame
    }
    
    private func handleSceneUpdate(event: SceneEvents.Update) {
        guard
            //            viewState == .playing,
            worldTracking.state == .running,
            let deviceTransform = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())?.originFromAnchorTransform
        else {
            print("Could not query device transform")
            contentContainerEntity.isEnabled = false
            return
        }
        
        let offsetTransform = Transform(
            translation: [0, 0, -0.7]
        )
        let contentContainerEntityTransform = contentContainerEntity.transformMatrix(relativeTo: nil)
        let targetTransform = simd_mul(deviceTransform, offsetTransform.matrix)
        
        contentContainerEntity.setTransformMatrix(
            contentContainerEntityTransform.mix(with: targetTransform, t: 0.01),
            relativeTo: nil
        )
        ballsContainerEntity.worldTransform = contentContainerEntity.worldTransform
        contentContainerEntity.isEnabled = true
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
                            viewState == .playing,
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
            
            self.startGame()
        }
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
        
    func registerGroupActivity() {
        let itemProvider = NSItemProvider()
        itemProvider.registerGroupActivity(ChessGroupActivity())
        let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
        configuration.metadataProvider = { key in
            guard key == .linkPresentationMetadata else { return Void.self }
            return ChessGroupActivity().metadata
        }
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController?
            .activityItemsConfiguration = configuration
    }
    
    func toggleSharePlay() {
        if (!self.sharePlayEnabled) {
            startSharePlay()
        } else {
            endSharePlay()
        }
    }
    
    func startSharePlay() {
        Task {
            let activity = ChessGroupActivity()
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                } catch {
                    print("SharePlay unable to activate the activity: \(error)")
                }
            case .activationDisabled:
                print("SharePlay group activity activation disabled")
            case .cancelled:
                print("SharePlay group activity activation cancelled")
            @unknown default:
                print("SharePlay group activity activation unknown case")
            }
        }
    }
    
    func endSharePlay() {
        self.sharePlaySession?.end()
    }
    
    func configureGroupSession() {
        Task {
            for await session in ChessGroupActivity.sessions() {
                self.sharePlaySession = session
                
                if let systemCoordinator = await session.systemCoordinator {
                    var config = SystemCoordinator.Configuration()
                    config.spatialTemplatePreference = .none
                    config.supportsGroupImmersiveSpace = true
                    systemCoordinator.configuration = config
                }
                
                
                Task {
                    @MainActor in
                    self.sharePlayEnabled = true
                }
                
                session.join()
                
                session.$state
                    .sink { [weak self] in
                        if case .invalidated = $0 {
                            self?.sharePlayMessenger = nil
                            self?.tasks.forEach { $0.cancel() }
                            self?.tasks = []
                            self?.subscriptions = []
                            self?.sharePlaySession = nil
                            self?.sharePlayEnabled = false
                        }
                    }
                    .store(in: &self.subscriptions)
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
#endif
