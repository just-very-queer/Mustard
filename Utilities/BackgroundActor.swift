// In Utilities/BackgroundActor.swift
import Foundation

@globalActor
public struct BackgroundActor {
    public actor ActorType { }
    public static let shared = ActorType()
}
