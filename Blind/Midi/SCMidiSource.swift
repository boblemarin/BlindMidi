//
//  SCMidiSource.swift
//  BlindMIDI
//
//  Created by boblemarin on 17/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation
import CoreMIDI

class SCMidiSource {
  var name:String = ""
  var uid:Int32 = 0
  var listening:Bool = false
  var destination:MIDIEndpointRef = 0
}

class SCMidiDestination {
  var name:String = ""
//  var uid:Int32 = 0
  var endPoint:MIDIEndpointRef = 0
}
