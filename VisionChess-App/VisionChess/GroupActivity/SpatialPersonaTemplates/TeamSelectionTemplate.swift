//
//  TeamSelectionTemplate.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import GroupActivities

struct TeamSelectionTemplate: SpatialTemplate {
    enum Role: String, SpatialTemplateRole {
        case white
        case black
    }
    
    let elements: [any SpatialTemplateElement] = [
        .seat(position: .app.offsetBy(x: -1.5, z: 3), role: Role.white),
        
        .seat(position: .app.offsetBy(x: 0, z: 3)),
        .seat(position: .app.offsetBy(x: 0.5, z: 3)),
        .seat(position: .app.offsetBy(x: -0.5, z: 3)),
        .seat(position: .app.offsetBy(x: 1, z: 3)),
        .seat(position: .app.offsetBy(x: -1, z: 3)),
        
        .seat(position: .app.offsetBy(x: 1.5, z: 3), role: Role.black)
    ]
}
