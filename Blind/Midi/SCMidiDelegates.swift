//
//  SCMidiDelegates.swift
//  BlindMIDI
//
//  Created by boblemarin on 17/11/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation

protocol SCMidiDelegate {
  func handleMidi(_ midi:[UInt8])
}

protocol SCMidiSourcesDelegate {
  func sourcesChanged(_ sources:[SCMidiSource])
}
