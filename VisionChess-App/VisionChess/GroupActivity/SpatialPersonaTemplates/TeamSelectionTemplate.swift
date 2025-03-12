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
    
    /// An array of seating positions the game uses to position spatial Personas during the team-selection stage.
    ///
    /// The game fills the seats with participants based on the order of the array's elements.
    let elements: [any SpatialTemplateElement] = [
        // Blue team:
        .seat(position: .app.offsetBy(x: -2.5, z: 3.5), role: Role.white),
        .seat(position: .app.offsetBy(x: -3.0, z: 3.0), role: Role.white),
        .seat(position: .app.offsetBy(x: -3.5, z: 2.5), role: Role.white),
        
        // Starting positions:
        .seat(position: .app.offsetBy(x: 0, z: 4)),
        .seat(position: .app.offsetBy(x: 1, z: 4)),
        .seat(position: .app.offsetBy(x: -1, z: 4)),
        .seat(position: .app.offsetBy(x: 2, z: 4)),
        .seat(position: .app.offsetBy(x: -2, z: 4)),
        
        // Red team:
        .seat(position: .app.offsetBy(x: 2.5, z: 3.5), role: Role.black),
        .seat(position: .app.offsetBy(x: 3.0, z: 3.0), role: Role.black),
        .seat(position: .app.offsetBy(x: 3.5, z: 2.5), role: Role.black)
    ]
}
