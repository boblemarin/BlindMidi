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
  var clockTimer:DispatchSourceTimer?
  var running = false
  var transitions = [SCTransition]()
  
  // MARK: Private
  
  private func startUpdateTimer() {
    guard clockTimer == nil else {
      //print("Update timer already running")
      return
    }
    let queue = DispatchQueue(label:"be.minimal.blind.smoothtimer")
    let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
    timer.setEventHandler {
      self.update()
    }
    timer.schedule(deadline: .now(), repeating: 0.02)
    timer.resume()
    clockTimer = timer
    //print("starting timer")
  }

  private func clearUpdateTimer() {
    guard let clockTimer = clockTimer else {
      print("No update timer running")
      return
    }
    clockTimer.cancel()
    self.clockTimer = nil
  }

  
  // MARK: Public
  
  func startTransitions(from startValues:[UInt16:(UInt8,UInt8,UInt8)], to endValues:[UInt16:(UInt8,UInt8,UInt8)], withCurve curve:Double, andDuration duration:Double) {
    guard endValues.count > 0 else {
      //print("nothing to transition about")
      return
    }
    
    let transition = SCTransition()
    for (id, endValue) in endValues {
      bypassProperty(withID: id)
      let startValue = startValues[id]?.2 ?? 0
      transition.properties.append(SCTransitionProperty(channel: endValue.0, id: endValue.1, from: startValue, to: endValue.2, withID: id))
    }
    transition.curve = curve
    transition.duration = duration
    transition.startTime = Date.timeIntervalSinceReferenceDate
    
    transitions.append(transition)
    
    //print("Starting timer for transitions count : \(transition.properties.count)")
    
    startUpdateTimer()
  }
  
  func update() {
    let tc = transitions.count
    guard tc > 0 else {
      clearUpdateTimer()
      return
    }
    
    let now = Date.timeIntervalSinceReferenceDate
    var hasCompletedTransitions = false
    for transition in transitions {
      if let values = transition.update(now) {
        for value in values {
          midi.send(value, sendBack: true)
        }
      } else {
        hasCompletedTransitions = true
      }
    }
    
    if hasCompletedTransitions {
      transitions = transitions.filter { $0.position < 1 }
    }
  }
  
  func bypassProperty(withID id:UInt16) {
    for transition in transitions {
      transition.bypassProperty(withID: id)
    }
  }
  
  func durationFor(value:UInt8) -> SCSmoothDuration {
    let duration = SCSmoothDuration()
    switch clockMode {
    case .internalClock:
      duration.value = Double(value)
      duration.stringValue = "\(duration.value)s"
    case .externalClock:
      duration.value = Double(value)
      duration.stringValue = "bar"
    }
    return duration
  }
}

extension SCSmoothManager: SCMidiDelegate {
  func handleMidi(_ midi: [UInt8]) {
    update()
  }
}
