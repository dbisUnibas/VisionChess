//
//  PersistedModel.swift
//  PlanePlopperDemo
//
//  Created by Danilo Campos on 2/28/24.
//

import Foundation
import SwiftData
import RealityKit
import SwiftUI
import RealityKitContent

@Model
class PersistedModel: AnchorableEntity {
        
    var timestamp: Date
    var worldAnchorID: UUID?
    
    var debugDescription: String {
        return self.timestamp.debugDescription
    }
    
    @Transient var renderContent: RealityKit.Entity? = .init()
    
    @MainActor
    func updateRenderContent(_ entity: RealityKit.Entity?) {
        if let entity {
            self.renderContent?.addChild(entity)
        }
    }
    
    func loadContent(side: PlayerModel.Side) {
        let rotation180Y = simd_quatf(angle: .pi, axis: [0, 1, 0])
        
        Task {
            let placeholder = try? await Entity(named: "Board", in: realityKitContentBundle)
            
            DispatchQueue.main.async {
                if side == .black {
                    placeholder?.orientation *= rotation180Y
                }
            }
        
            let transform = await placeholder?.findEntity(named: side.rawValue)
            await transform?.children.forEach {piece in
                Task {
                    await piece.components.set(HoverEffectComponent())
                }
            }
            await updateRenderContent(placeholder)
        }
    }
    
    init(timestamp: Date = .now, side: PlayerModel.Side) {
        self.timestamp = timestamp
        self.renderContent = .init()
        
        loadContent(side: side)
    }
}

