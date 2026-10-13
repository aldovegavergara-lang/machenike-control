import Foundation
import IOKit
import IOKit.hid

struct HardwareError: LocalizedError { let message:String; var errorDescription:String? {message} }
struct KeyMap: Codable, Equatable, Identifiable { var source:UInt64; var target:UInt64; var id:UInt64 {source} }
struct Lighting: Codable, Equatable { var mode:Int = 0; var brightness:Int = 4; var red:Int = 0; var green:Int = 220; var blue:Int = 190 }
struct Profile: Codable, Identifiable {
    var id=UUID();var name:String;var maps:[KeyMap];var light:Lighting;var shortcuts:[AppShortcut]=[]
    init(name:String,maps:[KeyMap],light:Lighting,shortcuts:[AppShortcut]=[]) {self.name=name;self.maps=maps;self.light=light;self.shortcuts=shortcuts}
    enum CodingKeys:String,CodingKey {case id,name,maps,light,shortcuts}
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        id=try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID();name=try c.decode(String.self,forKey:.name)
        maps=try c.decode([KeyMap].self,forKey:.maps);light=try c.decode(Lighting.self,forKey:.light)
        shortcuts=try c.decodeIfPresent([AppShortcut].self,forKey:.shortcuts) ?? []
        try InputValidation.name(name);try InputValidation.maps(maps);try InputValidation.shortcuts(shortcuts);try InputValidation.lighting(light)
    }
}
struct DeviceInfo { let connected:Bool; let featureSize:Int; let version:Int; let location:Int }

final class Hardware {
    static let vendor=9610, product=73
    private static let transactionLock=NSLock()
    func devices()->[IOHIDDevice] {
        let manager=IOHIDManagerCreate(kCFAllocatorDefault,0)
        IOHIDManagerSetDeviceMatching(manager,[kIOHIDVendorIDKey:Self.vendor,kIOHIDProductIDKey:Self.product] as CFDictionary)
        return Array(IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? [])
    }
    func property(_ device:IOHIDDevice,_ key:String)->Int {(IOHIDDeviceGetProperty(device,key as CFString) as? NSNumber)?.intValue ?? 0}
    func info()->DeviceInfo {
        let ds=devices();let d=ds.max{property($0,kIOHIDMaxFeatureReportSizeKey)<property($1,kIOHIDMaxFeatureReportSizeKey)}
        return DeviceInfo(connected:!ds.isEmpty,featureSize:d.map{property($0,kIOHIDMaxFeatureReportSizeKey)} ?? 0,version:d.map{property($0,kIOHIDVersionNumberKey)} ?? 0,location:d.map{property($0,kIOHIDLocationIDKey)} ?? 0)
    }
    func withDevice<T>(_ action:(IOHIDDevice)throws->T)throws->T {
        Self.transactionLock.lock();defer{Self.transactionLock.unlock()}
        guard let d=devices().first(where:{property($0,kIOHIDMaxFeatureReportSizeKey)==1032}) else {throw HardwareError(message:"Conecta el K500-B61 por USB. No se encontró su interfaz RGB.")}
        let result=IOHIDDeviceOpen(d,0)
        guard result==kIOReturnSuccess else {throw HardwareError(message:"macOS bloqueó el acceso USB (\(String(format:"%08x",result))). Habilita Machenike Control en Monitoreo de entrada y vuelve a abrir la app.")}
        defer {IOHIDDeviceClose(d,0)}
        return try action(d)
    }
    func send(_ bytes:[UInt8], to d:IOHIDDevice)throws {
        try Self.validateUSBReport(bytes)
        let result=bytes.withUnsafeBufferPointer{IOHIDDeviceSetReport(d,kIOHIDReportTypeFeature,CFIndex(bytes[0]),$0.baseAddress!,bytes.count)}
        guard result==0 else {throw HardwareError(message:"El teclado rechazó el mensaje USB (\(String(format:"%08x",result))).")}
    }
    static func validateUSBReport(_ bytes:[UInt8])throws {
        if [[5,0x83,0xb6,0,0,0],[5,0x88,0xb8,0,0,0],[5,0x84,0xd4,0,0,0]].contains(bytes) {return}
        guard bytes.count==1032 else {throw HardwareError(message:"Tamaño de reporte USB inválido.")}
        let header=Array(bytes.prefix(8))
        guard header==[6,4,0xd4,0,0x40,0,0,0] || header==[6,8,0xb8,0,0x40,0,0,0] || (bytes[0]==6 && bytes[1]==3 && bytes[2]==0xb6 && bytes[14]==0x5a && bytes[15]==0xa5 && bytes[28]==0x55 && bytes[29]==0x55) else {throw HardwareError(message:"Comando USB fuera del protocolo permitido.")}
    }
    func readConfig(_ d:IOHIDDevice)throws->[UInt8] {
        try send([5,0x83,0xb6,0,0,0],to:d)
        var bytes=[UInt8](repeating:0,count:1032);bytes[0]=6;var count=bytes.count
        let result=bytes.withUnsafeMutableBufferPointer{IOHIDDeviceGetReport(d,kIOHIDReportTypeFeature,6,$0.baseAddress!,&count)}
        guard result==0 else {throw HardwareError(message:"No se pudo leer la configuración RGB (\(String(format:"%08x",result))).")}
        guard count>=182,bytes[0]==6,bytes[1]==0x83,bytes[2]==0xb6,bytes[14]==0x5a,bytes[15]==0xa5,bytes[28]==0x55,bytes[29]==0x55 else {throw HardwareError(message:"La configuración de esta revisión no coincide con el protocolo estudiado. No se enviaron cambios de iluminación.")}
        return bytes
    }
    func inspectRGB()throws->Lighting {
        try withDevice {d in let b=try readConfig(d);let p=try readPalette(d);return Lighting(mode:Int(b[38]),brightness:Int(b[39]&0x0f),red:Int(p[29]),green:Int(p[30]),blue:Int(p[31]))}
    }
    static func configReport(_ current:[UInt8], lighting:Lighting)throws->[UInt8] {
        guard current.count==1032, [0,7].contains(lighting.mode),(0...4).contains(lighting.brightness) else {throw HardwareError(message:"Configuración RGB fuera del rango comprobado.")}
        var b=current; if b.count<1032 {b += [UInt8](repeating:0,count:1032-b.count)}
        b[1]=3;b[21]=1;b[38]=UInt8(lighting.mode);b[39]=(b[39]&0xf0)|UInt8(lighting.brightness)
        return b
    }
    static func paletteReport(_ template:[UInt8], lighting:Lighting)throws->[UInt8] {
        guard template.count==1032,template.prefix(5)==[6,8,0xb8,0,0x40],(0...255).contains(lighting.red),(0...255).contains(lighting.green),(0...255).contains(lighting.blue) else {throw HardwareError(message:"Plantilla de color inválida.")}
        var b=template;b[29]=UInt8(lighting.red);b[30]=UInt8(lighting.green);b[31]=UInt8(lighting.blue);return b
    }
    func readPalette(_ d:IOHIDDevice)throws->[UInt8] {
        try send([5,0x88,0xb8,0,0,0],to:d)
        var b=[UInt8](repeating:0,count:1032);b[0]=6;var count=b.count
        let r=b.withUnsafeMutableBufferPointer {IOHIDDeviceGetReport(d,kIOHIDReportTypeFeature,6,$0.baseAddress!,&count)}
        guard r==0,count==1032,Array(b.prefix(8))==[6,0x88,0,0,0,0,0,0] else {throw HardwareError(message:"Esta revisión no permite leer la paleta RGB con el protocolo estudiado. No se modificó la iluminación.")}
        return b
    }
    func applyRGB(_ lighting:Lighting, backupDirectory:URL)throws->Lighting {
        try withDevice {d in
            let current=try readConfig(d)
            let palette=try readPalette(d)
            let folder=backupDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
            try PrivateStorage.ensureDirectory(folder)
            try PrivateStorage.write(Data(current),to:folder.appendingPathComponent("config.bin"))
            try PrivateStorage.write(Data(palette),to:folder.appendingPathComponent("palette.bin"))
            try PrivateStorage.write(Data(folder.lastPathComponent.utf8),to:backupDirectory.appendingPathComponent("last-backup.txt"))
            var template=palette;template.replaceSubrange(0..<8,with:[6,8,0xb8,0,0x40,0,0,0])
            // Preserve live settings and palette; never write firmware, bootloader or key matrix.
            if lighting.mode==0 {try send(Self.paletteReport(template,lighting:lighting),to:d)}
            try send(Self.configReport(current,lighting:lighting),to:d)
            let verify=try readConfig(d)
            guard verify[21]==1,Int(verify[38])==lighting.mode,Int(verify[39]&0x0f)==lighting.brightness else {throw HardwareError(message:"Se enviaron los mensajes, pero la lectura posterior no confirmó el modo y el brillo.")}
            if lighting.mode==0 {
                let color=try readPalette(d)
                guard color[29]==UInt8(lighting.red),color[30]==UInt8(lighting.green),color[31]==UInt8(lighting.blue) else {throw HardwareError(message:"El teclado confirmó modo y brillo, pero no confirmó el color elegido.")}
            }
            return lighting
        }
    }
    func restoreRGB(backupDirectory:URL)throws {
        let name=String(decoding:try PrivateStorage.read(backupDirectory.appendingPathComponent("last-backup.txt")),as:UTF8.self)
        guard UUID(uuidString:name) != nil else {throw HardwareError(message:"Respaldo RGB inválido.")}
        let folder=backupDirectory.appendingPathComponent(name,isDirectory:true)
        var config=Array(try PrivateStorage.read(folder.appendingPathComponent("config.bin")))
        var palette=Array(try PrivateStorage.read(folder.appendingPathComponent("palette.bin")))
        guard config.count==1032,config[1]==0x83,config[14]==0x5a,config[15]==0xa5,palette.count==1032,palette[1]==0x88 else {throw HardwareError(message:"Los respaldos no corresponden al protocolo validado.")}
        config[1]=3;palette.replaceSubrange(0..<8,with:[6,8,0xb8,0,0x40,0,0,0])
        try withDevice {d in
            _=try readConfig(d);_=try readPalette(d)
            try send(palette,to:d);try send(config,to:d)
            let verify=try readConfig(d),colors=try readPalette(d)
            guard verify[21]==config[21],verify[38]==config[38],verify[39]==config[39],Array(colors[8..<1016])==Array(palette[8..<1016]) else {throw HardwareError(message:"La restauración RGB no fue confirmada por el teclado.")}
        }
    }
    func mappingState()throws->[KeyMap] {
        var iterator:io_iterator_t=0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching("IOHIDEventService"),&iterator)==0 else {throw HardwareError(message:"No se pudo consultar el mapa activo.")}
        defer {IOObjectRelease(iterator)}
        var entry=IOIteratorNext(iterator)
        while entry != 0 {
            func prop(_ key:String)->Any? {IORegistryEntryCreateCFProperty(entry,key as CFString,kCFAllocatorDefault,0)?.takeRetainedValue()}
            if (prop("VendorID") as? NSNumber)?.intValue==Self.vendor,(prop("ProductID") as? NSNumber)?.intValue==Self.product,(prop("PrimaryUsage") as? NSNumber)?.intValue==6 {
                let eventProperties=prop("HIDEventServiceProperties") as? [String:Any]
                let rows=(prop("UserKeyMapping") ?? eventProperties?["UserKeyMapping"]) as? [[String:NSNumber]] ?? []
                let maps=rows.compactMap {r -> KeyMap? in guard let s=r["HIDKeyboardModifierMappingSrc"],let t=r["HIDKeyboardModifierMappingDst"] else{return nil};return KeyMap(source:s.uint64Value,target:t.uint64Value)}
                IOObjectRelease(entry);return maps
            }
            IOObjectRelease(entry);entry=IOIteratorNext(iterator)
        }
        throw HardwareError(message:"No se encontró el servicio de teclado. Reconecta el cable USB.")
    }
    func applyMaps(_ maps:[KeyMap])throws {
        try InputValidation.maps(maps)
        guard info().connected else {throw HardwareError(message:"Conecta el teclado antes de aplicar el mapa.")}
        guard Set(maps.map(\.source)).count==maps.count else {throw HardwareError(message:"Hay teclas de origen duplicadas.")}
        let rows=maps.map{["HIDKeyboardModifierMappingSrc":$0.source,"HIDKeyboardModifierMappingDst":$0.target]}
        let json=try JSONSerialization.data(withJSONObject:["UserKeyMapping":rows])
        let task=Process();task.executableURL=URL(fileURLWithPath:"/usr/bin/hidutil");task.arguments=["property","--matching","{\"VendorID\":9610,\"ProductID\":73}","--set",String(decoding:json,as:UTF8.self)]
        let output=Pipe();task.standardOutput=output;task.standardError=output;try task.run();let data=output.fileHandleForReading.readDataToEndOfFile();task.waitUntilExit()
        guard task.terminationStatus==0 else {throw HardwareError(message:String(decoding:data,as:UTF8.self))}
        guard try mappingState().sorted(by:{$0.source<$1.source})==maps.sorted(by:{$0.source<$1.source}) else {throw HardwareError(message:"macOS no confirmó la reasignación. Revisa Monitoreo de entrada.")}
    }
}
