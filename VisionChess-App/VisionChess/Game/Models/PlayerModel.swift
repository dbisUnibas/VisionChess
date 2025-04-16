//
//  PlayerModel.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import Spatial
import SwiftUI

struct PlayerModel: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var deviceId: String
    
    var score: Int = 0
    var isPlaying: Bool = false
    
    var side: Side? = nil
    var seatPose: Pose3D?
    
    enum Side: String, Codable, Hashable, Sendable {
        case white
        case black
    }
}

extension PlayerModel.Side {
    var name: String {
        switch self {
            case .white: "White"
            case .black: "Black"
        }
    }
    
    var color: Color {
        switch self {
            case .white: .white
            case .black: .black
        }
    }
}
