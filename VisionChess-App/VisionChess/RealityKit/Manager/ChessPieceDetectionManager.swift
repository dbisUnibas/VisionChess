//
//  ChessPieceDetectionManager.swift
//  VisionChess
//
//  Created by Tim Bachmann on 05.02.2025.
//

import UIKit
import Vision
import CoreMedia
import Combine

class ChessPieceDetectionManager {
    
    struct PredictionResult: Identifiable {
        enum Label: String {
            case blackKing = "black-king"
            case blackQueen = "black-queen"
            case blackBishop = "black-bishop"
            case blackKnight = "black-knight"
            case blackRook = "black-rook"
            case blackPawn = "black-pawn"
            case whiteKing = "white-king"
            case whiteQueen = "white-queen"
            case whiteBishop = "white-bishop"
            case whiteKnight = "white-knight"
            case whiteRook = "white-rook"
            case whitePawn = "white-pawn"
        }
        
        let id: UUID
        let label: Label
        let confidence: Float
        
        var isBallInAir: Bool {
            label == .whiteKing
        }
        
        init(id: UUID = .init(), label: Label, confidence: Float) {
            self.id = id
            self.label = label
            self.confidence = confidence
        }
    }
    
    // MARK: - Vision Properties
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    var isInferencing = false
    
    let semaphore = DispatchSemaphore(value: 1)
    var lastExecution = Date()
    
    lazy var objectDectectionModel = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return try? ChessPieceDetectionModel(configuration: config)
    }()
    
    // MARK: - TableView Data
    let predictionsSubject: PassthroughSubject<[PredictionResult], Never> = .init()
    
    init() {
        setUpModel()
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        guard let objectDectectionModel = objectDectectionModel else { fatalError("fail to load the model") }
        if let visionModel = try? VNCoreMLModel(for: objectDectectionModel.model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
    }
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer, isARKitBuffer: Bool) {
        guard !isInferencing else {
            return
        }
        
        print("predictUsingVision")
        
        guard let request = request else { fatalError() }
        
        // vision framework configures the input size of image following our model's input configuration automatically
        self.semaphore.wait()
        let handler: VNImageRequestHandler
        
        if isARKitBuffer {
            //            handler = VNImageRequestHandler(
            //                cvPixelBuffer: pixelBuffer,
            //                orientation: .leftMirrored,
            //                options: [:]
            //            )
            handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            
            // TODO: Check why this is needed on visionOS
            #if os(visionOS)
            //            request.preferBackgroundProcessing = true
            request.usesCPUOnly = true
            #endif
        } else {
            handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        }
        
        try? handler.perform([request])
    }
    
    // MARK: - Post-processing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let error {
            print("Prediction error: \(error)")
            return
        }
        
        print("prediction results: \(String(describing: request.results))")
            
            if let visionPredictions = request.results as? [VNRecognizedObjectObservation] {
                let predictions = visionPredictions.compactMap{ observation -> PredictionResult? in
                    guard let label = observation.labels.first else {
                        return nil
                    }
                    let predictionResultLabel = PredictionResult.Label(rawValue: label.identifier)
                    return PredictionResult(label: predictionResultLabel ?? PredictionResult.Label.blackBishop, confidence: observation.confidence)
                }
                DispatchQueue.main.async {
                    if !predictions.isEmpty {
                        self.predictionsSubject.send(predictions)
                    }
                    self.isInferencing = false
                }
            } else {
                self.isInferencing = false
            }
//        if let visionPredictions = request.results as? [VNClassificationObservation] {
//            let predictions = visionPredictions.compactMap { observation -> PredictionResult? in
//                guard let label = PredictionResult.Label(rawValue: observation.identifier) else {
//                    return nil
//                }
//                return PredictionResult(label: label, confidence: observation.confidence)
//            }
//            DispatchQueue.main.async {
//                if !predictions.isEmpty {
//                    self.predictionsSubject.send(predictions)
//                }
//                self.isInferencing = false
//            }
//        } else {
//            self.isInferencing = false
//        }
        self.semaphore.signal()
        
    }
}
