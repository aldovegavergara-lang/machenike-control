import Foundation

enum ConfigAction:Equatable {
    case key(UInt64)
    case open(AppTarget,UInt32=0)
    var label:String {switch self {case .key(let id):return functionName(id);case .open(let target,let modifiers):return (modifiers==512 ? "Shift + esta tecla: ":"")+"Abrir \(target.name)"}}
}
struct ConfigChange:Identifiable {
    let source:UInt64;let current:ConfigAction;let prepared:ConfigAction
    var id:UInt64 {source}
}
struct Configuration {
    static func confirmedRoutes(maps:[KeyMap],routes:[AppShortcut],firmware:Set<UInt64>=[])->[AppShortcut] {
        routes.enumerated().compactMap {index,route in
            if isFirmwareFn(route.source) {return firmware.contains(route.source) ? route:nil}
            return maps.contains(where:{$0.source==route.source && $0.target==0x700000068+UInt64(index)}) ? route:nil
        }
    }
    static func liveAction(_ source:UInt64,maps:[KeyMap],routes:[AppShortcut],firmware:Set<UInt64>=[])->ConfigAction {
        if let route=confirmedRoutes(maps:maps,routes:routes,firmware:firmware).first(where:{$0.source==source}) {return .open(route.target,route.modifiers)}
        return .key(maps.first(where:{$0.source==source})?.target ?? (isFirmwareFn(source) ? 0x700000000|(source&0xffffffff):source))
    }
    static func desiredAction(_ source:UInt64,maps:[KeyMap],routes:[AppShortcut])->ConfigAction {
        if let route=routes.first(where:{$0.source==source}) {return .open(route.target,route.modifiers)}
        return .key(maps.first(where:{$0.source==source})?.target ?? (isFirmwareFn(source) ? 0x700000000|(source&0xffffffff):source))
    }
    static func differences(liveMaps:[KeyMap],liveRoutes:[AppShortcut],draftMaps:[KeyMap],draftRoutes:[AppShortcut],firmware:Set<UInt64>=[])->[ConfigChange] {
        let sources=Set((liveMaps+draftMaps).map(\.source)+liveRoutes.map(\.source)+draftRoutes.map(\.source))
        return sources.sorted().compactMap {source in
            let actual=liveAction(source,maps:liveMaps,routes:liveRoutes,firmware:firmware)
            let desired=desiredAction(source,maps:draftMaps,routes:draftRoutes)
            return actual==desired ? nil:ConfigChange(source:source,current:actual,prepared:desired)
        }
    }
}
func functionName(_ id:UInt64)->String {
    if isFirmwareFn(id) {return functionName(0x700000000|(id&0xffffffff))}
    switch id {
    case 0x7000000e0:return "Control izquierdo (⌃)"
    case 0x7000000e4:return "Control derecho (⌃)"
    case 0x7000000e1:return "Shift izquierdo (⇧)"
    case 0x7000000e5:return "Shift derecho (⇧)"
    case 0x7000000e2:return "Option izquierdo (⌥)"
    case 0x7000000e6:return "Option derecho (⌥)"
    case 0x7000000e3:return "Command izquierdo (⌘)"
    case 0x7000000e7:return "Command derecho (⌘)"
    case 0x700000039:return "Bloqueo de mayúsculas"
    case 0x70000002a:return "Borrar hacia atrás"
    case 0x700000028:return "Enter"
    case 0x70000002b:return "Tabulador"
    case 0x70000002c:return "Espacio"
    case 0x700000029:return "Escape"
    default:return keyLabel(id)
    }
}
func inputName(_ id:UInt64)->String {
    if id==0x7000000e3 {return "Win"}
    if id==0x7000000e2 {return "Alt izquierdo"}
    if id==0x7000000e6 {return "Alt derecho"}
    let label=sourceLabel(id)
    if let range=label.range(of:" · ") {return String(label[..<range.lowerBound])}
    return label
}
struct MacArrowShortcut:Identifiable {
    let preferenceID:String;let arrow:String;let keyCode:Int;let action:String
    var enabled:Bool?
    var defaultCombination=true
    var id:String {preferenceID}
    var available:Bool {enabled != false && defaultCombination}
    var status:String {if !defaultCombination {return "Combinación cambiada"};return enabled.map{$0 ? "Activado":"Desactivado"} ?? "Atajo predeterminado"}
    static func read()->[MacArrowShortcut] {
        var rows=[MacArrowShortcut(preferenceID:"79",arrow:"←",keyCode:123,action:"Escritorio anterior"),MacArrowShortcut(preferenceID:"81",arrow:"→",keyCode:124,action:"Escritorio siguiente"),MacArrowShortcut(preferenceID:"32",arrow:"↑",keyCode:126,action:"Mission Control"),MacArrowShortcut(preferenceID:"33",arrow:"↓",keyCode:125,action:"Ventanas de la app")]
        let url=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")
        guard let data=try? Data(contentsOf:url),let root=try? PropertyListSerialization.propertyList(from:data,options:[],format:nil) as? [String:Any],let entries=root["AppleSymbolicHotKeys"] as? [String:[String:Any]] else{return rows}
        for index in rows.indices {
            guard let entry=entries[rows[index].preferenceID] else {continue}
            rows[index].enabled=entry["enabled"] as? Bool
            if let value=entry["value"] as? [String:Any],let p=value["parameters"] as? [Int],p.count==3 {
                rows[index].defaultCombination=p[1]==rows[index].keyCode && p[2]==262144
            }
        }
        return rows
    }
}
