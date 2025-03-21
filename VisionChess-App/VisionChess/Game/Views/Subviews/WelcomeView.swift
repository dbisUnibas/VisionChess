//
//  WelcomeView.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct WelcomeView: View {
    @Environment(AppModel.self) var appModel
    public var basePath = UserDefaults.standard.string(forKey: "app_base_url") ?? "http://10.34.64.140:8090"
    @State var connectionEstablished: Bool = false
    
    var body: some View {
        VStack {
            WelcomeBanner()
            
            HStack(alignment: .center, spacing: 24) {
                Text("♚")
                    .italic()
                    .padding(.bottom, 14)
                    .font(.extraLargeTitle)
                Text("VisionChess")
                    .italic()
                    .font(.extraLargeTitle)
                Text("♛")
                    .italic()
                    .padding(.bottom, 14)
                    .font(.extraLargeTitle)
                
            }
            
            Text("Welcome to VisionChess!")
                .multilineTextAlignment(.center)
                .padding(.top)
            
            Text("""
                To play, join a FaceTime call with a friend or practice on your own.
                You'll join a side and take turns playing chess.
                """
            )
            .multilineTextAlignment(.center)
            .padding(.bottom)
            .padding(.horizontal)
            
            
            HStack(spacing: 36.0) {
                SharePlayButton("Play together!", activity: ChessGroupActivity())
                    .padding(.vertical, 20)
                    .disabled(!connectionEstablished)
                
                Button("Training", systemImage: "chart.line.uptrend.xyaxis") {
                    appModel.gameController = GameController()
                }
                .tint(.teal)
                .disabled(!connectionEstablished)
            }
            
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkAndRetryConnection(urlString: basePath)
            }
        }
    }
}

struct WelcomeBanner: View {
    @State private var bounce = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 48.0) {
            Model3D(named: "black-queen")
                .scaleEffect(2)
                .frame(depth: 46, alignment: .center)
                .bouncing(bounce: bounce)
            
            
            Model3D(named: "black-king")
                .scaleEffect(2)
                .frame(depth: 46, alignment: .center)
                .bouncing(bounce: bounce)
            
            ZStack {
                Image("AppIcon/Back/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128)
                Image("AppIcon/Middle/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 112)
                Image("AppIcon/Front/Content")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 78)
            }
            .clipShape(.circle)
            
            Model3D(named: "white-king")
                .scaleEffect(2)
                .frame(depth: 46, alignment: .center)
                .bouncing(bounce: bounce)
            
            Model3D(named: "white-queen")
                .scaleEffect(2)
                .frame(depth: 46, alignment: .center)
                .bouncing(bounce: bounce)
        }
        .font(.system(size: 50))
        .frame(maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                bounce.toggle()
            }
        }
    }
}

extension WelcomeView {
    func checkServerConnection(urlString: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                completion(true)
            } else {
                completion(false)
            }
        }

        task.resume()
    }
    
    func checkAndRetryConnection(urlString: String, retryDelay: TimeInterval = 5.0) {
        checkServerConnection(urlString: urlString) { connected in
            DispatchQueue.main.async {
                connectionEstablished = connected
                
                if !connected {
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        checkAndRetryConnection(urlString: urlString, retryDelay: retryDelay)
                    }
                }
            }
        }
    }
}

struct BounceEffect: ViewModifier {
    var bounce: Bool
    var amount: CGFloat = 3
    var duration: Double = 1.0

    func body(content: Content) -> some View {
        content
            .offset(y: bounce ? -amount : amount)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: bounce
            )
    }
}

extension View {
    func bouncing(bounce: Bool, amount: CGFloat = 3, duration: Double = 1.0) -> some View {
        self.modifier(BounceEffect(bounce: bounce, amount: amount, duration: duration))
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static let appModel = AppModel()

    static var previews: some View {
        WelcomeView()
            .environment(appModel)
            .glassBackgroundEffect()
            .frame(width: 900, height: 600)
    }
}
