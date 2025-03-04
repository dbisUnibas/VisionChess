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
    
    @State var viewModel: GameViewModel = .init()
    @State var currentDragTransformStart: Transform? = nil
    @State private var sourceTransform: Transform?
    
    
    let modelContainer: ModelContainer
    let dataSource: ModelDataSource
    
    init() {
        do {
            modelContainer = try ModelContainer(for: PersistedModel.self)
            dataSource = .init(context: modelContainer.mainContext)
            viewModel.dataSource = dataSource
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }
    
    var body: some View {
        RealityView { content, attachments in
            Task {
                dataSource.removeAll()
            }
            
            await viewModel.loadResources()
            
            let cameraFeedVisualizationEntity = viewModel.cameraFeedVisualizationEntity
            
            if let mainViewEntity = attachments.entity(for: ViewAttachment.mainView.rawValue) {
                viewModel.contentContainerEntity.addChild(mainViewEntity)
            }
            
            guard let scene else {
                return
            }
            viewModel.prepare(withContent: content, andScene: scene)
            
        } update: { content, attachments in
            if (viewModel.viewState == .setup && !content.entities.contains(where: {$0 == viewModel.utilityEntities.contentEntity})) {
                content.add(viewModel.utilityEntities.contentEntity)
            }
            
            if let rightUIViewEntity = attachments.entity(for: ViewAttachment.uiRightView.rawValue) {
                if (viewModel.viewState == .playing) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        var transform = rightUIViewEntity.transform
                        transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1.0, 0.0, 0.0])
                        rightUIViewEntity.transform = transform
                        viewModel.utilityEntities.contentEntity.findEntity(named: "ui_right_transform")?.addChild(rightUIViewEntity)
                    }
                }
                
            }
            
            
            if let leftUIViewEntity = attachments.entity(for: ViewAttachment.uiLeftView.rawValue) {
                if (viewModel.viewState == .playing) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        var transform = leftUIViewEntity.transform
                        transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1.0, 0.0, 0.0])
                        leftUIViewEntity.transform = transform
                        viewModel.utilityEntities.contentEntity.findEntity(named: "ui_left_transform")?.addChild(leftUIViewEntity)
                    }
                }
            }
            
            if let bottomUIViewEntity = attachments.entity(for: ViewAttachment.uiBottomView.rawValue) {
                if (viewModel.viewState == .playing) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        var transform = bottomUIViewEntity.transform
                        transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1.0, 0.0, 0.0])
                        bottomUIViewEntity.transform = transform
                        viewModel.utilityEntities.contentEntity.findEntity(named: "ui_bottom_transform")?.addChild(bottomUIViewEntity)
                    }
                }
            }
            
            viewModel.handleCollisions(content: content)
            
        } attachments: {
            Attachment(id: ViewAttachment.mainView.rawValue) {
                mainView
            }
            
            Attachment(id: ViewAttachment.uiLeftView.rawValue) {
                uiLeftView
            }
            
            Attachment(id: ViewAttachment.uiRightView.rawValue) {
                uiRightView
            }
            
            Attachment(id: ViewAttachment.uiBottomView.rawValue) {
                uiBottomView
            }
            
            Attachment(id: ViewAttachment.debugView.rawValue) {
                debugView
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if (viewModel.viewState == .setup) {
                        viewModel.placeBoard(dataSource.insert())
                    }
                }
        )
        .gesture(
            DragGesture()
                .simultaneously(with: RotateGesture3D(constrainedToAxis: .y))
                .targetedToAnyEntity()
                .handActivationBehavior(.pinch)
                .onChanged { value in
                    if viewModel.gameManager?.currentSide != .white {
                        return
                    }
                    
                    if sourceTransform == nil {
                        sourceTransform = value.entity.transform
                    }
                    
                    if viewModel.currentlyMovingChessPiece == nil && viewModel.currentlyMovingChessPieceCollisionSubscription == nil {
                        viewModel.currentlyMovingChessPiece = value.entity
                    }

                    if let rotation = value.second?.rotation {
                        let rotationTransform = Transform(AffineTransform3D(rotation: rotation))
                        value.entity.transform.rotation = sourceTransform!.rotation * rotationTransform.rotation
                    } else if let transform = value.first?.location3D {
                        value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = false
                        let location3D = value.convert(transform, from: .local, to: .scene)
                        Task {
                            await viewModel.moveCube(entity: value.entity, to: location3D)
                        }
                    }
                }
                .onEnded { value in
                    sourceTransform = nil
                    value.entity.components[PhysicsBodyComponent.self]?.isAffectedByGravity = true
                    
                    if viewModel.currentTargetField.isEmpty || viewModel.gameManager?.currentSide != .white {
                        return
                    }
                    
                    let fieldEntity = viewModel.currentTargetField.last!
                    viewModel.gameManager?.move(piece: ChessPiece(rawValue: value.entity.name)!, to: ChessField(rawValue: fieldEntity.name)!) { success in
                        if success {
                            fieldEntity.components[OpacityComponent.self]?.opacity = 0.0
                            viewModel.currentTargetField = []
                            viewModel.currentlyMovingChessPiece = nil
                            viewModel.currentlyMovingChessPieceCollisionSubscription?.cancel()
                            viewModel.currentlyMovingChessPieceCollisionSubscription = nil
                            viewModel.currentlyMovingChessPieceCollisionSubscriptionEnd?.cancel()
                            viewModel.currentlyMovingChessPieceCollisionSubscriptionEnd = nil
                            viewModel.deactivateInput()
                        } else {
                            if let initialField = viewModel.currentlyMovingChessPieceInitialField {
                                viewModel.gameManager?.animateMove(piece: value.entity, field: initialField)
                                initialField.components[OpacityComponent.self]?.opacity = 0.4
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    initialField.components[OpacityComponent.self]?.opacity = 0.0
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        initialField.components[OpacityComponent.self]?.opacity = 0.4
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            initialField.components[OpacityComponent.self]?.opacity = 0.0
                                            
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                viewModel.errorMessage = nil
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
            viewModel.handleViewDidAppear()
        }
        .task {
            print("awaiting anchor updates")
            await viewModel.processWorldAnchorUpdates()
        }
        .task {
            await viewModel.processDeviceAnchorUpdates()
        }
        .task {
            await viewModel.processPlaneDetectionUpdates()
        }
        .task {
            viewModel.registerGroupActivity()
        }
        .task {
            viewModel.configureGroupSession()
        }
    }
    
    @ViewBuilder
    var mainView: some View {
        VStack {
            switch viewModel.viewState {
            case .initializing:
                ProgressView()
            case .preGame:
                PreGameView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
            case .inModeSelection:
                ModeSelection(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
            case .inGameMenu:
                GameMenuView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
            case .setup:
                BoardSetupView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
            case .playing:
                EmptyView()
            case .gameOver:
                GameEndView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: 800, height: 600)
        .animation(.smooth, value: viewModel.viewState)
    }
    
    @ViewBuilder
    var uiRightView: some View {
        GamePlayingViewRight(viewModel: viewModel)
            .frame(width: 400, height: 600)
            .animation(.smooth, value: viewModel.viewState)
            .transition(.opacity.combined(with: .scale))
    }
    
    @ViewBuilder
    var uiLeftView: some View {
        GamePlayingViewLeft(viewModel: viewModel)
            .frame(width: 400, height: 600)
            .animation(.smooth, value: viewModel.viewState)
            .transition(.opacity.combined(with: .scale))
    }
    
    @ViewBuilder
    var uiBottomView: some View {
        GamePlayingViewBottom(viewModel: viewModel)
            .frame(width: 400, height: 600)
            .animation(.smooth, value: viewModel.viewState)
            .transition(.opacity.combined(with: .scale))
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
                if let predictions = viewModel.predictions, !predictions.isEmpty {
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
                if let predictions = viewModel.predictions, predictions.contains(where: { $0.isBallInAir && $0.confidence > 0.6 }) {
                    Color(uiColor: .systemGreen).opacity(0.5)
                        .blendMode(.overlay)
                        .clipShape(shape)
                }
            }
            .glassBackgroundEffect(in: shape)
        }
    }
    
    @ViewBuilder
    var debugView: some View {
        switch viewModel.viewState {
        case .initializing:
            VStack {
                ProgressView("Initializing")
            }
        case .playing:
            makeStatusContainerView {
                predictionsView
                
                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                        Text("Error: \(error.localizedDescription)")
                    }
                    .foregroundStyle(Color(uiColor: .systemRed))
                }
            }
        case .preGame, .inModeSelection, .inGameMenu, .setup, .gameOver:
            EmptyView()
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

//#Preview(immersionStyle: .mixed) {
//    ImmersiveView()
//        .environment(AppModel())
//}
#endif
