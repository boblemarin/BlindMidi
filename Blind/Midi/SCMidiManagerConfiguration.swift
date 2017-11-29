//
//  SCMidiManagerConfiguration.swift
//  BlindMIDI
//
//  Created by boblemarin on 17/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation

class SCMidiManagerConfiguration {
  var clientName:CFString!
  var enableMidiInput = true
  var enableVirtualSource = true
  var enableVirtualDestination = true
  var midiDelegate:SCMidiDelegate?
  var midiSourcesDelegate:SCMidiSourcesDelegate?
  
  convenience init(name:String = "BlindMidi") {
    self.init()
    clientName = name as CFString
  }
}
