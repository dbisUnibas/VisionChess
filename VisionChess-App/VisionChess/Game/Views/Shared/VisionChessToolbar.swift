/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Implementation for the Guess Together view modifier.
*/

import SwiftUI

struct VisionChessToolbarModifier: ViewModifier {
    @Environment(AppModel.self) var appModel
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        ZStack {
                            Image("AppIcon/Back/Content")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48)
                            Image("AppIcon/Middle/Content")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 38)
                            Image("AppIcon/Front/Content")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24)
                        }
                        .clipShape(.circle)
                        
                        Text("VisionChess")
                    }
                    .font(.largeTitle)
                    .italic()
                }
                
            }
            .toolbarRole(.navigationStack)
    }
}

// A convenience custom modifier wrapper.
extension View {
    func guessTogetherToolbar() -> some View {
        return modifier(VisionChessToolbarModifier())
    }
}
