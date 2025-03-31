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
    
    struct ChessBoardPredictionResult: Hashable, Identifiable {
        let id: UUID
        let p: VNCoreMLFeatureValueObservation
        let var_1647: VNCoreMLFeatureValueObservation
        let pieces: [PredictionResult]
        
        init(id: UUID = .init(), p: VNCoreMLFeatureValueObservation, var_1647: VNCoreMLFeatureValueObservation, pieces: [PredictionResult]) {
            self.id = id
            self.p = p
            self.var_1647 = var_1647
            self.pieces = pieces
        }
    }
    
    struct PredictionResult: Hashable, Identifiable {
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
        let boundingBox: CGRect
        
        init(id: UUID = .init(), label: Label, confidence: Float, boundingBox: CGRect) {
            self.id = id
            self.label = label
            self.confidence = confidence
            self.boundingBox = boundingBox
        }
        
        func toString() -> String {
            return "\(label): \(confidence): \(boundingBox)"
        }
    }
    
    var requestDetection: VNCoreMLRequest?
    var requestSegmentation: VNCoreMLRequest?
    var visionModelDetection: VNCoreMLModel?
    var visionModelSegmentation: VNCoreMLModel?
    
    var lastExecutionDetection = Date()
    var isInferencing = false
    let semaphore = DispatchSemaphore(value: 1)
    
    lazy var objectSegmentationModel = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return try? ChessboardSegmentation(configuration: config)
    }()
    
    lazy var objectDectectionModel = {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        return try? ChessPieceDetectionModel(configuration: config)
    }()
    
    // MARK: - TableView Data
    let predictionsSubject: PassthroughSubject<ChessBoardPredictionResult, Never> = .init()
    
    init() {
        setUpModel()
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        guard let objectSegmentationModel = objectSegmentationModel else { fatalError("Failed to load the model") }
        if let visionModelSegmentation = try? VNCoreMLModel(for: objectSegmentationModel.model) {
            self.visionModelSegmentation = visionModelSegmentation
            // Create a VNCoreMLRequest that will handle the segmentation outputs.
            requestSegmentation = VNCoreMLRequest(model: visionModelSegmentation)
            requestSegmentation?.imageCropAndScaleOption = .scaleFill
            requestDetection?.preferBackgroundProcessing = true
        } else {
            fatalError("Failed to create vision model")
        }
        
        guard let objectDectectionModel = objectDectectionModel else { fatalError("fail to load the model") }
        if let visionModelDetection = try? VNCoreMLModel(for: objectDectectionModel.model) {
            self.visionModelDetection = visionModelDetection
            requestDetection = VNCoreMLRequest(model: visionModelDetection)
            requestDetection?.imageCropAndScaleOption = .scaleFill
            requestDetection?.preferBackgroundProcessing = true
        } else {
            fatalError("fail to create vision model")
        }
    }

    
    func detectUsingVision(pixelBuffer: CVPixelBuffer, isARKitBuffer: Bool) {
        guard !isInferencing else { return }
        guard let requestDetection = requestDetection, let requestSegmentation = requestSegmentation else { fatalError("Request is nil") }
        
        self.semaphore.wait()
        
        // let requestHandler = VNImageRequestHandler(url: Bundle.main.url(forResource: "test", withExtension: "png")!, orientation: .up)
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        do {
            try requestHandler.perform([requestDetection, requestSegmentation])
            
            guard let resultsSegmentation = requestSegmentation.results,
                  let resultsDetection = requestDetection.results as? [VNRecognizedObjectObservation]
            else {
                print("Error performing vision request!")
                return
            }
            
            let result_0 = resultsSegmentation[0] as! VNCoreMLFeatureValueObservation
            let result_1 = resultsSegmentation[1] as! VNCoreMLFeatureValueObservation
//            print(result_0.featureName)
//            print(result_1.featureName)
            
            let piecePredictions = resultsDetection.compactMap{ observation -> PredictionResult? in
                guard let label = observation.labels.first else {
                    return nil
                }
                if observation.confidence > 0.6, let predictionResultLabel = PredictionResult.Label(rawValue: label.identifier) {
                    return PredictionResult(label: predictionResultLabel, confidence: observation.confidence, boundingBox: observation.boundingBox)
                } else {
                    return nil
                }
            }
            
            let prediction = ChessBoardPredictionResult(p: result_0, var_1647: result_1, pieces: piecePredictions)
            
            DispatchQueue.main.async {
                if !piecePredictions.isEmpty {
                    self.predictionsSubject.send(prediction)
                }
                self.isInferencing = false
                self.semaphore.signal()
            }
        } catch {
            print("Error performing vision request: \(error)")
            semaphore.signal()
            isInferencing = false
        }
    }
}
