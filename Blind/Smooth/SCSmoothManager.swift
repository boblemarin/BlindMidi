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
        // TODO: implement timer management for internal clock mode
        if clockMode == .externalClock {
          self.midi.virtualMidiDelegate = self
        } else {
          self.midi.virtualMidiDelegate = nil
        }
      }
    }
  }
  var lastUpdate:Double = 0
  var clockTimer:Timer?
  var running = false
  var transitions = [SCTransition]()
  
  // MARK: Public
  
  func update() {
    
  }
  
}

extension SCSmoothManager: SCMidiDelegate {
  func handleMidi(_ midi: [UInt8]) {
    update()
  }
}
