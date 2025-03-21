//
//  GameTemplate.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import GroupActivities
import Spatial


struct GameTemplate: SpatialTemplate {
    enum Role: String, SpatialTemplateRole {
        case white
        case black
    }
    
    var elements: [any SpatialTemplateElement] {
        
        let playerSeats: [any SpatialTemplateElement] = [
            .seat(position: .app.offsetBy(x: -0.5, z: 0.5), direction: .lookingAt(.app.offsetBy(x: 0, z: 0.5)), role: Role.white),
            .seat(position: .app.offsetBy(x: 0.5, z: 0.5), direction: .lookingAt(.app.offsetBy(x: 0, z: 0.5)), role: Role.black)
        ]
        
        let spectatorSeats: [any SpatialTemplateElement] = [
            .seat(position: .app.offsetBy(x: 0.5, z: 1), direction: .lookingAt(.app.offsetBy(x: 0, z: 0.5))),
            .seat(position: .app.offsetBy(x: -0.25, z: 1), direction: .lookingAt(.app.offsetBy(x: 0, z: 0.5))),
            .seat(position: .app.offsetBy(x: 0.25, z: 1), direction: .lookingAt(.app.offsetBy(x: 0, z: 0.5))),
            .seat(position: .app.offsetBy(x: 0.5, z: 1), direction: .lookingAt(.app.offsetBy(x: 0, z: 0.5)))
        ]
        
        return playerSeats + spectatorSeats
    }
}
