//
//  SCCurve.swift
//  BlindMIDI
//
//  Created by boblemarin on 17/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation

class SCCurve {
  static func getValue(at pos:Double, curve:Double) -> Double {
    return curve < 0 ? ((1 - pow(1 - pos, 1 - curve))) : (pow(pos, 1 + curve))
  }
}
