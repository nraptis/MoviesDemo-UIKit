//
//  ReachabilityMonitor.swift
//  BlockchainMoviesApp
//
//  Created by Nicky Taylor on 4/23/24.
//


import Foundation
import Network
import Combine

final class ReachabilityMonitor {
    
    static let shared = ReachabilityMonitor()
    
    @MainActor let reachabilityDidUpdatePublisher = PassthroughSubject<Void, Never>()
    
    
    private let queue = DispatchQueue(label: "com.reachability.monitor.operations")
    
    private init() {
        
    }
    
    private var monitor: NWPathMonitor?
    private var isListening = false
    
    func startListening() {
        if !isListening {
            isListening = true
            
            monitor = NWPathMonitor()
            if let monitor = monitor {
                monitor.pathUpdateHandler = { path in
                    Task { @MainActor in
                        self.reachabilityDidUpdatePublisher.send(())
                    }
                }
                monitor.start(queue: queue)
            }
        }
    }
    
    func stopListening() {
        if isListening {
            isListening = false
            monitor?.cancel()
            monitor = nil
        }
    }
    
    var isReachable: Bool {
        if let monitor = monitor {
            switch monitor.currentPath.status {
            case .satisfied:
                return true
            default:
                break
            }
        }
        return false
    }
    
}
