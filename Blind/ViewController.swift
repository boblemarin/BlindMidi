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

func MyVRMIDIReadProc(pktList: UnsafePointer<MIDIPacketList>,
                    readProcRefCon: UnsafeMutableRawPointer?, srcConnRefCon: UnsafeMutableRawPointer?) -> Void
{
  //midiListener?.onMidiReceived(pktList)
  print("ping")
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

class MidiSource {
  var name:String = ""
  var hash:Int = 0
  var listening:Bool = false
}

class ViewController: NSViewController {
 
  enum LearnMode {
    case Toggle
    case Fader
    case Auto
    case None
  }
  
  @IBOutlet weak var ibEyeImage: NSImageView!
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  
  @IBOutlet weak var ibBlindToggleField: NSTextField!
  @IBOutlet weak var ibToggleLearnButton: NSButton!
  
  @IBOutlet weak var ibBlindFaderField: NSTextField!
  @IBOutlet weak var ibFaderLearnButton: NSButton!
  
  @IBOutlet weak var ibBlindAutoField: NSTextField!
  @IBOutlet weak var ibAutoLearnButton: NSButton!
  
  @IBOutlet weak var ibProgressFader: NSProgressIndicator!
  
  let clientName = "BlindMIDI"
  var midiClient:MIDIClientRef = 0
  var midiOut:MIDIEndpointRef = 0
  var midiIn:MIDIPortRef = 0
  var vrMidiIn = MIDIEndpointRef()
  var midiSources:[MidiSource]!
  var connectedMidiSources = [Int]()
  var previousMidiSources:[Int]!
  
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
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // get saved values from CC
    let defaults = UserDefaults.standard
    blindModeToggleChannel = UInt8(defaults.integer(forKey: "blindModeToggleChannel"))
    blindModeToggleCC = UInt8(defaults.integer(forKey: "blindModeToggleCC"))
    blindModeFaderChannel = UInt8(defaults.integer(forKey: "blindModeFaderChannel"))
    blindModeFaderCC = UInt8(defaults.integer(forKey: "blindModeFaderCC"))
    blindModeAutoChannel = UInt8(defaults.integer(forKey: "blindModeAutoChannel"))
    blindModeAutoCC = UInt8(defaults.integer(forKey: "blindModeAutoCC"))
    
    // create virtual client, source and port
    midiListener = self
    MIDIClientCreate(clientName as CFString, MyMIDIStateChangedHander, nil, &midiClient)
    MIDISourceCreate(midiClient, clientName as CFString, &midiOut)
    MIDIInputPortCreate(midiClient, clientName as CFString, MyMIDIReadProc, nil, &midiIn)
    MIDIDestinationCreate(midiClient, clientName as CFString, MyVRMIDIReadProc, nil, &vrMidiIn)
    
    // get source names
    previousMidiSources = defaults.array(forKey: "previousMidiSources") as? [Int] ?? []
    midiSources = getSources()
    
    for (i, source) in midiSources.enumerated() {
      if previousMidiSources.contains(source.hash) {
        listenTo(i)
        connectedMidiSources.append(source.hash)
        midiSources[i].listening = true
      }
    }
    
    print("Connected sources : \(connectedMidiSources)")
    print("Previous sources : \(previousMidiSources)")
    
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
  
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    UserDefaults.standard.set(previousMidiSources, forKey: "previousMidiSources")
  }
  
  func refreshMidiInputList() {
    midiSources = getSources()
    for (i, source) in midiSources.enumerated() {
      if connectedMidiSources.contains(source.hash) {
        // already connected, mark as appropriate
        midiSources[i].listening = true
      } else if previousMidiSources.contains(source.hash) {
        // source has come back, connect and store
        connectedMidiSources.append(source.hash)
        midiSources[i].listening = true
        listenTo(i)
      }
    }
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
  
  @IBAction func onAutoLearnButtonPushed(_ sender: Any) {
    currentLearnMode = .Auto
    isLearnModeActive = true
    DispatchQueue.main.async {
      self.ibAutoLearnButton.title = "..."
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
            send(values)
          }
        }
      } else {
        // passthrough for non-CC messages
        let values = (v1, v2, v3)
        send(values)
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
    return midiSources.count
  }
}

extension ViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let columnID = tableColumn?.identifier else{
      return nil
    }
    
    let ucell = ibMidiSourcesTableView.makeView(withIdentifier: columnID, owner: nil)
    if let cell = ucell as? NSTableCellView {
      cell.textField?.stringValue = midiSources[row].name
      cell.imageView?.image = NSImage(named: NSImage.Name(rawValue: midiSources[row].listening ? "checkbox_on" : "checkbox_off"))
      //        cell.imageView?.image = NSImage(named: "checkbox_off")
      return cell
    }
    return nil
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    if let myTable = notification.object as? NSTableView {
      let selected = myTable.selectedRowIndexes.map { Int($0) }
      for i in selected {
        let listening = !midiSources[i].listening
        midiSources[i].listening = listening
        let hash = midiSources[i].hash
        if listening {
          listenTo(i)
          connectedMidiSources.append(hash)
          if !previousMidiSources.contains(hash) {
            previousMidiSources.append(hash)
          }
        } else {
          stopListeningTo(i)
          if let index = connectedMidiSources.index(of: hash) {
            connectedMidiSources.remove(at: index)
          }
          if let index = previousMidiSources.index(of: hash) {
            previousMidiSources.remove(at: index)
          }
        }
      }
      print("Connected sources : \(connectedMidiSources)")
      print("Previous sources : \(previousMidiSources)")
      ibMidiSourcesTableView.reloadData()
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
  
//  func getDestinationNames() -> [String]
//  {
//    var names:[String] = [];
//
//    let count: Int = MIDIGetNumberOfDestinations();
//    for i in 0..<count {
//      let endpoint:MIDIEndpointRef = MIDIGetDestination(i);
//
//      if (endpoint != 0)
//      {
//        names.append(getDisplayName(endpoint));
//      }
//    }
//    return names;
//  }
  
  func getSources() -> [MidiSource]
  {
    var sources = [MidiSource]()
    let count = MIDIGetNumberOfSources()
    for i in 0..<count {
      let endpoint = MIDIGetSource(i)
      if endpoint != 0 {
        let name = getDisplayName(endpoint)
        if name != clientName {
          let src = MidiSource()
          src.name = name
          src.hash = endpoint.hashValue
          sources.append(src)
        }
      }
    }
    return sources
  }
  

  
  func listenTo( _ i:Int ) {
    var src = MIDIGetSource(i)
    MIDIPortConnectSource(midiIn, src, &src)

  }
  
  func stopListeningTo( _ i:Int ) {
    let src = MIDIGetSource(i)
    MIDIPortDisconnectSource(midiIn, src)
  }
  
  

}
