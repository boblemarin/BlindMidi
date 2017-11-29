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
  // Interface outlets
  @IBOutlet weak var ibEyeImage: NSImageView!
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  @IBOutlet weak var ibProgressFader: NSProgressIndicator!
  @IBOutlet weak var ibClockMode: NSPopUpButton!
  @IBOutlet weak var ibDurationField: NSTextField!
  @IBOutlet weak var ibLearView:NSView!
  @IBOutlet weak var ibFnView: PKFunctionView!
  
  // Input list Icon
  let imgCheckOn = NSImage(named: NSImage.Name(rawValue: "checkbox_on"))
  let imgCheckOff = NSImage(named: NSImage.Name(rawValue: "checkbox_off"))
  
  // Midi Learn properties
  var isLearnModeActive = false
  var currentLearnTag:Int = 0
  var ibLearnedButton:NSButton?
  
  // Midi CC bindings
  var midiSmoothCC:UInt16 = 0 //(UInt8, UInt8) = (177, 14)
  var midiToggleCC:UInt16 = 0 //:(UInt8, UInt8) = (177, 15)
  var midiFaderCC:UInt16 = 0 //:(UInt8, UInt8) = (176, 15)
  var midiCurveCC:UInt16 = 0 //:(UInt8, UInt8) = (176, 13)
  var midiDurationCC:UInt16 = 0 //:(UInt8, UInt8) = (176, 14)
  var midiCancelCC:UInt16 = 0 // 177, 14
  
  // Blind mode storage values
  var lastValues = [UInt16:(UInt8,UInt8,UInt8)]()
  var blindValues = [UInt16:(UInt8,UInt8,UInt8)]()
  var isBlindModeActive = false
  var mode:SCMode = .passthrough
  var midi:SCMidiManager!
  var smooth:SCSmoothManager!
  
  override func viewDidLoad() {
    super.viewDidLoad()
     let defaults = UserDefaults.standard
    
    // setup clock mode combo box
    ibClockMode.removeAllItems()
    ibClockMode.addItems(withTitles: ["Internal","External"])
    
    
    // setup smooth controller
    smooth = SCSmoothManager.shared
    // smooth.clockMode = get previous clock mode from userdefaults
    
    // setup midi
    let midiConfig = SCMidiManagerConfiguration(name: "BlindMIDI")
    midiConfig.midiSourcesDelegate = self
    midiConfig.midiDelegate = self
    midi = SCMidiManager.shared
    midi.setup(with: midiConfig)
    
    // get saved values from CC

//    blindModeToggleChannel = UInt8(defaults.integer(forKey: "blindModeToggleChannel"))
//    blindModeToggleCC = UInt8(defaults.integer(forKey: "blindModeToggleCC"))
//    blindModeFaderChannel = UInt8(defaults.integer(forKey: "blindModeFaderChannel"))
//    blindModeFaderCC = UInt8(defaults.integer(forKey: "blindModeFaderCC"))
//    blindModeAutoChannel = UInt8(defaults.integer(forKey: "blindModeAutoChannel"))
//    blindModeAutoCC = UInt8(defaults.integer(forKey: "blindModeAutoCC"))
    midiSmoothCC = makeId(177, 14)
    midiToggleCC = makeId(177, 15)
    midiFaderCC = makeId(176, 15)
    midiCurveCC = makeId(176, 13)
    midiDurationCC = makeId(176, 14)
    midiCancelCC = makeId(177, 13)

    
    // configure table view
    ibMidiSourcesTableView.delegate = self
    ibMidiSourcesTableView.dataSource = self
    ibEyeImage.alphaValue = 0.5
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    
    //midi.sendBack((blindModeCurveChannel, blindModeCurveCC, 63))
    
    // show toggle and fader cc values
//    let toggleValue = blindModeToggleChannel > 174 ? "\(blindModeToggleChannel - 175)/\(self.blindModeToggleCC)" : ""
//    let faderValue = blindModeToggleChannel > 174 ? "\(blindModeFaderChannel - 175)/\(self.blindModeFaderCC)" : ""
//    let autoValue = blindModeAutoChannel > 174 ? "\(blindModeAutoChannel - 175)/\(self.blindModeAutoCC)" : ""
    // TODO: fix display of previous values
//    DispatchQueue.main.async {
//      self.ibBlindToggleField.stringValue = toggleValue
//      self.ibBlindFaderField.stringValue = faderValue
//      self.ibBlindAutoField.stringValue = autoValue
//    }
  }
  
  override func viewWillDisappear() {
    midi.terminate()
  }
  
  // MARK: Actions
  
  @IBAction func onToggleLearnView(_ sender: Any) {
    if let btn = ibLearnedButton {
      btn.isBordered = false
      ibLearnedButton = nil
    }

    DispatchQueue.main.async {
      self.ibLearView.isHidden = !self.ibLearView.isHidden
    }
  }
  
  @IBAction func onStartLearningCC(_ sender:NSButton) {
    let previous = ibLearnedButton
    ibLearnedButton = sender
    currentLearnTag = sender.tag
    DispatchQueue.main.async {
      previous?.isBordered = false
      sender.isBordered = true
      sender.title = "..."
    }
  }
  

  @IBAction func onSelectClockMode(_ sender: Any) {
    if let clockMode = ibClockMode.selectedItem?.title {
      switch clockMode {
        case "Internal":
          smooth.clockMode = .internalClock
        case "External":
          smooth.clockMode = .externalClock
        default:
          break
      }
    }
    
  }
  
  // MARK: Helping functions
  
  func makeId(_ d1:UInt8, _ d2:UInt8) -> UInt16 {
    return UInt16(d1) << 8 + UInt16(d2)
  }
  
  func mix(_ lastValues:(UInt8, UInt8, UInt8), with blindValues:(UInt8, UInt8, UInt8), q:UInt8) {
    let mixFactor = Float(q) / 127
    let mixValue = UInt8( Float(lastValues.2) * (1 - mixFactor) + Float(blindValues.2) * mixFactor)
    midi.send((blindValues.0, blindValues.1, mixValue), sendBack: true)  //TODO: refactor
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
//      let vm = (midi[i] << 8) | midi[i+1]
      let v1 = midi[i]
      let v2 = midi[i+1]
      let v3 = midi[i+2]
      let intId = makeId(v1, v2)
      
      if (v1 & 0xF0) == 0xB0 { // this is a CC message}
        
        if isLearnModeActive {
          switch currentLearnTag {
            
          }
/* TODO: refactor
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
         */
        }

        switch intId {
          
        // Blind mode Toggle CC
        case midiToggleCC :
          let newState = v3 > 0
          if newState != isBlindModeActive {
            isBlindModeActive = newState
            DispatchQueue.main.async {
              self.ibEyeImage.alphaValue = self.isBlindModeActive ? 1 : 0.5
            }
            if isBlindModeActive {
              
            } else {
              for (id, value) in blindValues {
                self.midi.send(value, sendBack: true)
                lastValues[id] = value
              }
              blindValues.removeAll()
            }
          }

        case midiFaderCC: // FADER
          if isBlindModeActive {
            for (id, value) in blindValues {
              let lastValue = lastValues[id] ?? value
              mix(lastValue, with: value, q: v3)
            }
          }
          DispatchQueue.main.async {
            self.ibProgressFader.doubleValue = Double(v3) / 127
          }
        
        case midiCurveCC: // CURVE
          let val = (CGFloat(v3) / 127) * 16 - 8
          self.ibFnView.updateCurve( val )
          
          
        case midiDurationCC: // DURATION
          DispatchQueue.main.async {
            self.ibDurationField.stringValue = "-\(v3)-"
          }
          
          
        case midiSmoothCC: // SMOOTH
          if v3 > 0 {
            // TODO: start timer and move parameters
            print("starting automatic parameters transition")
          }
          
          
        case midiCancelCC: //CANCEL
          if v3 > 0 {
            print("canceling")
            self.blindValues.removeAll(keepingCapacity: true)
          }
          
        // Other actions
        default:
          let values = (v1, v2, v3)
          if isBlindModeActive {
            blindValues[intId] = values
          } else {
            lastValues[intId] = values
            self.midi.send(values)
            // TODO: check for stored duplicates and remove them
          }
        }
      } else {
        // passthrough for non-CC messages
        let values = (v1, v2, v3)
        self.midi.send(values)
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

