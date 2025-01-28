//
//  RateLimiter.swift
//  Mustard
//
//  Created by VAIBHAV SRIVASTAVA on 24/01/25.
//

import Foundation

actor RateLimiter {
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

    func tryConsume(count: Int = 1) -> Bool {
        refill()
        let needed = Double(count)
        guard tokens >= needed else { return false }
        tokens -= needed
        return true
    }

    private func refill() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefillTime)
        let refillAmount = elapsed * refillRate
        tokens = min(Double(capacity), tokens + refillAmount)
        lastRefillTime = now
    }
}
