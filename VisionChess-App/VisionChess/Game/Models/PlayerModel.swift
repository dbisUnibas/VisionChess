/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A model that represents each player's state in the SharePlay group session.
*/

import Spatial
import SwiftUI

struct PlayerModel: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var name: String
    
    var score: Int = 0
    var isPlaying: Bool = false
    
    var side: Side? = nil
    var seatPose: Pose3D?
    
    enum Side: String, Codable, Hashable, Sendable {
        case white
        case black
        case spectator
    }
}

extension PlayerModel.Side {
    var name: String {
        switch self {
            case .white: "White"
            case .black: "Black"
            case .spectator: "Spectator"
        }
    }
    
    var color: Color {
        switch self {
            case .white: .white
            case .black: .black
            case .spectator: .orange
        }
    }
}
