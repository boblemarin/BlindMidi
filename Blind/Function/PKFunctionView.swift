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
  var curve:CGFloat = 0
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
  }
  
  required init?(coder decoder: NSCoder) {
    super.init(coder: decoder)
  }
  
  func updateCurve(_ ratio:CGFloat) {
    curve = ratio
    DispatchQueue.main.async {
      self.needsDisplay = true
    }
  }
  
  override func draw(_ dirtyRect: NSRect) {
    let rect = NSInsetRect(self.bounds, 1, 1)
    let fsteps = rect.width
    let steps = Int(fsteps)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX, y: rect.minY))
    for i in 1...steps {
      let fi = CGFloat(i)
      //let val = curve < 0 ? ((1 - pow((fsteps-fi) / fsteps, 1 - curve))) : (pow((fi / fsteps), 1 + curve))
      let val = SCCurve.getValue(at: fi / fsteps, curve: curve)
      path.line(to: NSPoint(x: rect.minX + rect.width / fsteps * fi, y: rect.minY + rect.height * val))
    }
    path.lineWidth = 1
    NSColor.black.setStroke()
    path.stroke()
  }
}
