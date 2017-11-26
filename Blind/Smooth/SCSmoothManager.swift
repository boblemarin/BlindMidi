//
//  SCSmoothManager.swift
//  BlindMIDI
//
//  Created by boblemarin on 17/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation

enum SCClockMode {
  case internalClock
  case externalClock
}

class SCSmoothManager {
  // MARK: Singleton implementation
  private init() {
    
  }
  static let shared = SCSmoothManager()
  
  // MARK: properties
  let midi = SCMidiManager.shared
  var clockMode:SCClockMode = .internalClock {
    didSet {
      if clockMode != oldValue {
        print("changed clock mode to : \(clockMode)")
      }
    }
  }
  var lastUpdate:Double = 0
  var clockTimer:Timer?
  var running = false
  var transitions = [SCTransition]()
  
  // MARK: Public
  
}
