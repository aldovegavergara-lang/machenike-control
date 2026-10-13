import Foundation
import IOKit.hid

// K500-B61 official Cfg.ini physical indices. Fn pairs live in the same 0xd4 key report.
// Each 4-byte entry is [kind, modifier, reserved, value]. Kind 2 selects a normal/Fn pair.
struct OnboardKeys:Equatable {
    var bytes:[UInt8]
    static let physicalIndices:[UInt64:Int]=[0x29:1,0x1e:7,0x1f:13,0x20:19,0x21:25,0x22:31,0x23:37,0x24:43,0x25:49,0x26:55,0x27:61,0x2d:67,0x2e:73,0x2a:79,0x2b:2,0x14:8,0x1a:14,0x08:20,0x15:26,0x17:32,0x1c:38,0x18:44,0x0c:50,0x12:56,0x13:62,0x2f:68,0x30:74,0x31:80,0x39:3,0x04:9,0x16:15,0x07:21,0x09:27,0x0a:33,0x0b:39,0x0d:45,0x0e:51,0x0f:57,0x33:63,0x34:69,0x28:81,0xe1:4,0x1d:10,0x1b:16,0x06:22,0x19:28,0x05:34,0x11:40,0x10:46,0x36:52,0x37:58,0x38:64,0xe0:5,0xe3:11,0xe2:17,0x2c:35,0xe6:53,0xffff:59,0x65:77,0xe4:83]
    init(_ bytes:[UInt8])throws {
        guard bytes.count==1032,Array(bytes.prefix(8))==[6,0x84,0xd4,0,0x84,0,0,0],Array(bytes[536..<540])==[0,0,0,0x1e],Array(bytes[728..<732])==[0,0,0,0x3a] else {throw HardwareError(message:"La matriz Fn no coincide con el K500-B61 estudiado. No se modificaron teclas internas.")}
        self.bytes=bytes
    }
    func entry(_ index:Int)->[UInt8] {Array(bytes[(8+index*4)..<(12+index*4)])}
    mutating func setEntry(_ index:Int,_ entry:[UInt8]) {bytes.replaceSubrange((8+index*4)..<(12+index*4),with:entry)}
    func pairIndex(_ physical:UInt64)->Int? {guard let index=Self.physicalIndices[physical] else{return nil};let value=entry(index);return value[0]==2 && value[3]<48 ? Int(value[3]):nil}
    func normalEntry(_ physical:UInt64)->[UInt8]? {guard let index=Self.physicalIndices[physical] else{return nil};if let pair=pairIndex(physical) {return entry(132+pair)};return entry(index)}
    func fnEntry(_ physical:UInt64)->[UInt8]? {guard let index=Self.physicalIndices[physical] else{return nil};if let pair=pairIndex(physical) {return entry(180+pair)};return entry(index)}
    func fnKey(_ physical:UInt64)->UInt64? {guard let e=fnEntry(physical),[0,6].contains(e[0]),e[1]==0,e[2]==0,e[3]>0 else{return nil};return 0x700000000|UInt64(e[3])}
    mutating func assignFn(_ physical:UInt64,key:UInt8)throws {
        guard (4...29).contains(physical),let index=Self.physicalIndices[physical],let normal=normalEntry(physical),normal==[0,0,0,UInt8(physical)] else {throw HardwareError(message:"Esta tecla no conserva una letra normal en la matriz. No se modificó su capa Fn.")}
        let pair:Int
        if let existing=pairIndex(physical) {pair=existing}
        else {
            let used=Set((0..<132).compactMap {i->Int? in let v=entry(i);return v[0]==2 && v[3]<48 ? Int(v[3]):nil})
            guard let free=(0..<48).first(where:{!used.contains($0) && entry(132+$0)==[0,0,0,0] && entry(180+$0)==[0,0,0,0]}) else {throw HardwareError(message:"No quedan pares Fn libres en el teclado.")}
            pair=free;setEntry(132+pair,normal);setEntry(index,[2,0,0,UInt8(pair)])
        }
        setEntry(180+pair,[0,0,0,key])
    }
    var writeReport:[UInt8] {var copy=bytes;copy.replaceSubrange(0..<8,with:[6,4,0xd4,0,0x40,0,0,0]);return copy}
}
extension Hardware {
    func readKeys(_ d:IOHIDDevice)throws->OnboardKeys {
        try send([5,0x84,0xd4,0,0,0],to:d)
        var b=[UInt8](repeating:0,count:1032);b[0]=6;var count=b.count
        let r=b.withUnsafeMutableBufferPointer{IOHIDDeviceGetReport(d,kIOHIDReportTypeFeature,6,$0.baseAddress!,&count)}
        guard r==0,count==1032 else{throw HardwareError(message:"No se pudo leer la capa Fn del teclado.")}
        return try OnboardKeys(b)
    }
    func inspectKeys()throws->OnboardKeys {try withDevice{try readKeys($0)}}
    func writeKeys(_ value:OnboardKeys)throws {try withDevice {d in _=try readConfig(d);try send(value.writeReport,to:d);guard try readKeys(d)==value else{throw HardwareError(message:"El teclado no confirmó la nueva capa Fn.")}}}
}
struct FnState:Codable {
    var baseline:[UInt8]
    var expected:[UInt8]
    var previous:[UInt8]
}
struct FnPlan {
    var before:OnboardKeys
    var after:OnboardKeys
    var state:FnState
}
extension Hardware {
    func prepareFn(_ routes:[AppShortcut],maps:[KeyMap]=[],saved:Data?)throws->FnPlan? {
        try InputValidation.maps(maps);try InputValidation.shortcuts(routes)
        guard saved != nil || (routes.contains(where:{isFirmwareFn($0.source)}) || maps.contains(where:{isFirmwareFn($0.source)})) else{return nil}
        let current=try inspectKeys()
        let baseline:OnboardKeys
        if let saved {
            let state=try JSONDecoder().decode(FnState.self,from:saved)
            guard current.bytes==state.expected || current.bytes==state.previous || current.bytes==state.baseline else {throw HardwareError(message:"La capa Fn cambió fuera de esta app. No se sobrescribirá. Conserva el respaldo Fn-State.json y vuelve a leer el teclado.")}
            baseline=try OnboardKeys(state.baseline)
        }else{baseline=current}
        var next=baseline
        for map in maps where isFirmwareFn(map.source) {
            guard map.target>>32==7,(4...0xe7).contains(map.target&0xffffffff) else {throw HardwareError(message:"La capa Fn admite una tecla de teclado; los controles multimedia todavía no están habilitados.")}
            try next.assignFn(map.source&0xffffffff,key:UInt8(map.target&0xffffffff))
        }
        for (slot,route) in routes.enumerated() where isFirmwareFn(route.source) {try next.assignFn(route.source&0xffffffff,key:UInt8(0x68+slot))}
        return FnPlan(before:current,after:next,state:FnState(baseline:baseline.bytes,expected:next.bytes,previous:current.bytes))
    }
}
