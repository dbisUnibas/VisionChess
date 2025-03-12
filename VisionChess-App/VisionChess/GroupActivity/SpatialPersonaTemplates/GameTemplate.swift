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
            .seat(position: .app.offsetBy(x: -1, z: 4), role: Role.white),
            .seat(position: .app.offsetBy(x: 1, z: 4), role: Role.black)
        ]
        
        let spectatorSeats: [any SpatialTemplateElement] = [
            .seat(position: .app.offsetBy(x: 4, z: 4)),
            .seat(position: .app.offsetBy(x: 4, z: 4)),
            .seat(position: .app.offsetBy(x: -4, z: 4)),
            .seat(position: .app.offsetBy(x: -4, z: 4))
        ]
        
        return playerSeats + spectatorSeats
    }
}
