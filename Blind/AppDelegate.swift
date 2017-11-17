//
//  AppDelegate.swift
//  Blind
//
//  Created by boblemarin on 22/09/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    let appDefaults = [
      "blindModeToggleChannel": 177,
      "blindModeToggleCC": 15,
      "blindModeFaderChannel": 176,
      "blindModeFaderCC": 15
      ] as [String : Any]
    UserDefaults.standard.register(defaults: appDefaults)
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}

