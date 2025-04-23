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
        } update: { content, attachments in
            if (appModel.activeController?.game.stage == .inSetup)
                && !content.entities.contains(where: {$0 == appModel.activeController?.contentEntity}) {
                if let contentEntity = appModel.activeController?.contentEntity {
                    content.add(contentEntity)
                }
            }
            
            appModel.activeController?.handleCollisions(content: content)
            
        } attachments: {
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    tapGestureEnded(value)
                }
        )
        .gesture(
            DragGesture()
                .simultaneously(with: RotateGesture3D(constrainedToAxis: .y))
                .targetedToAnyEntity()
                .handActivationBehavior(.pinch)
                .onChanged { value in
                    dragGestureChanged(value)
                }
                .onEnded { value in
                    dragGestureEnded(value)
                }
        )
        .task {
            await appModel.viewModel?.processWorldAnchorUpdates()
        }
        .task {
            await appModel.viewModel?.processDeviceAnchorUpdates()
        }
        .task {
            await appModel.viewModel?.processPlaneDetectionUpdates()
        }
        .onAppear {
            initGameView()
        }
    }
}
    
extension GameView {
    
    func initGameView() {
        print("INIT GAME VIEW")
        Task {
            dataSource.removeAll()
            switch appModel.activeController?.game.mode {
                case .virtual, .physical, .review, .tutorial:
                    let cursor = try await ModelEntity(named: "PlacementCursor")
                    appModel.activeController?.placementLocation.addChild(cursor)
                    break
                case .mixed:
                    let cursor = try await ModelEntity(named: "pointer")
                    appModel.activeController?.placementLocation.addChild(cursor)
                    break
                case .none:
                    break
            }
        }
        
        appModel.viewModel?.prepare()
    }
    
    func resetView() {
        dataSource.removeAll()
    }
    
    func tapGestureEnded(_ value: EntityTargetValue<SpatialTapGesture.Value>) {
        if let activeController = appModel.activeController,
           let viewModel = appModel.viewModel {
            
            let side = activeController.localPlayer.side ?? .white
            var pointer: Int?
            
            // Determine pointer value based on game mode and board state.
            if activeController.game.mode == .mixed {
                pointer = viewModel.pointersPlaced == 0 ? 1 : 2
            } else if activeController.pieceEntities.isEmpty {
                pointer = 0
            }
            
            if let pointer = pointer {
                viewModel.placeBoard(
                    dataSource.insert(
                        side: side,
                        isSpatial: false,
                        isPointer: pointer
                    )
                )
            }
            
            if (viewModel.pointersPlaced == 1 || activeController.game.mode != .mixed) &&
               activeController.pieceEntities.isEmpty {
                activeController.startGame()
            }
        }
    }
    
    func dragGestureChanged(_ value: EntityTargetValue<SimultaneousGesture<DragGesture, RotateGesture3D>.Value>) {
        guard let activeController = appModel.activeController,
              activeController.game.stage == .inGame(.duringPlayersTurn) else {
            return
        }
        
        if sourceTransform == nil {
            sourceTransform = value.entity.transform
        }
        
        if activeController.currentlyMovingChessPiece == nil && activeController.currentlyMovingChessPieceCollisionSubscription == nil {
            activeController.setCurrentlyMovingChessPiece(entity: value.entity)
            activeController.playSoundEffect(SFX.pickUp)
        }

        if let rotation = value.second?.rotation {
            let rotationTransform = Transform(AffineTransform3D(rotation: rotation))
            value.entity.transform.rotation = sourceTransform!.rotation * rotationTransform.rotation
        } else if let transform = value.first?.location3D {
            value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false
            let location3D = value.convert(transform, from: .local, to: .scene)
            value.entity.setPosition(location3D, relativeTo: nil)
        }
    }
    
    func dragGestureEnded(_ value: EntityTargetValue<SimultaneousGesture<DragGesture, RotateGesture3D>.Value>) {
        sourceTransform = nil
        value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
        
        guard let activeController = appModel.activeController,
              activeController.game.stage == .inGame(.duringPlayersTurn) else {
            return
        }
        
        // If no target field exists, return the piece to its last known position.
        if activeController.currentTargetField.isEmpty {
            print("Return piece to initial position")
            activeController.movePieceToLastKnownPosition(piece: value.entity)
            return
        }
        
        guard let fieldEntity = activeController.currentTargetField.last,
              let piece = ChessPiece(rawValue: value.entity.name),
              let field = ChessField(rawValue: fieldEntity.name) else {
            return
        }
        
        print("Move piece to field")

        activeController.move(piece: piece, to: field, promotedPiece: nil) { success in
            if success {
                fieldEntity.components[OpacityComponent.self]?.opacity = 0.0
            } else {
                activeController.movePieceToLastKnownPosition(piece: value.entity)
                print("Return piece to initial position")
            }
        }
    }
}
