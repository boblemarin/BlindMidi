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
  var curve:CGFloat = 0
  
  func update(_ now:Double) -> Bool {
    position = (now - startTime) / duration
    return false
  }
}
