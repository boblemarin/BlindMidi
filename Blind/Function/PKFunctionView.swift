//
//  PKFunctionView.swift
//  AutoSlider
//
//  Created by boblemarin on 24/10/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Foundation
import Cocoa

class PKFunctionView:NSView {
  var curve:Double = 0
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
  }
  
  required init?(coder decoder: NSCoder) {
    super.init(coder: decoder)
  }
  
  func updateCurve(_ ratio:Double) {
    curve = ratio
    DispatchQueue.main.async {
      self.needsDisplay = true
    }
  }
  
  override func draw(_ dirtyRect: NSRect) {
    let rect = NSInsetRect(self.bounds, 1, 1)
    let fsteps = rect.width
    let dsteps = Double(fsteps)
    let steps = Int(fsteps)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX, y: rect.minY))
    for i in 1...steps {
      let val = CGFloat(SCCurve.getValue(at: Double(i) / dsteps, curve: curve))
      path.line(to: NSPoint(x: rect.minX + rect.width / fsteps * CGFloat(i), y: rect.minY + rect.height * val))
    }
    path.lineWidth = 1
    NSColor.black.setStroke()
    path.stroke()
  }
}
