//
//  ViewController.swift
//  Blind
//
//  Created by boblemarin on 22/09/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Cocoa
import CoreMIDI


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
  var midiSmoothCC:UInt16 = 0
  var midiToggleCC:UInt16 = 0
  var midiFaderCC:UInt16 = 0
  var midiCurveCC:UInt16 = 0
  var midiDurationCC:UInt16 = 0
  var midiCancelCC:UInt16 = 0
  
  // Blind mode storage values
  var lastValues = [UInt16:(UInt8,UInt8,UInt8)]()
  var blindValues = [UInt16:(UInt8,UInt8,UInt8)]()
  var isBlindModeActive = false
  
//  var blinkTimer:Timer!
//  var blinkState = true
  var midi:SCMidiManager!
  var smooth:SCSmoothManager!
  let defaults = UserDefaults.standard
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // setup smooth controller
    smooth = SCSmoothManager.shared
    
    // setup clock mode combo box
    ibClockMode.removeAllItems()
    ibClockMode.addItems(withTitles: ["Internal","External"])
    if let cm =  defaults.string(forKey: "clockMode") {
      ibClockMode.selectItem(withTitle: cm)
      if cm == "Internal" {
        smooth.clockMode = .internalClock
      } else {
        smooth.clockMode = .externalClock
      }
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
    midiSmoothCC = getSavedValueFor("midiSmoothCC", defaultValue: makeId(177, 14))
    midiToggleCC = getSavedValueFor("midiToggleCC", defaultValue: makeId(177, 15))
    midiFaderCC = getSavedValueFor("midiFaderCC", defaultValue: makeId(176, 15))
    midiCurveCC = getSavedValueFor("midiCurveCC", defaultValue: makeId(176, 13))
    midiDurationCC = getSavedValueFor("midiDurationCC", defaultValue: makeId(176, 14))
    midiCancelCC = getSavedValueFor("midiCancelCC", defaultValue: makeId(177, 13))
    
    // configure table view
    ibMidiSourcesTableView.delegate = self
    ibMidiSourcesTableView.dataSource = self
    ibEyeImage.alphaValue = 0.5
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    let labels = ["","",
                  formatId(midiFaderCC),
                  formatId(midiToggleCC),
                  formatId(midiDurationCC),
                  formatId(midiCurveCC),
                  formatId(midiSmoothCC),
                  formatId(midiCancelCC)]
    
    for view in ibLearView.subviews {
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
      self.ibLearView.isHidden = !self.ibLearView.isHidden
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
      //sender.title = "..."
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
      defaults.set(clockMode, forKey: "clockMode")
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
  
  func clearBlindValues() {
    //print("clear stored blind values")
    self.blindValues.removeAll(keepingCapacity: true)
  }
  
  func startSmoothTransition() {
    //print("starting automatic parameters transition")
  }
  
//  @objc func blinkBlindValues() {
//    blinkState = !blinkState
//
//    for (_, value) in blindValues {
//      midi.sendBack((value.0, value.1, blinkState ? value.2 : 0))
//    }
//  }
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
      let intId = makeId(v1, v2)
      
      if (v1 & 0xF0) == 0xB0 { // this is a CC message}
        
        if isLearnModeActive {
          switch currentLearnTag {
            case 2: // Fader
              midiFaderCC = intId
              UserDefaults.standard.set(midiFaderCC, forKey: "midiFaderCC")
            
            case 3: // Toggle
              midiToggleCC = intId
              UserDefaults.standard.set(midiToggleCC, forKey: "midiToggleCC")
            
            case 4: // Duration
              midiDurationCC = intId
              UserDefaults.standard.set(midiDurationCC, forKey: "midiDurationCC")
            
            case 5: // Curve
              midiCurveCC = intId
              UserDefaults.standard.set(midiCurveCC, forKey: "midiCurveCC")
            
            case 6: // Smooth start
              midiSmoothCC = intId
              UserDefaults.standard.set(midiSmoothCC, forKey: "midiSmoothCC")
            
            case 7: // Cancel/Reset
              midiCancelCC = intId
              UserDefaults.standard.set(midiCancelCC, forKey: "midiCancelCC")
            
            default:
              return
          }
          DispatchQueue.main.async {
            self.ibLearnedButton?.title = self.formatId(intId)
            self.ibLearnedButton?.isBordered = false
          }
          isLearnModeActive = false
          currentLearnTag = 0
          return
        }

        switch intId {
          case midiToggleCC : // TOGGLE
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
              startSmoothTransition()
            }
          
          
          case midiCancelCC: //CANCEL
            if v3 > 0 {
              clearBlindValues()
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

