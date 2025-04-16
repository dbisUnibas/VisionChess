//
//  PerspectiveTransform.swift
//  VisionChess
//
//  Created by Tim Bachmann on 28.03.2025.
//

import Foundation
import CoreGraphics
import Accelerate
import simd
import Vision
import UIKit


struct PerspectiveTransform {
    let h: [CGFloat]  // 9 coefficients of the 3x3 matrix

    /// Initializes the perspective transform from 4 source to 4 destination points.
    init?(source: [CGPoint], destination: [CGPoint]) {
        guard source.count == 4 && destination.count == 4 else { return nil }
        
        // Build the 8x9 matrix from the point correspondences.
        // For each correspondence (x, y) -> (u, v):
        //   x·h₀ + y·h₁ + 1·h₂ - u·(h₆·x + h₇·y + 1) = 0
        //   x·h₃ + y·h₄ + 1·h₅ - v·(h₆·x + h₇·y + 1) = 0
        var matrix: [[CGFloat]] = []
        for i in 0..<4 {
            let src = source[i]
            let dst = destination[i]
            let x = src.x, y = src.y, u = dst.x, v = dst.y

            // Equation for u coordinate
            matrix.append([ x,  y, 1, 0, 0, 0, -u*x, -u*y, u ])
            // Equation for v coordinate
            matrix.append([ 0, 0, 0,  x,  y, 1, -v*x, -v*y, v ])
        }
        
        // We now have an 8x9 matrix.
        // We need to solve for the 8 unknowns [h0 ... h7] (with h8 set to 1).
        guard let solution = PerspectiveTransform.solve(matrix: matrix) else { return nil }
        
        // Append h8 = 1 to complete the 3x3 matrix.
        self.h = solution + [1]
    }
    
    /// Transforms a point from the source space to the destination space.
    func transform(point: CGPoint) -> CGPoint {
        let denominator = h[6]*point.x + h[7]*point.y + 1
        let u = (h[0]*point.x + h[1]*point.y + h[2]) / denominator
        let v = (h[3]*point.x + h[4]*point.y + h[5]) / denominator
        return CGPoint(x: u, y: v)
    }
    
    /// Solves an 8x9 system of linear equations using Gaussian elimination.
    /// Returns an array of 8 coefficients [h0 ... h7] if successful.
    private static func solve(matrix: [[CGFloat]]) -> [CGFloat]? {
        var mat = matrix // Copy of the matrix for elimination
        let n = 8  // number of unknowns

        // Forward elimination
        for i in 0..<n {
            // Find the pivot row
            var maxRow = i
            for k in (i+1)..<n {
                if abs(mat[k][i]) > abs(mat[maxRow][i]) {
                    maxRow = k
                }
            }
            // Check for a singular matrix
            if abs(mat[maxRow][i]) < 1e-10 { return nil }
            
            // Swap current row with the pivot row if needed
            if i != maxRow {
                mat.swapAt(i, maxRow)
            }
            
            // Normalize the pivot row
            let pivot = mat[i][i]
            for j in i..<n+1 {
                mat[i][j] /= pivot
            }
            
            // Eliminate the current column in rows below
            for k in (i+1)..<n {
                let factor = mat[k][i]
                for j in i..<n+1 {
                    mat[k][j] -= factor * mat[i][j]
                }
            }
        }
        
        // Back substitution
        var solution = [CGFloat](repeating: 0, count: n)
        for i in stride(from: n-1, through: 0, by: -1) {
            solution[i] = mat[i][n]
            for j in (i+1)..<n {
                solution[i] -= mat[i][j] * solution[j]
            }
        }
        return solution
    }
}

func orderPoints(pts: [CGPoint]) -> [CGPoint] {
    let sums = pts.map { $0.x + $0.y }
    let diffs = pts.map { $0.y - $0.x }
    
    var rect = [CGPoint](repeating: CGPoint.zero, count: 4)
    
    if let topLeftIndex = sums.enumerated().min(by: { $0.element < $1.element })?.offset {
        rect[0] = pts[topLeftIndex]
    }
    if let bottomRightIndex = sums.enumerated().max(by: { $0.element < $1.element })?.offset {
        rect[2] = pts[bottomRightIndex]
    }
    if let topRightIndex = diffs.enumerated().min(by: { $0.element < $1.element })?.offset {
        rect[1] = pts[topRightIndex]
    }
    if let bottomLeftIndex = diffs.enumerated().max(by: { $0.element < $1.element })?.offset {
        rect[3] = pts[bottomLeftIndex]
    }
    
    return rect
}


func getCornerPoints(_ boundingBox: CGRect, masks: MLMultiArray, bestMaskIdx: Int) -> [CGPoint] {
    let imageViewWidth = CGFloat(640)
    let imageViewHeight = CGFloat(640)
    let scaledX : CGFloat = (boundingBox.minX/640)*imageViewWidth
    let scaledY : CGFloat = (boundingBox.minY/640)*imageViewHeight
    let scaledWidth : CGFloat = (boundingBox.width/640)*imageViewWidth
    let scaledHeight : CGFloat = (boundingBox.height/640)*imageViewHeight
    
    let rectangle = CGRect(x: scaledX, y: scaledY, width: scaledWidth, height: scaledHeight)
    
    let maskProbThreshold : Float = 0.4
    var maskProbalities : [[Float]] = [] //this will contains 160x160 mask pixel probablities
    var maskProbYAxis : [Float] = []
    
    let mask_x_min = (rectangle.minX/imageViewWidth)*160
    let mask_x_max = (rectangle.maxX/imageViewWidth)*160
    
    let mask_y_min = (rectangle.minY/imageViewHeight)*160
    let mask_y_max = (rectangle.maxY/imageViewHeight)*160
    
    for y in 0..<masks.shape[2].intValue{
        maskProbYAxis.removeAll()
        for x in 0..<masks.shape[3].intValue{
            let pointKey = [0, bestMaskIdx, y, x] as [NSNumber]
            if(sigmoid(z: masks[pointKey].floatValue) > maskProbThreshold
               && x >=  Int(mask_x_min) && x <= Int(mask_x_max)
            && y >= Int(mask_y_min) && y <= Int(mask_y_max)){
                maskProbYAxis.append(1.0)
            } else {
                maskProbYAxis.append(0.0)
            }
        }
        maskProbalities.append(maskProbYAxis)
    }
    
    var finalPoints: [CGPoint] = []
    for y in 0..<maskProbalities.count {
        for x in 0..<maskProbalities[y].count{
            
            let xFactor = Float(imageViewWidth)/160
            let yFactor = Float(imageViewHeight)/160
            let maskScaled_X = Double(x) * Double(xFactor)
            let maskScaled_Y = Double(y) * Double(yFactor)
            
            if(maskProbalities[y][x] == 1.0) {
                finalPoints.append(CGPoint(x: maskScaled_X, y: maskScaled_Y))
            }
        }
    }
    
    return orderPoints(pts: finalPoints)
}

private func sigmoid(z:Float) -> Float{
    return 1.0/(1.0+exp(z))
}

func getBoundingBox(feature: MLMultiArray) -> (CGRect, Int) {
    var boundingBox = CGRect(x: 0,y: 0,width: 10,height: 10)
    
    var bestMaskIdx = 0
    var probMaxIdx = 0
    var maxProb : Float = 0
    var box_x : Float = 0
    var box_y : Float = 0
    var box_width : Float = 0
    var box_height : Float = 0
    
    for j in 0..<feature.shape[2].intValue-1
    {
        let key = [0,4,j] as [NSNumber]
        let nextKey = [0,4,j+1] as [NSNumber]
        if(feature[key].floatValue < feature[nextKey].floatValue){
            if(maxProb < feature[nextKey].floatValue){
                probMaxIdx = j+1
                let xKey = [0,0,probMaxIdx] as [NSNumber]
                let yKey = [0,1,probMaxIdx] as [NSNumber]
                let widthKey = [0,2,probMaxIdx] as [NSNumber]
                let heightKey = [0,3,probMaxIdx] as [NSNumber]
                maxProb = feature[nextKey].floatValue
                box_width = feature[widthKey].floatValue
                box_height = feature[heightKey].floatValue
                
                box_x = feature[xKey].floatValue - (box_width/2)
                box_y = feature[yKey].floatValue - (box_height/2)
            }
        }
    }
    boundingBox = CGRect(x: CGFloat(box_x)
                         ,y: CGFloat(box_y)
                         ,width: CGFloat(box_width)
                         ,height: CGFloat(box_height))
    var maxMaskProb : Float = 0
    var maxMaskIdx = 0
    for maskPrbIdx in 5..<feature.shape[1].intValue-1{
        let key = [0,maskPrbIdx,probMaxIdx] as [NSNumber]
        let nextKey = [0,maskPrbIdx+1,probMaxIdx] as [NSNumber]
        if(feature[key].floatValue < feature[nextKey].floatValue){
            if(maxMaskProb < feature[nextKey].floatValue){
                maxMaskIdx = maskPrbIdx+1
                maxMaskProb = feature[nextKey].floatValue
            }
        }
        bestMaskIdx = maxMaskIdx-5
    }
    return (boundingBox, bestMaskIdx)
}

// Get the center of a normalized bounding box
func center(of rect: CGRect) -> CGPoint {
    return CGPoint(x: rect.midX, y: (1.0 - rect.midY) + rect.height/4.0)
}

func drawPointsOnImage(named imageName: String, normalizedPoints: [CGPoint]) -> UIImage? {
    guard let image = UIImage(named: imageName),
          let cgImage = image.cgImage else {
        print("Image not found")
        return nil
    }

    let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

    // Begin drawing context
    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
    image.draw(in: CGRect(origin: .zero, size: imageSize))

    guard let context = UIGraphicsGetCurrentContext() else {
        UIGraphicsEndImageContext()
        return nil
    }

    context.setFillColor(UIColor.red.cgColor)

    // Draw circles at each normalized point
    for point in normalizedPoints {
        let pixelPoint = CGPoint(x: point.x * imageSize.width, y: point.y * imageSize.height)
        let dotSize: CGFloat = 8.0
        let dotRect = CGRect(x: pixelPoint.x - dotSize / 2, y: pixelPoint.y - dotSize / 2, width: dotSize, height: dotSize)
        context.fillEllipse(in: dotRect)
    }

    let resultImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resultImage
}
