//
//  RateLimiter.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation

class RateLimiter {
    private let capacity: Int
    private let refillRate: Double // Tokens per second
    private var tokens: Double
    private var lastRefillTime: Date

    init(capacity: Int, refillRate: Double) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.tokens = Double(capacity)
        self.lastRefillTime = Date()
    }

    func tryConsume(tokens: Int = 1) -> Bool {
        refill()
        if Double(tokens) <= self.tokens {
            self.tokens -= Double(tokens)
            return true
        } else {
            return false
        }
    }

    private func refill() {
        let now = Date()
        let timeSinceLastRefill = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = timeSinceLastRefill * refillRate
        self.tokens = min(Double(capacity), self.tokens + tokensToAdd)
        self.lastRefillTime = now
    }
}
