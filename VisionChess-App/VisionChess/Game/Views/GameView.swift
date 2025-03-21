//
//  GameView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 13.01.2025.
//

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

    @State var currentDragTransformStart: Transform? = nil
    @State private var sourceTransform: Transform?
    
    var dataSource: ModelDataSource
    
    var body: some View {
        RealityView { content, attachments in
            Task {
                dataSource.removeAll()
            }
            
            //let cameraFeedVisualizationEntity = appModel.viewModel?.cameraFeedVisualizationEntity
            
            guard let scene else {
                return
            }
            
            Task {
                switch appModel.activeController?.game.mode {
                    case .virtual, .physical:
                        let cursor = try await ModelEntity(named: "PlacementCursor")
                        appModel.activeController?.placementLocation.addChild(cursor)
                        print("Added cursor")
                    case .mixed:
                        let cursor = try await ModelEntity(named: "pointer")
                        appModel.activeController?.placementLocation.addChild(cursor)
                        print("Added cursor")
                    case .none:
                        print("Game mode not set")
                }
                
            }
            
            appModel.viewModel?.prepare(withContent: content, andScene: scene)
            
        } update: { content, attachments in
            if (appModel.activeController?.game.stage == .inSetup)
                && !content.entities.contains(where: {$0 == appModel.activeController?.contentEntity}) {
                if let contentEntity = appModel.activeController?.contentEntity {
                    content.add(contentEntity)
                    
#if targetEnvironment(simulator)
                    if let activeController = appModel.activeController {
                        if appModel.sessionController != nil {
                            appModel.viewModel?.placeBoard(dataSource.insert(side: appModel.activeController?.localPlayer.side ?? .white, isSpatial: true, isPointer: 0))
                        } else {
                            appModel.viewModel?.placeBoard(dataSource.insert(side: appModel.activeController?.localPlayer.side ?? .white, isSpatial: false, isPointer: 0))
                        }
                        activeController.startGame(opponentStrength: activeController.opponentStrength)
                    }
#endif
                }
            }
            
            appModel.activeController?.handleCollisions(content: content)
            
        } attachments: {
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let activeController = appModel.activeController {
                        if activeController.game.mode == .mixed {
                            if appModel.viewModel?.pointersPlaced == 0 {
                                appModel.viewModel?.placeBoard(dataSource.insert(side: appModel.activeController?.localPlayer.side ?? .white, isSpatial: false, isPointer: 1))
                            } else {
                                appModel.viewModel?.placeBoard(dataSource.insert(side: appModel.activeController?.localPlayer.side ?? .white, isSpatial: false, isPointer: 2))
                            }
                        } else {
                            if activeController.pieceEntities.count == 0 {
                                appModel.viewModel?.placeBoard(dataSource.insert(side: appModel.activeController?.localPlayer.side ?? .white, isSpatial: false, isPointer: 0))
                            }
                        }
                        
                        if (appModel.viewModel?.pointersPlaced == 1 || activeController.game.mode != .mixed) && activeController.pieceEntities.count == 0 {
                            activeController.startGame(opponentStrength: activeController.opponentStrength)
                        }
                    }
                }
        )
        .gesture(
            DragGesture()
                .simultaneously(with: RotateGesture3D(constrainedToAxis: .y))
                .targetedToAnyEntity()
                .handActivationBehavior(.pinch)
                .onChanged { value in
                    if appModel.activeController?.game.stage != .inGame(.duringPlayersTurn) {
                        return
                    }
                    
                    if sourceTransform == nil {
                        sourceTransform = value.entity.transform
                    }
                    
                    if appModel.activeController?.currentlyMovingChessPiece == nil && appModel.activeController?.currentlyMovingChessPieceCollisionSubscription == nil {
                        appModel.activeController?.setCurrentlyMovingChessPiece(entity: value.entity)
                    }

                    if let rotation = value.second?.rotation {
                        let rotationTransform = Transform(AffineTransform3D(rotation: rotation))
                        value.entity.transform.rotation = sourceTransform!.rotation * rotationTransform.rotation
                    } else if let transform = value.first?.location3D {
                        value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false
                        let location3D = value.convert(transform, from: .local, to: .scene)
                        appModel.activeController?.moveCube(entity: value.entity, to: location3D)
                    }
                }
                .onEnded { value in
                    sourceTransform = nil
                    value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
                    
                    if appModel.activeController?.game.stage != .inGame(.duringPlayersTurn) {
                        return
                    }
                    
                    if appModel.activeController?.currentTargetField.isEmpty ?? true {
                        print("Return piece to initial position")
                        appModel.activeController?.movePieceToLastKnownPosition(piece: value.entity)
                    } else {
                        let fieldEntity = appModel.activeController?.currentTargetField.last!
                        if let fieldEntity = fieldEntity {
                            
                            
                            print("Move piece to field")
                            appModel.activeController?.move(piece: ChessPiece(rawValue: value.entity.name)!, to: ChessField(rawValue: fieldEntity.name)!, promotedPiece: nil) { success in
                                if success {
                                    fieldEntity.components[OpacityComponent.self]?.opacity = 0.0
                                } else {
                                    appModel.activeController?.movePieceToLastKnownPosition(piece: value.entity)
                                    print("Return piece to initial position")
                                }
                            }
                        }
                    }
                }
        )
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
