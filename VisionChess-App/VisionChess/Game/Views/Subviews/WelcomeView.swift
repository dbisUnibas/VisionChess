/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The implementation for the welcome view.
*/

import SwiftUI
import RealityKit

/// A view that introduces the Guess Together game, and invites the person to
/// create a SharePlay group session with the current FaceTime call.
///
/// ```
/// ┌───────────────────────────────────────┐
/// │                                       │
/// │               {   *   }               │
/// │                                       │
/// │            Guess Together!            │
/// │                                       │
/// │                                       │
/// │   Welcome! To play, join a FaceTime   │
/// │                call...                │
/// │              ┌─────────┐              │
/// │              │ Play  ▶ │              │
/// │              └─────────┘              │
/// └───────────────────────────────────────┘
/// ```
struct WelcomeView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        VStack {
            WelcomeBanner().offset(y: 20)
            
            Text("VisionChess").italic().font(.extraLargeTitle)
            
            Text("""
                Welcome to VisionChess! \
                To play, join a FaceTime call with a friend. \
                You'll join a side and take turns playing chess.
                """
            )
            .multilineTextAlignment(.center)
            .padding()
            
            SharePlayButton("Play together!", activity: ChessGroupActivity())
                .padding(.vertical, 20)
        }
        .padding(.horizontal)
    }
}

struct WelcomeBanner: View {
    var body: some View {
        HStack(alignment: .center, spacing: 48.0) {
            Model3D(named: "black-knight")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            Model3D(named: "black-bishop")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            Model3D(named: "black-queen")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            Model3D(named: "black-king")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            
            ZStack {
                Image("AppIcon/Back/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 86)
                Image("AppIcon/Middle/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72)
                Image("AppIcon/Front/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)
            }
            .clipShape(.circle)
            
            Model3D(named: "white-king")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            Model3D(named: "white-queen")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            Model3D(named: "white-bishop")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
            Model3D(named: "white-knight")
                .scaleEffect(x: 2.0, y: 2.0, z: 2.0)
        }
        .font(.system(size: 50))
        .frame(maxHeight: .infinity)
    }
}
