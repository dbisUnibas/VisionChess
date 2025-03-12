//
//  SharePlayButton.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import CoreTransferable
import GroupActivities
import SwiftUI
import UIKit

struct SharePlayButton<ActivityType: GroupActivity & Transferable & Sendable>: View {
    @ObservedObject
    private var groupStateObserver = GroupStateObserver()
    
    @State
    private var isActivitySharingViewPresented = false
    
    @State
    private var isActivationErrorViewPresented = false
    
    private let activitySharingView: ActivitySharingView<ActivityType>
    
    let text: any StringProtocol
    let activity: ActivityType
    
    init(_ text: any StringProtocol, activity: ActivityType) {
        self.text = text
        self.activity = activity
        self.activitySharingView = ActivitySharingView {
            activity
        }
    }
    
    var body: some View {
        ZStack {
            ShareLink(item: activity, preview: SharePreview(text)).hidden()
            
            Button(text, systemImage: "shareplay") {
                if groupStateObserver.isEligibleForGroupSession {
                    Task.detached {
                        do {
                            _ = try await activity.activate()
                        } catch {
                            print("Error activating activity: \(error)")
                            
                            Task { @MainActor in
                                isActivationErrorViewPresented = true
                            }
                        }
                    }
                } else {
                    isActivitySharingViewPresented = true
                }
            }
            .tint(.green)
            .sheet(isPresented: $isActivitySharingViewPresented) {
                activitySharingView
            }
            .alert("Unable to start game", isPresented: $isActivationErrorViewPresented) {
                Button("Ok", role: .cancel) { }
            } message: {
                Text("Please try again later.")
            }
        }
    }
}

struct ActivitySharingView<ActivityType: GroupActivity & Sendable>: UIViewControllerRepresentable {
    let preparationHandler: () async throws -> ActivityType

    func makeUIViewController(context: Context) -> GroupActivitySharingController {
        GroupActivitySharingController(preparationHandler: preparationHandler)
    }

    func updateUIViewController(_: GroupActivitySharingController, context: Context) {}
}

struct SharePlayButton_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        SharePlayButton("Test", activity: ChessGroupActivity())
    }
}
