//
//  ChessGroupActivity.swift
//  VisionChess
//
//  Created by Tim Bachmann on 01.03.2025.
//

import Foundation
import GroupActivities
import UIKit
import CoreTransferable

struct ChessGroupActivity: GroupActivity, Transferable, Sendable {
    static let activityIdentifier = "de.timbachmann.VisionChess"

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "VisionChess SharePlay"
        metadata.subtitle = "Let's play together!"
        metadata.previewImage = UIImage(systemName: "shareplay")?.cgImage
        metadata.type = .generic
        return metadata
    }
}
