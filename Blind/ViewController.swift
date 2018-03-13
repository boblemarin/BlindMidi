//
//  ViewController.swift
//  Blind
//
//  Created by boblemarin on 22/09/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//


/* ***************************************************************
 TODO:
 
 - make layout vertical
 - l'oeil se ferme en blind mode
 - visual feedback on runnign transitions (use nsprogressviews ?)
 
 
 *************************************************************** */

import Cocoa
import CoreMIDI


class ViewController: NSViewController {
  // Interface outlets
  @IBOutlet weak var ibEyeImage: NSImageView!
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  @IBOutlet weak var ibProgressFader: NSProgressIndicator!
  @IBOutlet weak var ibClockMode: NSPopUpButton!
  @IBOutlet weak var ibSmoothButton: NSButton!
  @IBOutlet weak var ibClearButton: NSButton!
  @IBOutlet weak var ibDurationField: NSTextField!
  @IBOutlet weak var ibLearnView:NSView!
  @IBOutlet weak var ibFnView: PKFunctionView!
  @IBOutlet weak var ibProgress1: NSProgressIndicator!
  @IBOutlet weak var ibProgress2: NSProgressIndicator!
  @IBOutlet weak var ibProgress3: NSProgressIndicator!
  @IBOutlet weak var ibProgress4: NSProgressIndicator!
  
  // Input list Icon
  let imgCheckOn = NSImage(named: NSImage.Name(rawValue: "checkbox_on"))
  let imgCheckOff = NSImage(named: NSImage.Name(rawValue: "checkbox_off"))
  
  // Midi Learn properties
  var isLearnModeActive = false
  var currentLearnTag:Int = 0
  var ibLearnedButton:NSButton?
  
  // Midi CC bindings
  var midiSmoothID:UInt16 = 0
  var midiToggleID:UInt16 = 0
  var midiFaderID:UInt16 = 0
  var midiCurveID:UInt16 = 0
  var midiDurationID:UInt16 = 0
  var midiCancelID:UInt16 = 0
  var midiToggle:(UInt8, UInt8) = (0, 0)
  var midiFader:(UInt8, UInt8) = (0, 0)
  
  // Blind mode storage values
  var lastValues = [UInt16:(UInt8,UInt8,UInt8)]()
  var blindValues = [UInt16:(UInt8,UInt8,UInt8)]()
  var isBlindModeActive = false
  var faderValue:UInt8 = 0
  var curveValue:Double = 0
  var durationValue:Double = 16
  
  //var blinkTimer:Timer!
//  var blinkState = true
  var midi:SCMidiManager!
  var smooth:SCSmoothManager!
//  let defaults = UserDefaults.standard
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // setup smooth controller
    smooth = SCSmoothManager.shared
    smooth.valueDelegate = self
    
    // setup clock mode combo box
    ibClockMode.removeAllItems()
    ibClockMode.addItems(withTitles: ["Internal","External"])
    if let cm =  UserDefaults.standard.string(forKey: "clockMode") {
      ibClockMode.selectItem(withTitle: cm)
      if cm == "Internal" {
        smooth.clockMode = .internalClock
      } else {
        smooth.clockMode = .externalClock
      }
    } else {
      ibClockMode.selectItem(withTitle: "Internal")
      smooth.clockMode = .internalClock
    }
    
    // setup midi
    let midiConfig = SCMidiManagerConfiguration(name: "BlindMIDI")
    midiConfig.midiSourcesDelegate = self
    midiConfig.midiDelegate = self
    midi = SCMidiManager.shared
    midi.setup(with: midiConfig)
    
    // blink timer setup
    //blinkTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.blinkBlindValues), userInfo: nil, repeats: true)
    
    // get saved values for CC`
    midiSmoothID = getSavedValueFor("midiSmoothCC", defaultValue: makeId(177, 14))
    midiToggleID = getSavedValueFor("midiToggleCC", defaultValue: makeId(177, 15))
    midiFaderID = getSavedValueFor("midiFaderCC", defaultValue: makeId(176, 15))
    midiCurveID = getSavedValueFor("midiCurveCC", defaultValue: makeId(176, 13))
    midiDurationID = getSavedValueFor("midiDurationCC", defaultValue: makeId(176, 14))
    midiCancelID = getSavedValueFor("midiCancelCC", defaultValue: makeId(177, 13))
    
    midiToggle = (UInt8(midiToggleID>>8),UInt8(midiToggleID&0xFF))
    midiFader = (UInt8(midiFaderID>>8),UInt8(midiFaderID&0xFF))
    
    // configure table view
    ibMidiSourcesTableView.delegate = self
    ibMidiSourcesTableView.dataSource = self
    ibEyeImage.alphaValue = 0.5
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    let labels = ["","",
                  formatId(midiFaderID),
                  formatId(midiToggleID),
                  formatId(midiDurationID),
                  formatId(midiCurveID),
                  formatId(midiSmoothID),
                  formatId(midiCancelID)]
    
    for view in ibLearnView.subviews {
      if let btn = view as? NSButton {
        btn.title = labels[view.tag]
      }
    }
  }
  
  
  override func viewWillDisappear() {
    //blinkTimer.invalidate()
    midi.terminate()
  }
  
  // MARK: IB Actions
  
  @IBAction func onToggleLearnView(_ sender: Any) {
    if let btn = ibLearnedButton {
      btn.isBordered = false
      ibLearnedButton = nil
    }

    DispatchQueue.main.async {
      self.ibLearnView.isHidden = !self.ibLearnView.isHidden
    }
  }
  
  @IBAction func onStartLearningCC(_ sender:NSButton) {
    let previous = ibLearnedButton
    ibLearnedButton = sender
    currentLearnTag = sender.tag
    isLearnModeActive = true
    DispatchQueue.main.async {
      previous?.isBordered = false
      sender.isBordered = true
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
      UserDefaults.standard.set(clockMode, forKey: "clockMode")
      DispatchQueue.main.async {
        self.ibDurationField.stringValue = self.smooth.durationLabelFor(duration: self.durationValue)
      }
    }
  }
  
  @IBAction func onSmoothButtonPushed(_ sender: Any) {
    startSmoothTransition()
  }
  
  @IBAction func onClearButtonPushed(_ sender: Any) {
    clearBlindValues()
  }
  
  // MARK: Helping functions
  
  func makeId(_ d1:UInt8, _ d2:UInt8) -> UInt16 {
    return UInt16(d1) << 8 + UInt16(d2)
  }
  
  func formatId(_ id:UInt16) -> String {
    return "\((id>>8)-175)/\(id & 0xFF)"
  }
  
  func mix(_ lastValues:(UInt8, UInt8, UInt8), with blindValues:(UInt8, UInt8, UInt8), q:UInt8) {
    let mixFactor = Float(q) / 127
    let mixValue = UInt8( Float(lastValues.2) * (1 - mixFactor) + Float(blindValues.2) * mixFactor)
    midi.send((blindValues.0, blindValues.1, mixValue), sendBack: true)
  }
  
  func getSavedValueFor(_ key:String, defaultValue:UInt16 = 0) -> UInt16 {
    let val = UserDefaults.standard.integer(forKey: key)
    if val > 0 {
      return UInt16(val)
    }
    return defaultValue
  }
  
  func updateLastValues(_ values:[(UInt8, UInt8, UInt8)]) {
    for value in values {
      let intID = makeId(value.0, value.1)
      lastValues[intID] = value
    }
  }
  
  func clearBlindValues() {
    // reset state
    blindValues.removeAll(keepingCapacity: true)
    isBlindModeActive = false
    faderValue = 0
    // show on controllers
    midi.sendBack((midiToggle.0, midiToggle.1, 0))
    midi.sendBack((midiFader.0, midiFader.1, 0))
    // show in interface
    DispatchQueue.main.async {
      self.ibEyeImage.alphaValue = 0.5
      self.ibProgressFader.doubleValue = 0
    }
  }
  
  func startSmoothTransition() {
    smooth.startTransitions(from: lastValues, to: blindValues, withCurve: curveValue, andDuration: durationValue)
    clearBlindValues()
  }
  
//  @objc func blinkBlindValues() {
//    blinkState = !blinkState
//
//    smooth.update()
//    print("blinking")
//    for (_, value) in blindValues {
//      midi.sendBack((value.0, value.1, blinkState ? value.2 : 0))
//    }
//  }
  
  //MARK: feedback function
  func updateProgressBars(for transitions:[SCTransition]) {
    let tc = transitions.count
    let p1 = tc > 0 ? transitions[0].position : 0
    let p2 = tc > 1 ? transitions[1].position : 0
    let p3 = tc > 2 ? transitions[2].position : 0
    let p4 = tc > 3 ? transitions[3].position : 0
    
    DispatchQueue.main.async {
      self.ibProgress1.doubleValue = p1
      self.ibProgress2.doubleValue = p2
      self.ibProgress3.doubleValue = p3
      self.ibProgress4.doubleValue = p4
    }
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
      let intID = makeId(v1, v2)
      
      if (v1 & 0xF0) == 0xB0 { // this is a CC message}
        
        if isLearnModeActive {
          switch currentLearnTag {
            case 2: // Fader
              midiFaderID = intID
              midiFader = (v1, v2)
              UserDefaults.standard.set(midiFaderID, forKey: "midiFaderCC")
            
            case 3: // Toggle
              midiToggleID = intID
              midiToggle = (v1, v2)
              UserDefaults.standard.set(midiToggleID, forKey: "midiToggleCC")
            
            case 4: // Duration
              midiDurationID = intID
              UserDefaults.standard.set(midiDurationID, forKey: "midiDurationCC")
            
            case 5: // Curve
              midiCurveID = intID
              UserDefaults.standard.set(midiCurveID, forKey: "midiCurveCC")
            
            case 6: // Smooth start
              midiSmoothID = intID
              UserDefaults.standard.set(midiSmoothID, forKey: "midiSmoothCC")
            
            case 7: // Cancel/Reset
              midiCancelID = intID
              UserDefaults.standard.set(midiCancelID, forKey: "midiCancelCC")
            
            default:
              return
          }
          DispatchQueue.main.async {
            self.ibLearnedButton?.title = self.formatId(intID)
            self.ibLearnedButton?.isBordered = false
          }
          isLearnModeActive = false
          currentLearnTag = 0
          return // comment for immediate action
        }

        switch intID {
          case midiToggleID : // TOGGLE
            let newState = v3 > 0
            if newState != isBlindModeActive {
              isBlindModeActive = newState
              DispatchQueue.main.async {
                self.ibEyeImage.alphaValue = newState ? 1 : 0.5
              }
              if isBlindModeActive {
                // entering blind mode
              } else {
                // exit blind mode
                for (id, _) in blindValues {
                  if let v = lastValues[id] {
                    self.midi.sendBack(v)
                  }
                }
                // -- removing this clearOnExit behavior for now --
//                for (id, value) in blindValues {
//                  self.midi.send(value, sendBack: true)
//                  lastValues[id] = value
//                }
//                blindValues.removeAll()
              }
            }

          case midiFaderID: // FADER
            faderValue = v3
            //if isBlindModeActive {
              for (id, value) in blindValues {
                let lastValue = lastValues[id] ?? value
                mix(lastValue, with: value, q: v3)
              }
            //}
            DispatchQueue.main.async {
              self.ibProgressFader.doubleValue = Double(v3) / 127
            }
          
          case midiCurveID: // CURVE
            curveValue = (Double(v3) / 127) * 16 - 8
            self.ibFnView.updateCurve( curveValue )
          
          
          case midiDurationID: // DURATION
            let duration = smooth.durationFor(value: v3)
            durationValue = duration.value
            DispatchQueue.main.async {
              self.ibDurationField.stringValue = duration.stringValue
            }
          
          case midiSmoothID: // SMOOTH
            if v3 > 0 {
              startSmoothTransition()
            }
            DispatchQueue.main.async {
//              self.ibSmoothButton.state = v3 > 0 ? .on : .off
              self.ibSmoothButton.title = v3 > 0 ? "-Smooth-" : "Smooth"
            }
          
          case midiCancelID: //CANCEL
            if v3 > 0 {
              clearBlindValues()
            }
            DispatchQueue.main.async {
//              self.ibClearButton.state = v3 > 0 ? .on : .off
              self.ibClearButton.title = v3 > 0 ? "-Clear-" : "Clear"
            }
          
          
          // Other actions
          default:
            let values = (v1, v2, v3)
            if isBlindModeActive {
              smooth.bypassProperty(withID: intID)
              blindValues[intID] = values
            } else {
              smooth.bypassProperty(withID: intID)
              lastValues[intID] = values
              self.midi.send(values)
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

