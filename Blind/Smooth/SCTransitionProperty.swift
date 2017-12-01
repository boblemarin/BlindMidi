//
//  SCTransitionProperty.swift
//  BlindMIDI
//
//  Created by boblemarin on 20/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation

class SCTransitionProperty {
  var intID:UInt16 = 0
  var channel:UInt8 = 0
  var id:UInt8 = 0
  var lastSentValue:UInt8 = 0
  var startValue:Double = 0
  var endValue:Double = 0
  var bypassed:Bool = false
  
  init(channel:UInt8, id:UInt8, from:UInt8, to:UInt8, withID intID:UInt16) {
    self.channel = channel
    self.id = id
    self.lastSentValue = from
    self.startValue = Double(from)
    self.endValue = Double(to)
    self.intID = intID
  }
}
