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

  }

  func applicationWillTerminate(_ aNotification: Notification) {
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}

