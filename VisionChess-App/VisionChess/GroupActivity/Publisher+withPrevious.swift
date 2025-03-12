//
//  Publisher+withPrevious.swift
//  VisionChess
//
//  Created by Tim Bachmann on 12.03.2025.
//

import Combine

extension Combine.Publisher {
    func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
        scan(nil) { previousWithPrevious, currentElement in
            (previous: previousWithPrevious?.current, current: currentElement)
        }
        .compactMap { $0 }
        .eraseToAnyPublisher()
    }
}
