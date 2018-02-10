//
//  SCTransition.swift
//  BlindMIDI
//
//  Created by boblemarin on 20/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation

class SCTransition {
  var startTime:Double = 0
  var duration:Double = 0
  var position:Double = 0
  var properties = [SCTransitionProperty]()
  var curve:Double = 0
  
  func update(_ now:Double) -> [(UInt8, UInt8, UInt8)]? {
    guard position < 1 else {
      return nil
    }
    
    position = min(1, (now - startTime) / duration)
    
    var values = [(UInt8, UInt8, UInt8)]()
    let cp = SCCurve.getValue(at: position, curve: curve)
    
    //print("transition in progress : \(position) / \(cp)")
    for prop in properties where !prop.bypassed {
      let nv = UInt8(prop.startValue * (1 - cp) + prop.endValue * cp)
      if nv != prop.lastSentValue {
        prop.lastSentValue = nv
        values.append((prop.channel, prop.id, nv))
      }
    }
    
    return values
  }
  
  func updateTick() ->[(UInt8, UInt8, UInt8)]? {
    guard position < 1 else {
      return nil
    }
    startTime += 1
    
    position = startTime / duration
    
    var values = [(UInt8, UInt8, UInt8)]()
    let cp = SCCurve.getValue(at: position, curve: curve)
    
    //print("transition in progress : \(position) / \(cp)")
    for prop in properties where !prop.bypassed {
      let nv = UInt8(prop.startValue * (1 - cp) + prop.endValue * cp)
      if nv != prop.lastSentValue {
        prop.lastSentValue = nv
        values.append((prop.channel, prop.id, nv))
      }
    }
    
    return values
  }
  
  func bypassProperty(withID id:UInt16) {
    for prop in properties where prop.intID == id {
      prop.bypassed = true
    }
  }
}
