import AppKit
import Carbon

struct AppTarget:Codable,Equatable,Identifiable {
    var name:String
    var url:String
    var id:String {url}
    static func installed(_ name:String,bundle:String,web:String?=nil)->AppTarget? {
        if let u=NSWorkspace.shared.urlForApplication(withBundleIdentifier:bundle) {return AppTarget(name:name,url:u.absoluteString)}
        if let web {return try? website(web,name:name+" · web")}
        return nil
    }
    var isApplication:Bool {URL(string:url)?.isFileURL == true}
    static func application(_ location:URL,name:String="")throws->AppTarget {
        guard location.isFileURL,(location.host ?? "").isEmpty || location.host=="localhost" else {throw HardwareError(message:"Elige una aplicación local.")}
        guard location.user==nil,location.password==nil,location.query==nil,location.fragment==nil,location.pathExtension.lowercased()=="app",Bundle(url:location) != nil else {throw HardwareError(message:"Elige una aplicación .app con Finder.")}
        let title=name.trimmingCharacters(in:.whitespacesAndNewlines)
        let fallback=FileManager.default.displayName(atPath:location.path).replacingOccurrences(of:".app",with:"")
        let display=title.isEmpty ? fallback:title;try InputValidation.name(display)
        return AppTarget(name:display,url:location.absoluteString)
    }
    static func website(_ input:String,name:String="")throws->AppTarget {
        var text=input.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty,text.utf8.count<=8192,text.rangeOfCharacter(from:.whitespacesAndNewlines)==nil,!text.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}) else {throw HardwareError(message:"Escribe una URL sin espacios, por ejemplo https://web.whatsapp.com.")}
        if !text.contains("://") {text="https://"+text}
        guard let components=URLComponents(string:text),let scheme=components.scheme?.lowercased(),["http","https"].contains(scheme),let host=components.host,!host.isEmpty,components.user==nil,components.password==nil,let location=components.url else {throw HardwareError(message:"La dirección debe ser una URL web http o https válida.")}
        let title=name.trimmingCharacters(in:.whitespacesAndNewlines)
        let display=title.isEmpty ? host:title;try InputValidation.name(display)
        return AppTarget(name:display,url:location.absoluteString)
    }
    func validatedURL()throws->URL {
        try InputValidation.name(name)
        guard let location=URL(string:url) else {throw HardwareError(message:"Destino inválido.")}
        if location.isFileURL {_=try Self.application(location,name:name)}
        else {_=try Self.website(url,name:name);guard ["http","https"].contains(location.scheme?.lowercased() ?? "") else {throw HardwareError(message:"Solo se permiten URLs http o https.")}}
        return location
    }
    enum CodingKeys:String,CodingKey {case name,url}
    init(name:String,url:String) {self.name=name;self.url=url}
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        name=try c.decode(String.self,forKey:.name);url=try c.decode(String.self,forKey:.url)
        _=try validatedURL()
    }
}
struct AppShortcut:Codable,Equatable,Identifiable {
    var source:UInt64
    var target:AppTarget
    var modifiers:UInt32=0
    var id:UInt64 {source}
    init(source:UInt64,target:AppTarget,modifiers:UInt32=0) {self.source=source;self.target=target;self.modifiers=modifiers}
    enum CodingKeys:String,CodingKey {case source,target,modifiers}
    init(from decoder:Decoder)throws {let c=try decoder.container(keyedBy:CodingKeys.self);source=try c.decode(UInt64.self,forKey:.source);target=try c.decode(AppTarget.self,forKey:.target);modifiers=try c.decodeIfPresent(UInt32.self,forKey:.modifiers) ?? 0}
    var combination:String {let p=[(UInt32(512),"Shift"),(UInt32(4096),"Control"),(UInt32(2048),"Option"),(UInt32(256),"Command")].filter{modifiers & $0.0 != 0}.map{$0.1};return (p+[sourceLabel(source)]).joined(separator:" + ")}
}
final class ShortcutRouter {
    static let slots:[UInt32]=[105,107,113,106,64,79,80,90] // macOS virtual key codes F13…F20
    var references:[EventHotKeyRef]=[]
    var routes:[AppShortcut]=[]
    var handler:EventHandlerRef?
    var onResult:((String,Bool)->Void)?
    init() {
        var spec=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        let context=Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(),{(_,event,context)->OSStatus in
            guard let event,let context else{return OSStatus(eventNotHandledErr)}
            var key=EventHotKeyID()
            let status=GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&key)
            guard status==noErr,key.signature==0x4d434b35 else{return OSStatus(eventNotHandledErr)}
            let router=Unmanaged<ShortcutRouter>.fromOpaque(context).takeUnretainedValue()
            router.launch(Int(key.id)-1);return noErr
        },1,&spec,context,&handler)
    }
    deinit {clear();if let handler {RemoveEventHandler(handler)}}
    func clear() {references.forEach{UnregisterEventHotKey($0)};references=[];routes=[]}
    func configure(_ new:[AppShortcut])throws {
        try InputValidation.shortcuts(new)
        guard handler != nil else {throw HardwareError(message:"macOS no permitió registrar los accesos globales a aplicaciones.")}
        guard new.count<=Self.slots.count else{throw HardwareError(message:"Puedes configurar hasta 8 accesos a apps o URLs.")}
        clear()
        for (index,route) in new.enumerated() {
            var reference:EventHotKeyRef?
            let id=EventHotKeyID(signature:0x4d434b35,id:UInt32(index+1))
            let status=RegisterEventHotKey(Self.slots[index],route.modifiers,id,GetApplicationEventTarget(),0,&reference)
            guard status==noErr,let reference else {clear();throw HardwareError(message:"F\(13+index) está reservada por otra app. Cambia ese atajo o cierra la app que lo usa.")}
            references.append(reference)
        }
        routes=new
    }
    static func effectiveMaps(_ maps:[KeyMap],shortcuts:[AppShortcut])throws->[KeyMap] {
        try InputValidation.maps(maps);try InputValidation.shortcuts(shortcuts)
        guard shortcuts.count<=slots.count,Set(shortcuts.map(\.source)).count==shortcuts.count else {throw HardwareError(message:"Máximo 8 accesos, sin repetir teclas.")}
        let sources=Set(shortcuts.map(\.source))
        let reserved=Set((0..<shortcuts.count).map{UInt64(0x700000068+$0)})
        guard !maps.contains(where:{!sources.contains($0.source) && reserved.contains($0.target)}) else {throw HardwareError(message:"Una reasignación usa una tecla F13–F20 reservada para abrir apps.")}
        var result=maps.filter{!isFirmwareFn($0.source) && !sources.contains($0.source)}
        result += shortcuts.enumerated().filter{!isFirmwareFn($0.element.source)}.map{KeyMap(source:$0.element.source,target:0x700000068+UInt64($0.offset))}
        return result
    }
    func launch(_ index:Int) {
        guard routes.indices.contains(index) else{return}
        let url:URL
        do {url=try routes[index].target.validatedURL()}catch{onResult?(error.localizedDescription,true);return}
        let target=routes[index].target
        let ok=NSWorkspace.shared.open(url)
        onResult?(ok ? "Abriendo \(target.name).":"No se pudo abrir \(target.name). Revisa el destino del acceso.",!ok)
    }
}
