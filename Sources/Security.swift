import Foundation

/// Validate persisted configuration before it reaches a launcher, hotkey or USB writer.
enum InputValidation {
    static func name(_ value:String)throws {
        guard !value.isEmpty,value.utf8.count<=256,!value.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}) else {throw HardwareError(message:"Nombre vacío, demasiado largo o con caracteres de control.")}
    }
    static func maps(_ maps:[KeyMap])throws {
        let sources=Set(allKeys.map(\.id)),targets=Set(baseKeys.map(\.id))
        guard maps.count<=256,Set(maps.map(\.source)).count==maps.count,maps.allSatisfy({sources.contains($0.source) && targets.contains($0.target)}) else {throw HardwareError(message:"El mapa contiene teclas inválidas, duplicadas o demasiadas entradas.")}
    }
    static func shortcuts(_ routes:[AppShortcut])throws {
        guard routes.count<=8,Set(routes.map(\.source)).count==routes.count else {throw HardwareError(message:"Máximo 8 accesos, sin repetir teclas.")}
        let sources=Set(allKeys.map(\.id)),allowedModifiers:UInt32=256|512|2048|4096
        for route in routes {
            guard sources.contains(route.source),route.modifiers & ~allowedModifiers==0 else {throw HardwareError(message:"Acceso con tecla o modificadores inválidos.")}
            _=try route.target.validatedURL()
        }
    }
    static func lighting(_ light:Lighting)throws {
        guard [0,7].contains(light.mode),(0...4).contains(light.brightness),[light.red,light.green,light.blue].allSatisfy({(0...255).contains($0)}) else {throw HardwareError(message:"Color, brillo o modo fuera del rango permitido.")}
    }
}

/// Owner-only state. Never follow a symlink for an app-owned state file.
enum PrivateStorage {
    static let limit=2*1024*1024
    static func checkParents(_ url:URL)throws {
        var parent=url.deletingLastPathComponent()
        let fm=FileManager.default
        while parent.path != "/" {
            if let attributes=try? fm.attributesOfItem(atPath:parent.path),attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                // macOS owns these conventional root-level aliases; other links are rejected.
                let systemAlias=["/var","/tmp","/etc"].contains(parent.path) && (attributes[.ownerAccountID] as? NSNumber)?.intValue==0
                guard systemAlias else {throw HardwareError(message:"Se rechazó un enlace en la ruta de configuración.")}
            }
            parent=parent.deletingLastPathComponent()
        }
    }
    static func ensureDirectory(_ url:URL)throws {
        try checkParents(url)
        let fm=FileManager.default
        if fm.fileExists(atPath:url.path) {
            guard try fm.attributesOfItem(atPath:url.path)[.type] as? FileAttributeType == .typeDirectory else {throw HardwareError(message:"La carpeta de configuración no es un directorio seguro.")}
        }else{try fm.createDirectory(at:url,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])}
        try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:url.path)
    }
    static func checkFile(_ url:URL)throws {
        try checkParents(url)
        let attributes=try FileManager.default.attributesOfItem(atPath:url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {throw HardwareError(message:"Se rechazó un enlace o un archivo de configuración no regular.")}
    }
    static func read(_ url:URL)throws->Data {
        try checkFile(url)
        let attributes=try FileManager.default.attributesOfItem(atPath:url.path)
        guard (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= limit else {throw HardwareError(message:"El archivo de configuración es demasiado grande.")}
        let data=try Data(contentsOf:url)
        guard data.count<=limit else {throw HardwareError(message:"El archivo de configuración es demasiado grande.")}
        return data
    }
    static func write(_ data:Data,to url:URL)throws {
        guard data.count<=limit else {throw HardwareError(message:"El archivo de configuración es demasiado grande.")}
        try ensureDirectory(url.deletingLastPathComponent())
        if (try? FileManager.default.attributesOfItem(atPath:url.path)) != nil {try checkFile(url)}
        try data.write(to:url,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
}
