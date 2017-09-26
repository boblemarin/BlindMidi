//
//  ViewController.swift
//  Blind
//
//  Created by boblemarin on 22/09/2017.
//  Copyright © 2017 minimal.be. All rights reserved.
//

import Cocoa
import CoreMIDI

var midiListener:ViewController?

func MyMIDIReadProc(pktList: UnsafePointer<MIDIPacketList>,
                    readProcRefCon: UnsafeMutableRawPointer?, srcConnRefCon: UnsafeMutableRawPointer?) -> Void
{
  midiListener?.onMidiReceived(pktList)
}

func MyMIDIStateChangedHander(notification:UnsafePointer<MIDINotification>, rawPointer:UnsafeMutableRawPointer?) -> Void {
  if notification.pointee.messageID == .msgSetupChanged {
    midiListener?.refreshMidiInputList()
  }
  /*
   // keep complete version for future needs
  switch notification.pointee.messageID {
  case .msgObjectAdded:
    print("object added")
//    midiListener?.refreshMidiInputList()
  case .msgObjectRemoved:
    print("object removed")
//    midiListener?.refreshMidiInputList()
    case .msgPropertyChanged:
      print("property changed")
    case .msgSetupChanged:
      print("setup changed")
      midiListener?.refreshMidiInputList()
    case .msgIOError:
      print("io error")
    case .msgThruConnectionsChanged:
      print("thru connections changed")
    case .msgSerialPortOwnerChanged:
      print("Serial port owner changed")
  }
  */
}

class ViewController: NSViewController {
 
  enum LearnMode {
    case Toggle
    case Fader
    case None
  }
  
  @IBOutlet weak var ibEyeImage: NSImageView!
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  @IBOutlet weak var ibBlindToggleField: NSTextField!
  @IBOutlet weak var ibToggleLearnButton: NSButton!
  @IBOutlet weak var ibBlindFaderField: NSTextField!
  @IBOutlet weak var ibFaderLearnButton: NSButton!
  @IBOutlet weak var ibProgressFader: NSProgressIndicator!
  
  let clientName = "BlindMIDI"
  var midiSourceNames = [String]()
  var midiClient:MIDIClientRef = 0
  var midiOut:MIDIEndpointRef = 0
  var midiIn:MIDIPortRef = 0
  
  var isLearnModeActive = false
  var currentLearnMode:LearnMode = .None
  var isBlindModeActive = false
  var blindModeToggleChannel:UInt8 = 177
  var blindModeToggleCC:UInt8 = 15
  var blindModeFaderChannel:UInt8 = 176
  var blindModeFaderCC:UInt8 = 15
  var lastValues = [String:(UInt8,UInt8,UInt8)]()
  var blindValues = [String:(UInt8,UInt8,UInt8)]()
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // get saved values from CC
    let defaults = UserDefaults.standard
    blindModeToggleChannel = UInt8(defaults.integer(forKey: "blindModeToggleChannel"))
    blindModeToggleCC = UInt8(defaults.integer(forKey: "blindModeToggleCC"))
    blindModeFaderChannel = UInt8(defaults.integer(forKey: "blindModeFaderChannel"))
    blindModeFaderCC = UInt8(defaults.integer(forKey: "blindModeFaderCC"))
    
    ibEyeImage.alphaValue = 0.5
    
    // create virtual client, source and port
    midiListener = self
    MIDIClientCreate(clientName as CFString, MyMIDIStateChangedHander, nil, &midiClient)
    MIDISourceCreate(midiClient, clientName as CFString, &midiOut)
    MIDIInputPortCreate(midiClient, clientName as CFString, MyMIDIReadProc, nil, &midiIn)
    
    // get source names
    midiSourceNames = getSourceNames()
    
    // configure table view
    ibMidiSourcesTableView.delegate = self
    ibMidiSourcesTableView.dataSource = self
  }
  
  override func viewWillAppear() {
    
    // show toggle and fader cc values
    DispatchQueue.main.async {
      self.ibBlindToggleField.stringValue = "\(self.blindModeToggleChannel - 175)/\(self.blindModeToggleCC)"
      self.ibBlindFaderField.stringValue = "\(self.blindModeFaderChannel - 175)/\(self.blindModeFaderCC)"
    }
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }
  
  func refreshMidiInputList() {
    midiSourceNames = getSourceNames()
    ibMidiSourcesTableView.reloadData()
  }

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
  
  func onMidiReceived(_ pktList:UnsafePointer<MIDIPacketList>) {
      let packetList:MIDIPacketList = pktList.pointee
      var packet:MIDIPacket = packetList.packet
      for _ in 1...packetList.numPackets
      {
        let bytes = Mirror(reflecting: packet.data).children
        var midi = [UInt8]()

        var i = packet.length
        for (_, attr) in bytes.enumerated()
        {
          midi.append(attr.value as! UInt8)
          i -= 1
          if i <= 0 { break }
        }

        handleMidi(midi)
        packet = MIDIPacketNext(&packet).pointee
      }
  }
  
  func handleMidi(_ midi:[UInt8]) {
    var i = 0
    // cycle through multiple messages
    while i < midi.count - 2 {
      // store command values
      let v1 = midi[i]
      let v2 = midi[i+1]
      let v3 = midi[i+2]
      
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
              send(value)
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
        
        // Other actions
        default:
          let values = (v1, v2, v3)
          if isBlindModeActive {
            blindValues["\(v1)-\(v2)"] = values
          } else {
            lastValues["\(v1)-\(v2)"] = values
            send(values)
          }
      }
      
      i += 3
    }
  }
  
  func mix(_ lastValues:(UInt8, UInt8, UInt8), with blindValues:(UInt8, UInt8, UInt8), q:UInt8) {
    let mixFactor = Float(q) / 127
    let mixValue = UInt8( Float(lastValues.2) * (1 - mixFactor) + Float(blindValues.2) * mixFactor)
    send((lastValues.0, lastValues.1, mixValue))
  }
  
  func send(_ values:(UInt8, UInt8, UInt8)) {
    var packet = MIDIPacket()
    packet.timeStamp = 0
    packet.length = 3
    packet.data.0 = values.0
    packet.data.1 = values.1
    packet.data.2 = values.2
    
    var midiPacketList = MIDIPacketList(numPackets: 1, packet: packet)
    MIDIReceived(midiOut, &midiPacketList)
  }
  
}


extension ViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return midiSourceNames.count
  }
}

extension ViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {


    let CellID = NSUserInterfaceItemIdentifier(rawValue: "NameCellID")
    
    if let cell = ibMidiSourcesTableView.makeView(withIdentifier: CellID, owner: nil) as? NSTableCellView {
      cell.textField?.stringValue = midiSourceNames[row]
      return cell
    }
    return nil
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    // TODO: use selection to really listen to midi sources
    for i in ibMidiSourcesTableView.selectedRowIndexes {
      print("Should listen to \(midiSourceNames[i])")
    }
  }
}

extension ViewController {
  func getDisplayName(_ obj: MIDIObjectRef) -> String
  {
    var param: Unmanaged<CFString>?
    var name: String = "Error"
    
    let err: OSStatus = MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &param)
    if err == OSStatus(noErr)
    {
      name =  param!.takeRetainedValue() as String
    }
    
    return name
  }
  
  func getDestinationNames() -> [String]
  {
    var names:[String] = [];
    
    let count: Int = MIDIGetNumberOfDestinations();
    for i in 0..<count {
      let endpoint:MIDIEndpointRef = MIDIGetDestination(i);
      
      if (endpoint != 0)
      {
        names.append(getDisplayName(endpoint));
      }
    }
    return names;
  }
  
  func getSourceNames() -> [String]
  {
    var names:[String] = [];
    
    let count: Int = MIDIGetNumberOfSources();
    for i in 0..<count {
      let endpoint:MIDIEndpointRef = MIDIGetSource(i);
      if (endpoint != 0)
      {
        let name = getDisplayName(endpoint)
        print("INPUT : \(name)")
        if name != clientName {
          names.append(name);
        }
        if name == "Midi Fighter Twister" {
          listenTo(i)
        }
      }
    }
    return names;
  }
  
  func listenTo( _ i:Int ) {
    var src = MIDIGetSource(i)
    MIDIPortConnectSource(midiIn, src, &src)
  }

}
