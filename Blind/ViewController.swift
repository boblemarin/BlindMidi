//
//  ViewController.swift
//  Blind
//
//  Created by boblemarin on 22/09/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Cocoa
import CoreMIDI

enum SCMode {
  case passthrough
  case capture
  case learn
}

class ViewController: NSViewController {
 
  // should move to SCSmoothManager
  enum LearnMode {
    case Toggle
    case Fader
    case Auto
    case None
  }
  // ---
  
  @IBOutlet weak var ibEyeImage: NSImageView!
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  
  @IBOutlet weak var ibBlindToggleField: NSTextField!
  @IBOutlet weak var ibToggleLearnButton: NSButton!
  
  @IBOutlet weak var ibBlindFaderField: NSTextField!
  @IBOutlet weak var ibFaderLearnButton: NSButton!
  
  @IBOutlet weak var ibBlindAutoField: NSTextField!
  @IBOutlet weak var ibAutoLearnButton: NSButton!
  
  @IBOutlet weak var ibProgressFader: NSProgressIndicator!
  
  
  let imgCheckOn = NSImage(named: NSImage.Name(rawValue: "checkbox_on"))
  let imgCheckOff = NSImage(named: NSImage.Name(rawValue: "checkbox_off"))
  
  // should move to SCSmoothManager
  var isLearnModeActive = false
  var currentLearnMode:LearnMode = .None
  var isBlindModeActive = false
  var blindModeToggleChannel:UInt8 = 177
  var blindModeToggleCC:UInt8 = 15
  var blindModeFaderChannel:UInt8 = 176
  var blindModeFaderCC:UInt8 = 15
  var blindModeAutoChannel:UInt8 = 176
  var blindModeAutoCC:UInt8 = 16
  var lastValues = [String:(UInt8,UInt8,UInt8)]()
  var blindValues = [String:(UInt8,UInt8,UInt8)]()
  // ---
  
  var midi:SCMidiManager!
  var mode:SCMode = .passthrough
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // setup midi
    let midiConfig = SCMidiManagerConfiguration(name: "BlindMIDI")
    midiConfig.midiSourcesDelegate = self
    midiConfig.midiDelegate = self
    midi = SCMidiManager.shared
    midi.setup(with: midiConfig)
    
    // get saved values from CC -- should move to smoothcontroller ?
    let defaults = UserDefaults.standard
    blindModeToggleChannel = UInt8(defaults.integer(forKey: "blindModeToggleChannel"))
    blindModeToggleCC = UInt8(defaults.integer(forKey: "blindModeToggleCC"))
    blindModeFaderChannel = UInt8(defaults.integer(forKey: "blindModeFaderChannel"))
    blindModeFaderCC = UInt8(defaults.integer(forKey: "blindModeFaderCC"))
    blindModeAutoChannel = UInt8(defaults.integer(forKey: "blindModeAutoChannel"))
    blindModeAutoCC = UInt8(defaults.integer(forKey: "blindModeAutoCC"))
    
    // configure table view
    ibMidiSourcesTableView.delegate = self
    ibMidiSourcesTableView.dataSource = self
    ibEyeImage.alphaValue = 0.5
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    // show toggle and fader cc values
    let toggleValue = blindModeToggleChannel > 174 ? "\(blindModeToggleChannel - 175)/\(self.blindModeToggleCC)" : ""
    let faderValue = blindModeToggleChannel > 174 ? "\(blindModeFaderChannel - 175)/\(self.blindModeFaderCC)" : ""
    let autoValue = blindModeAutoChannel > 174 ? "\(blindModeAutoChannel - 175)/\(self.blindModeAutoCC)" : ""
    DispatchQueue.main.async {
      self.ibBlindToggleField.stringValue = toggleValue
      self.ibBlindFaderField.stringValue = faderValue
      self.ibBlindAutoField.stringValue = autoValue
    }
  }
  
  // MARK: Actions
  
  @IBAction func onToggleLearnButtonPushed(_ sender: Any) {
    currentLearnMode = .Toggle
    isLearnModeActive = true
    DispatchQueue.main.async {
      self.ibToggleLearnButton.title = "..."
    }
  }
  
  @IBAction func onFaderLearnButtonPushed(_ sender: Any) {
    currentLearnMode = .Fader
    isLearnModeActive = true
    DispatchQueue.main.async {
      self.ibFaderLearnButton.title = "..."
    }
  }
  
  @IBAction func onAutoLearnButtonPushed(_ sender: Any) {
    currentLearnMode = .Auto
    isLearnModeActive = true
    DispatchQueue.main.async {
      self.ibAutoLearnButton.title = "..."
    }
  }

  func mix(_ lastValues:(UInt8, UInt8, UInt8), with blindValues:(UInt8, UInt8, UInt8), q:UInt8) {
    let mixFactor = Float(q) / 127
    let mixValue = UInt8( Float(lastValues.2) * (1 - mixFactor) + Float(blindValues.2) * mixFactor)
    midi.send((lastValues.0, lastValues.1, mixValue))  //TODO: refactor
  }
}

//MARK: SCMidi delegates
extension ViewController: SCMidiSourcesDelegate {
  
  func sourcesChanged(_ sources: [SCMidiSource]) {
    self.ibMidiSourcesTableView.reloadData()
  }
  
}

extension ViewController: SCMidiDelegate {
  
  func handleMidi(_ midi:[UInt8]) {
    var i = 0
    // cycle through multiple messages
    while i < midi.count - 2 {
      // store command values
      let v1 = midi[i]
      let v2 = midi[i+1]
      let v3 = midi[i+2]
      
      if (v1 & 0xF0) == 0xB0 { // this is a CC message}
        
        if isLearnModeActive {
          
          switch currentLearnMode {
          case .Fader:
            // get values
            blindModeFaderChannel = v1
            blindModeFaderCC = v2
            // save in user defaults
            let defaults = UserDefaults.standard
            defaults.set(blindModeFaderChannel, forKey: "blindModeFaderChannel")
            defaults.set(blindModeFaderCC, forKey: "blindModeFaderCC")
            // show in interface
            DispatchQueue.main.async {
              self.ibBlindFaderField.stringValue = "\(v1 - 175)/\(v2)"
              self.ibFaderLearnButton.title = "Learn"
            }
          case .Toggle:
            // get values
            blindModeToggleChannel = v1
            blindModeToggleCC = v2
            // save in user defaults
            let defaults = UserDefaults.standard
            defaults.set(blindModeToggleChannel, forKey: "blindModeToggleChannel")
            defaults.set(blindModeToggleCC, forKey: "blindModeToggleCC")
            // show in interface
            DispatchQueue.main.async {
              self.ibBlindToggleField.stringValue = "\(v1 - 175)/\(v2)"
              self.ibToggleLearnButton.title = "Learn"
            }
          case .Auto:
            // get values
            blindModeAutoChannel = v1
            blindModeAutoCC = v2
            // save in user defaults
            let defaults = UserDefaults.standard
            defaults.set(blindModeAutoChannel, forKey: "blindModeAutoChannel")
            defaults.set(blindModeAutoCC, forKey: "blindModeAutoCC")
            // show in interface
            DispatchQueue.main.async {
              self.ibBlindAutoField.stringValue = "\(v1 - 175)/\(v2)"
              self.ibAutoLearnButton.title = "Learn"
            }
          case .None:
            break
          }
          // finish learning session
          isLearnModeActive = false
          currentLearnMode = .None
          return
        }
        
        switch (v1, v2) {
          
        // Blind mode Toggle CC
        case (blindModeToggleChannel, blindModeToggleCC) :
          isBlindModeActive = v3 > 0
          DispatchQueue.main.async {
            self.ibEyeImage.alphaValue = self.isBlindModeActive ? 1 : 0.5
          }
          if !isBlindModeActive {
            for (id, value) in blindValues {
              self.midi.send(value)
              lastValues[id] = value
            }
            blindValues.removeAll()
          }
          
        // Blind mode Fader CC
        case (blindModeFaderChannel, blindModeFaderCC):
          if isBlindModeActive {
            for (id, value) in blindValues {
              if let lastValue = lastValues[id] {
                mix(lastValue, with: value, q: v3)
              }
            }
          }
          DispatchQueue.main.async {
            self.ibProgressFader.doubleValue = Double(v3) / 127
          }
          
        case (blindModeAutoChannel, blindModeAutoCC):
          // TODO: start timer and move parameters
          print("starting automatic parameters transition")
          
        // Other actions
        default:
          let values = (v1, v2, v3)
          if isBlindModeActive {
            blindValues["\(v1)-\(v2)"] = values
          } else {
            lastValues["\(v1)-\(v2)"] = values
            self.midi.send(values)
          }
        }
      } else {
        // passthrough for non-CC messages
        let values = (v1, v2, v3)
        self.midi.send(values)
        // TODO: check for stored duplicates and remove them
      }
      i += 3
    }
  }
}

//MARK: NSTableView delegates

extension ViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return midi.midiSources.count
  }
}

extension ViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let columnID = tableColumn?.identifier else{
      return nil
    }
    
    let ucell = ibMidiSourcesTableView.makeView(withIdentifier: columnID, owner: nil)
    if let cell = ucell as? NSTableCellView {
      let src = midi.midiSources[row]
      cell.textField?.stringValue = src.name
      cell.imageView?.image = src.listening ? imgCheckOn : imgCheckOff
      return cell
    }
    return nil
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    if let myTable = notification.object as? NSTableView {
      let selected = myTable.selectedRowIndexes.map { Int($0) }
      for i in selected {
        midi.toggleInput(i)
      }
      ibMidiSourcesTableView.reloadData()
    }
  }
}

