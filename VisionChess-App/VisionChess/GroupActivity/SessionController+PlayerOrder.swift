/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A session controller extension that sorts the players in the app's current game.
*/

import Foundation
import GroupActivities

extension SessionController {
    func updateCurrentPlayer() {
        if game.stage.isInGame, localParticipantShouldBecomeActivePlayer {
            localPlayer.isPlaying = true
        }
    }
    
    var playerOrder: [Participant] {
        let firstPlayer = players.filter {
            $0.value.side == .white
        }
        .sorted(using: KeyPathComparator(\.key.id))
        .first?.key
        
        let secondPlayer = players.filter {
            $0.value.side == .black
        }
        .sorted(using: KeyPathComparator(\.key.id))
        .first?.key
        
        if let firstPlayer = firstPlayer, let secondPlayer = secondPlayer {
            return [firstPlayer, secondPlayer]
        }
        return []
    }
    
    var playerBeforeLocalParticipant: Participant? {
        guard let localParticipantIndex = playerOrder.firstIndex(of: session.localParticipant) else {
            return nil
        }
        
        if localParticipantIndex == 0 {
            return playerOrder.last
        } else {
            return playerOrder[localParticipantIndex - 1]
        }
    }
    
    var playerAfterLocalParticipant: PlayerModel? {
        guard let localParticipantIndex = playerOrder.firstIndex(of: session.localParticipant) else {
            return nil
        }
        
        let participant = if playerOrder.indices.contains(localParticipantIndex + 1) {
            playerOrder[localParticipantIndex + 1]
        } else {
            playerOrder.first
        }
        
        guard let participant else {
            return nil
        }
        
        return players[participant]
    }
    
    var currentPlayer: PlayerModel? {
        players.values.first(where: \.isPlaying)
    }
    
    var activeTeam: PlayerModel.Side? {
        return currentPlayer?.side
    }
    
    var localParticipantShouldBecomeActivePlayer: Bool {
        guard let playerBeforeLocalParticipant else {
            return false
        }
        
        guard let lastPlayer = game.moveHistory.last else {
            return playerOrder.first == session.localParticipant
        }
        
        let shouldBecomeActive = (lastPlayer == playerBeforeLocalParticipant.id)
        return shouldBecomeActive
    }
}
