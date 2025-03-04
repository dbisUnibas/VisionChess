//
//  ChessPieceEntity.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.25.
//

import UIKit
import RealityKit

class ChessPieceEntity: Entity, HasModel, HasPhysics {
    let particleEntity: Entity
    
    deinit {
        print("Deinit ChessPieceEntity")
    }
    
    init(
        particleEntity: Entity
    ) {
        self.particleEntity = particleEntity
        super.init()
        commonInit()
    }
    
    @MainActor @preconcurrency required init() {
        fatalError("init() has not been implemented")
    }
    
    private func commonInit() {
        let colors: [UIColor] = [
            .black,
            .white
        ]
        
        let color = colors.randomElement()!
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.metallic = 0.2
        mat.roughness = 0.8
        
        let sphereRadius: Float = 0.001
        
        model = .init(
            mesh: .generateSphere(radius: sphereRadius),
            materials: [
                mat
            ]
        )
        
        let shape = ShapeResource.generateSphere(radius: sphereRadius)
        collision = CollisionComponent(shapes: [shape])
        physicsBody = PhysicsBodyComponent(
            shapes: [shape],
            mass: 0.2,
            mode: .dynamic
        )
        
        addChild(particleEntity)
        particleEntity.visit { entity in
            entity.modifyComponent(forType: ParticleEmitterComponent.self) { comp in
                comp.mainEmitter.color = .constant(.single(color))
            }
        }
    }
}
