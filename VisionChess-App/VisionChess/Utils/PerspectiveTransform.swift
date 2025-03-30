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

// Get the center of a normalized bounding box
func center(of rect: CGRect) -> CGPoint {
    return CGPoint(x: rect.midX, y: (1.0 - rect.midY) + rect.height/4.0)
}

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
