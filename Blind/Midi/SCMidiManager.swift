

import Foundation
import CoreMIDI


class SCMidiManager {
  
  // MARK: Singleton implementation
  private init() {
    _SCMidiInstance = self
  }
  static let shared = SCMidiManager()

  // MARK: Properties
  var midiClientName = ""
  var midiClient:MIDIClientRef = 0
  var midiOut:MIDIEndpointRef = 0
  var midiBack:MIDIEndpointRef = 0
  var midiIn:MIDIPortRef = 0
  var vrMidiIn = MIDIEndpointRef()
  var midiSources:[SCMidiSource]!
  var midiDestinations:[SCMidiDestination]!
  var connectedMidiSources = [Int32]()
  var previousMidiSources:[Int32]!
  var delegate:SCMidiDelegate?
  var sourcesDelegate:SCMidiSourcesDelegate?

  // MARK: Setup
  
  func setup(with configuration:SCMidiManagerConfiguration = SCMidiManagerConfiguration()) {
    // store global reference to singleton (for midi callbacks)
    _SCMidiInstance = self
    midiClientName = configuration.clientName as String
    
    // get delegates
    delegate = configuration.midiDelegate
    sourcesDelegate = configuration.midiSourcesDelegate
    
    // create virtual client, source and port
    MIDIClientCreate(configuration.clientName, SCMIDIStateChangedHander, nil, &midiClient)
    if configuration.enableVirtualSource {
      MIDISourceCreate(midiClient, configuration.clientName, &midiOut)
    }
    if configuration.enableMidiInput {
      MIDIInputPortCreate(midiClient, configuration.clientName, SCMIDIReadProc, nil, &midiIn)
      MIDIOutputPortCreate(midiClient, configuration.clientName, &midiBack)
    }
    if configuration.enableVirtualDestination {
      MIDIDestinationCreate(midiClient, configuration.clientName, SCVRMIDIReadProc, nil, &vrMidiIn)
    }
    
    // get source names
    previousMidiSources = UserDefaults.standard.array(forKey: "previousMidiSources") as? [Int32] ?? []
    midiSources = getSources()
    midiDestinations = getDestinations()
    
    for (i, source) in midiSources.enumerated() {
      if previousMidiSources.contains(source.uid) {
        listenTo(i)
        connectedMidiSources.append(source.uid)
        midiSources[i].listening = true
      }
    }
    
//    print("Connected sources : \(connectedMidiSources)")
//    print("Previous sources : \(previousMidiSources)")
  }
  
  func terminate() {
//    print("Saving previous sources : \(previousMidiSources)")
    UserDefaults.standard.set(previousMidiSources, forKey: "previousMidiSources")
  }
  
  // MARK: Midi I/O Utilities
  
  private func getDisplayName(_ obj: MIDIObjectRef) -> String
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
  
  private func getUniqueID(_ obj: MIDIObjectRef) -> Int32
  {
    var param: Int32 = 0
    MIDIObjectGetIntegerProperty(obj, kMIDIPropertyUniqueID, &param)
    return param
  }
  
  func getDestinations() -> [SCMidiDestination]
  {
    var destinations = [SCMidiDestination]()
    let count = MIDIGetNumberOfDestinations()
    for i in 0..<count {
      let endpoint:MIDIEndpointRef = MIDIGetDestination(i)
      if (endpoint != 0)
      {
        let name = getDisplayName(endpoint)
        if name != midiClientName {
          let dest = SCMidiDestination()
          dest.name = name
          dest.endPoint = endpoint
          destinations.append(dest)
        }
      }
    }
    return destinations
  }
  
  private func getSources() -> [SCMidiSource]
  {
    var sources = [SCMidiSource]()
    let count = MIDIGetNumberOfSources()
    for i in 0..<count {
      let endpoint = MIDIGetSource(i)
      if endpoint != 0 {
        let name = getDisplayName(endpoint)
        if name != midiClientName {
          let src = SCMidiSource()
          src.name = name
          src.uid = getUniqueID(endpoint)
          sources.append(src)
        }
      }
    }
    return sources
  }
  
  private func listenTo( _ i:Int ) {
    var src = MIDIGetSource(i)
    MIDIPortConnectSource(midiIn, src, &src)
  }
  
  private func stopListeningTo( _ i:Int ) {
    let src = MIDIGetSource(i)
    MIDIPortDisconnectSource(midiIn, src)
  }
  
  // MARK: Midi Input methods
  
  func toggleInput(_ i:Int) {
    let listening = !midiSources[i].listening
    midiSources[i].listening = listening
    let uid = midiSources[i].uid
    if listening {
      listenTo(i)
      connectedMidiSources.append(uid)
      if !previousMidiSources.contains(uid) {
        previousMidiSources.append(uid)
      }
    } else {
      stopListeningTo(i)
      if let index = connectedMidiSources.index(of: uid) {
        connectedMidiSources.remove(at: index)
      }
      if let index = previousMidiSources.index(of: uid) {
        previousMidiSources.remove(at: index)
      }
    }
//    print("Connected sources : \(connectedMidiSources)")
//    print("Previous sources : \(previousMidiSources)")
  }
  
  // MARK: MIDI Send
  
  func send(_ values:(UInt8, UInt8, UInt8), sendBack:Bool = false) {
    var packet = MIDIPacket()
    packet.timeStamp = 0
    packet.length = 3
    packet.data.0 = values.0
    packet.data.1 = values.1
    packet.data.2 = values.2
    
    var midiPacketList = MIDIPacketList(numPackets: 1, packet: packet)
    MIDIReceived(midiOut, &midiPacketList)
    
    if sendBack {
      for source in midiSources {
        if source.listening {
          MIDISend(midiBack, source.destination, &midiPacketList)
//          MIDIReceived(MIDIGetDestination(i), &midiPacketList)
//          print("Sending back to \(source.name) : \(values)")
        }
      }
    }
  }
  
  func sendBack(_ values:(UInt8, UInt8, UInt8)) {
    var packet = MIDIPacket()
    packet.timeStamp = 0
    packet.length = 3
    packet.data.0 = values.0
    packet.data.1 = values.1
    packet.data.2 = values.2
    var midiPacketList = MIDIPacketList(numPackets: 1, packet: packet)
    
    for source in midiSources {
      if source.listening {
        MIDISend(midiBack, source.destination, &midiPacketList)
      }
    }
  }
  
  // MARK: MIDI Callbacks
  
  func onMidiReceived(_ pktList:UnsafePointer<MIDIPacketList>) {
    guard let delegate = delegate else {
      return
    }
    
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
      
      delegate.handleMidi(midi)
      packet = MIDIPacketNext(&packet).pointee
    }
  }
  
  func onVirtualMidiReceived(_ pktList:UnsafePointer<MIDIPacketList>) {
    
  }
  
  func onMidiInputListChanged() {
    // get fresh input lists
    midiSources = getSources()
    midiDestinations = getDestinations()
    // transfer status properties
    for (i, source) in midiSources.enumerated() {
      let uid = source.uid
      if connectedMidiSources.contains(uid) {
        // already connected, mark as appropriate
        midiSources[i].listening = true
      } else if previousMidiSources.contains(uid) {
        // source has come back, connect and store
        connectedMidiSources.append(uid)
        midiSources[i].listening = true
        listenTo(i)
      }
      for destination in midiDestinations {
        if destination.name == source.name {
          source.destination = destination.endPoint
        }
      }
    }
    // tell delegate
    sourcesDelegate?.sourcesChanged(midiSources)
  }
}

// MARK: Global instance & listeners
var _SCMidiInstance:SCMidiManager?

func SCMIDIReadProc(pktList: UnsafePointer<MIDIPacketList>,
                    readProcRefCon: UnsafeMutableRawPointer?, srcConnRefCon: UnsafeMutableRawPointer?) -> Void
{
  _SCMidiInstance?.onMidiReceived(pktList)
}

func SCVRMIDIReadProc(pktList: UnsafePointer<MIDIPacketList>,
                      readProcRefCon: UnsafeMutableRawPointer?, srcConnRefCon: UnsafeMutableRawPointer?) -> Void
{
  _SCMidiInstance?.onVirtualMidiReceived(pktList)
}

func SCMIDIStateChangedHander(notification:UnsafePointer<MIDINotification>, rawPointer:UnsafeMutableRawPointer?) -> Void {
  if notification.pointee.messageID == .msgSetupChanged {
    _SCMidiInstance?.onMidiInputListChanged()
  }
}


// MARK: Code references
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
