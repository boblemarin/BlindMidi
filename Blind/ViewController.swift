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
//  let packetList:MIDIPacketList = pktList.pointee
//  let srcRef:MIDIEndpointRef = srcConnRefCon!.load(as: MIDIEndpointRef.self)
//
//  print("MIDI Received From Source: \(getDisplayName(srcRef))")
//
//  var packet:MIDIPacket = packetList.packet
//  for _ in 1...packetList.numPackets
//  {
//    let bytes = Mirror(reflecting: packet.data).children
//    var dumpStr = ""
//
//    // bytes mirror contains all the zero values in the ridiulous packet data tuple
//    // so use the packet length to iterate.
//    var i = packet.length
//    for (_, attr) in bytes.enumerated()
//    {
//      dumpStr += String(format:"$%02X ", attr.value as! UInt8)
//      i -= 1
//      if (i <= 0)
//      {
//        break
//      }
//    }
//
//    print(dumpStr)
//    packet = MIDIPacketNext(&packet).pointee
//  }
  midiListener?.onMidiReceived(pktList)
}

class ViewController: NSViewController {
  
//  static var z: UInt8 = 0
//  var midiDataTuple = (z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z)

  
  
  @IBOutlet weak var ibBlindBox: NSButton!
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  
  let clientName = "BlindMidi"
  var midiSourceNames = [String]()
  var midiClient:MIDIClientRef = 0
  var midiOut:MIDIEndpointRef = 0
  var midiIn:MIDIPortRef = 0
  
  var isBlindModeActive = false
  var blindModeToggleChannel:UInt8 = 177
  var blindModeToggleCC:UInt8 = 15
  var blindModeFaderChannel:UInt8 = 176
  var blindModeFaderCC:UInt8 = 15
  var lastValues = [String:(UInt8,UInt8,UInt8)]()
  var blindValues = [String:(UInt8,UInt8,UInt8)]()
  
  override func viewDidLoad() {
    super.viewDidLoad()

    // create virtual source
    midiListener = self
    MIDIClientCreate(clientName as CFString, nil, nil, &midiClient)
    MIDISourceCreate(midiClient, clientName as CFString, &midiOut)
    MIDIInputPortCreate(midiClient, clientName as CFString, MyMIDIReadProc, nil, &midiIn)
    
    // get source names
    midiSourceNames = getSourceNames()
    
    // configure table view
    ibMidiSourcesTableView.delegate = self
    ibMidiSourcesTableView.dataSource = self
    // Do any additional setup after loading the view.
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }
  
  func refreshMidiInputList() {
    ibMidiSourcesTableView.reloadData()
  }
  
  @IBAction func onPingButtonPushed(_ sender: Any) {
    var packet = MIDIPacket()
    packet.timeStamp = 0
    packet.length = 3
//    packet.data = midiDataTuple
    
    packet.data.0 = 0x90
    packet.data.1 = 48
    packet.data.2 = 98
    
    var midiPacketList = MIDIPacketList(numPackets: 1, packet: packet)
    MIDIReceived(midiOut, &midiPacketList)
  }
  
  func onMidiReceived(_ pktList:UnsafePointer<MIDIPacketList>) {
//    if isBlindModeActive {
//
//    } else {
//
//    }
//     MIDIReceived(midiOut, pktList)
    
      let packetList:MIDIPacketList = pktList.pointee
      var packet:MIDIPacket = packetList.packet
      for _ in 1...packetList.numPackets
      {
        let bytes = Mirror(reflecting: packet.data).children
        var midi = [UInt8]()

        // bytes mirror contains all the zero values in the ridiulous packet data tuple
        // so use the packet length to iterate.
        var i = packet.length
        for (_, attr) in bytes.enumerated()
        {
          midi.append(attr.value as! UInt8)
//          dumpStr += "\() "
          i -= 1
          if (i <= 0)
          {
            break
          }
        }

        handleMidi(midi)
        packet = MIDIPacketNext(&packet).pointee
      }
  }
  
  func handleMidi(_ midi:[UInt8]) {
    var i = 0
    while i < midi.count - 2 {
//      var command = midi[i]
      let v1 = midi[i]
      let v2 = midi[i+1]
      let v3 = midi[i+2]
      switch (v1, v2) {
        case (blindModeToggleChannel, blindModeToggleCC) :
          isBlindModeActive = v3 > 0
          DispatchQueue.main.async {
            self.ibBlindBox.state = self.isBlindModeActive ? NSButton.StateValue.on : NSButton.StateValue.off
          }
          if !isBlindModeActive {
            for (id, value) in blindValues {
              send(value)
              lastValues[id] = value
            }
            blindValues.removeAll()
          }
        case (blindModeFaderChannel, blindModeFaderCC):
          if isBlindModeActive {
            for (id, value) in blindValues {
              if let lastValue = lastValues[id] {
                mix(lastValue, with: value, q: v3)
              }
            }
          }
        
        default:
          let values = (v1, v2, v3)
          if isBlindModeActive {
            blindValues["\(v1)-\(v2)"] = values
//            print("MIDI IN : \(values)")
          } else {
            lastValues["\(v1)-\(v2)"] = values
            send(values)
          }
      }
      
      i += 3
    }
  }
  
  func mix(_ lastValues:(UInt8, UInt8, UInt8), with blindValues:(UInt8, UInt8, UInt8), q:UInt8) {
    let mixFactor = Float(q) / 128
    let mixValue = UInt8( Float(lastValues.2) * (1 - mixFactor) + Float(blindValues.2) * mixFactor)
    send((lastValues.0, lastValues.1, mixValue))
  }
  
  func send(_ values:(UInt8, UInt8, UInt8)) {
    var packet = MIDIPacket()
    packet.timeStamp = 0
    packet.length = 3
    // packet.data = midiDataTuple
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
