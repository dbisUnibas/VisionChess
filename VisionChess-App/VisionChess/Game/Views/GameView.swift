//
//  GameView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 13.01.2025.
//

#if os(visionOS)
import SwiftUI
import ARKit
import RealityKit
import RealityKitContent
import Combine
import SwiftData

struct GameView: View {
    enum ViewAttachment: String {
        case mainView
        case uiRightView
        case uiLeftView
        case uiBottomView
        case debugView
    }
    
    @Environment(AppModel.self) private var appModel
    @Environment(\.realityKitScene) var scene: RealityKit.Scene?
    @Environment(\.modelContext) var modelContext
    @State var currentDragTransformStart: Transform? = nil
    @State private var sourceTransform: Transform?
    
    
    let modelContainer: ModelContainer
    let dataSource: ModelDataSource
    
    init() {
        do {
            modelContainer = try ModelContainer(for: PersistedModel.self)
            dataSource = .init(context: modelContainer.mainContext)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }
    
    var body: some View {
        RealityView { content, attachments in
            Task {
                dataSource.removeAll()
            }
            
            let cameraFeedVisualizationEntity = appModel.viewModel?.cameraFeedVisualizationEntity
            
            guard let scene else {
                return
            }
            
            appModel.viewModel?.prepare(withContent: content, andScene: scene)
            
        } update: { content, attachments in
            if (appModel.sessionController?.game.stage == .inSetup && !content.entities.contains(where: {$0 == appModel.viewModel?.utilityEntities.contentEntity})) {
                if let contentEntity = appModel.viewModel?.utilityEntities.contentEntity {
                    content.add(contentEntity)
                }
            }
            
            appModel.viewModel?.handleCollisions(content: content)
            
        } attachments: {
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if (appModel.sessionController?.game.stage == .inSetup) {
                        appModel.viewModel?.placeBoard(dataSource.insert())
                        appModel.sessionController?.startGame()
                        appModel.viewModel?.gameManager?.startGame()
                    }
                }
        )
        .gesture(
            DragGesture()
                .simultaneously(with: RotateGesture3D(constrainedToAxis: .y))
                .targetedToAnyEntity()
                .handActivationBehavior(.pinch)
                .onChanged { value in
                    if appModel.viewModel?.gameManager?.currentSide != .white {
                        return
                    }
                    
                    if sourceTransform == nil {
                        sourceTransform = value.entity.transform
                    }
                    
                    if appModel.viewModel?.currentlyMovingChessPiece == nil && appModel.viewModel?.currentlyMovingChessPieceCollisionSubscription == nil {
                        appModel.viewModel?.currentlyMovingChessPiece = value.entity
                    }

                    if let rotation = value.second?.rotation {
                        let rotationTransform = Transform(AffineTransform3D(rotation: rotation))
                        value.entity.transform.rotation = sourceTransform!.rotation * rotationTransform.rotation
                    } else if let transform = value.first?.location3D {
                        value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false
                        let location3D = value.convert(transform, from: .local, to: .scene)
                        Task {
                            await appModel.viewModel?.moveCube(entity: value.entity, to: location3D)
                        }
                    }
                }
                .onEnded { value in
                    sourceTransform = nil
                    value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
                    
                    if appModel.viewModel?.currentTargetField.isEmpty ?? true || appModel.viewModel?.gameManager?.currentSide != .white {
                        return
                    }
                    
                    let fieldEntity = appModel.viewModel?.currentTargetField.last!
                    if let fieldEntity = fieldEntity {
                        appModel.viewModel?.gameManager?.move(piece: ChessPiece(rawValue: value.entity.name)!, to: ChessField(rawValue: fieldEntity.name)!) { success in
                            if success {
                                fieldEntity.components[OpacityComponent.self]?.opacity = 0.0
                                appModel.viewModel?.currentTargetField = []
                                appModel.viewModel?.currentlyMovingChessPiece = nil
                                appModel.viewModel?.currentlyMovingChessPieceCollisionSubscription?.cancel()
                                appModel.viewModel?.currentlyMovingChessPieceCollisionSubscription = nil
                                appModel.viewModel?.currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
                                appModel.viewModel?.currentlyMovingChessPieceCollisionSubscriptionEnd = nil
                                appModel.viewModel?.deactivateInput()
                            } else {
                                if let initialField = appModel.viewModel?.currentlyMovingChessPieceInitialField {
                                    appModel.viewModel?.gameManager?.animateMove(piece: value.entity, field: initialField)
                                    initialField.components[OpacityComponent.self]?.opacity = 0.4
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        initialField.components[OpacityComponent.self]?.opacity = 0.0
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            initialField.components[OpacityComponent.self]?.opacity = 0.4
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                initialField.components[OpacityComponent.self]?.opacity = 0.0
                                                
                                                
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    appModel.viewModel?.errorMessage = nil
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
        )
        .onAppear {
            appModel.initViewModel(dataSource: dataSource)
        }
        .task {
            print("awaiting anchor updates")
            await appModel.viewModel?.processWorldAnchorUpdates()
        }
        .task {
            await appModel.viewModel?.processDeviceAnchorUpdates()
        }
        .task {
            await appModel.viewModel?.processPlaneDetectionUpdates()
        }
    }
    
    func formattedPercentage(_ value: Float) -> String {
        let percentage = value * 100  // Convert to percentage
        return String(format: "%.2f%%", percentage)  // Format as percentage with two decimal places
    }
    
    @ViewBuilder
    var predictionsView: some View {
        let shape = Capsule()
        
        VStack {
            ZStack {
                if let predictions = appModel.viewModel?.predictions, !predictions.isEmpty {
                    VStack {
//                        ForEach(predictions, id: \.id) { prediction in
//                            Text("\(prediction.label.description) – \(formattedPercentage(prediction.confidence))")
//                        }
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding()
            .frame(width: 400)
            .background {
                if let predictions = appModel.viewModel?.predictions, predictions.contains(where: { $0.isBallInAir && $0.confidence > 0.6 }) {
                    Color(uiColor: .systemGreen).opacity(0.5)
                        .blendMode(.overlay)
                        .clipShape(shape)
                }
            }
            .glassBackgroundEffect(in: shape)
        }
    }
    
    @ViewBuilder
    private func makeStatusContainerView(
        @ViewBuilder content: @escaping () -> some View
    ) -> some View {
        VStack {
            content()
                .padding()
        }
    }
}

extension Transform {
    func whenTranslatedBy (vector: Vector3D) -> Transform {
        // Turn the vector translation into a transformation
        let movement = Transform(translation: simd_float3(vector.vector))

        // Calculate the new transformation by matrix multiplication
        let result = Transform(matrix: (movement.matrix * self.matrix))

        return result
    }
}
#endif
