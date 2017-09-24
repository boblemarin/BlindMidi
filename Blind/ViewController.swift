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

  
  
  @IBOutlet weak var ibMidiSourcesTableView: NSTableView!
  
  let clientName = "BlindMidi"
  var midiSourceNames = [String]()
  var midiClient:MIDIClientRef = 0
  var midiOut:MIDIEndpointRef = 0
  var midiIn:MIDIPortRef = 0
  
  var isBlindModeActive = false
  
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
     MIDIReceived(midiOut, pktList)
    
//      let packetList:MIDIPacketList = pktList.pointee
//      var packet:MIDIPacket = packetList.packet
//      for _ in 1...packetList.numPackets
//      {
//        let bytes = Mirror(reflecting: packet.data).children
//        var dumpStr = ""
//
//        // bytes mirror contains all the zero values in the ridiulous packet data tuple
//        // so use the packet length to iterate.
//        var i = packet.length
//        for (_, attr) in bytes.enumerated()
//        {
//          dumpStr += "\(attr.value as! UInt8) "
//          i -= 1
//          if (i <= 0)
//          {
//            break
//          }
//        }
//
//        print(dumpStr)
//        packet = MIDIPacketNext(&packet).pointee
//      }
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
