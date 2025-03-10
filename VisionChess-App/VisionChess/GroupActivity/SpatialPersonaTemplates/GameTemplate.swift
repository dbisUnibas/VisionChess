/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The custom spatial template used to arrange spatial Personas
  during Guess Together's game stage.
*/

import GroupActivities
import Spatial


struct GameTemplate: SpatialTemplate {
    enum Role: String, SpatialTemplateRole {
        case white
        case black
        case spectator
    }
    
    var elements: [any SpatialTemplateElement] {
        
        let playerSeats: [any SpatialTemplateElement] = [
            .seat(position: .app.offsetBy(x: -1, z: 4), role: Role.white),
            .seat(position: .app.offsetBy(x: 1, z: 4), role: Role.black)
        ]
        
        let spectatorSeats: [any SpatialTemplateElement] = [
            .seat(position: .app.offsetBy(x: 4, z: 4), role: Role.spectator),
            .seat(position: .app.offsetBy(x: 4, z: 4), role: Role.spectator),
            .seat(position: .app.offsetBy(x: -4, z: 4), role: Role.spectator),
            .seat(position: .app.offsetBy(x: -4, z: 4), role: Role.spectator)
        ]
        
        return playerSeats + spectatorSeats
    }
}
