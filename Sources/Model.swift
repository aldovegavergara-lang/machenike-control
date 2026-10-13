import SwiftUI
import AppKit
import UniformTypeIdentifiers
import IOKit.hid

final class Model:ObservableObject {
    static weak var current:Model?
    @Published var connected=false
    @Published var usbSummary="Buscando teclado…"
    @Published var maps:[KeyMap]=[]
    @Published var appliedMaps:[KeyMap]=[]
    @Published var shortcuts:[AppShortcut]=[]
    @Published var appliedShortcuts:[AppShortcut]=[]
    @Published var appTargets:[AppTarget]=[]
    @Published var selectedApp=""
    @Published var showTargetEditor=false
    @Published var targetType=0
    @Published var targetName=""
    @Published var targetAddress=""
    @Published var targetEditorError=""
    @Published var light=Lighting()
    @Published var profiles:[Profile]=[]
    @Published var message="Selecciona una tecla para cambiar su función."
    @Published var isError=false
    @Published var busy=false
    @Published var rgbChecked=false
    @Published var rgbStatus="Acceso RGB pendiente de comprobar"
    @Published var selected:UInt64=0x700000039
    @Published var destination:UInt64=0x700000039
    @Published var editKind=0
    @Published var mappingVerified=false
    @Published var onboardKeys:OnboardKeys?
    @Published var fnStatus="Capa Fn pendiente de leer"
    @Published var shortcutModifiers:UInt32=0
    @Published var macArrowShortcuts=MacArrowShortcut.read()
    @Published var profileName="Mi perfil"
    @Published var reapply=false
    let hardware=Hardware()
    let router=ShortcutRouter()
    let folder:URL
    var timer:Timer?
    var activeMaps:[KeyMap]?
    var activatedRawMaps:[KeyMap]=[]
    var appPickerRequested=false
    init(preview:Bool=false) {
        folder=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Machenike Control",isDirectory:true)
        try? PrivateStorage.ensureDirectory(folder)
        if let data=try? PrivateStorage.read(folder.appendingPathComponent("profiles.json")),let p=try? JSONDecoder().decode([Profile].self,from:data) {profiles=p}
        if let data=try? PrivateStorage.read(folder.appendingPathComponent("targets.json")),let targets=try? JSONDecoder().decode([AppTarget].self,from:data) {appTargets=targets}
        Model.current=self
        router.onResult = { [weak self] message,error in
            guard let self else{return};self.message=message;self.isError=error

        }
        refresh()
        readOnboardKeys()
        if connected {do{maps=try hardware.mappingState();appliedMaps=maps}catch{report(error)}}
        if let data=try? PrivateStorage.read(folder.appendingPathComponent("active.json")),let p=try? JSONDecoder().decode(Profile.self,from:data) {
            maps=p.maps;shortcuts=p.shortcuts;light=p.light;profileName=p.name;reapply=true
            if preview {appliedShortcuts=shortcuts;router.routes=shortcuts;activatedRawMaps=maps}
            if connected && !preview {
                applyMapping(maps)
                // Carbon launch handlers do not require USB/Input Monitoring access. A saved
                // onboard assignment can keep working while USB inspection awaits permission.
                if isError,message.contains("e00002e2"),let saved=try? PrivateStorage.read(folder.appendingPathComponent("Fn-State.json")),let state=try? JSONDecoder().decode(FnState.self,from:saved),let expected=try? OnboardKeys(state.expected),shortcuts.enumerated().allSatisfy({slot,route in !isFirmwareFn(route.source) || expected.fnKey(route.source&0xffffffff)==0x700000068+UInt64(slot)}) {
                    do {
                        let effective=try ShortcutRouter.effectiveMaps(maps,shortcuts:shortcuts)
                        try router.configure(shortcuts)
                        try hardware.applyMaps(effective)
                        appliedMaps=effective;appliedShortcuts=shortcuts;activeMaps=effective;activatedRawMaps=maps
                        success("Atajos registrados. La capa Fn guardada está pendiente de comprobar por USB; macOS aún bloquea esa lectura.")
                    }catch{report(error)}
                }
            }
        }
        for target in profiles.flatMap({$0.shortcuts.map(\.target)})+shortcuts.map(\.target) {
            if !appTargets.contains(where:{$0.id==target.id}) {appTargets.append(target)}
        }
        selectedApp=appTargets.first?.id ?? ""
        selectSource(selected)
        timer=Timer.scheduledTimer(withTimeInterval:3,repeats:true){[weak self] _ in self?.refresh()}
    }
    func refresh() {
        if busy {return}
        let was=connected;let d=hardware.info();connected=d.connected
        usbSummary=connected ? String(format:"USB 258A:0049 · revisión %04X · %d bytes HID",d.version,d.featureSize):"Conecta tu K500-B61 por cable USB"
        macArrowShortcuts=MacArrowShortcut.read()
        if connected {
            do {
                let wasClean=pendingChanges.isEmpty
                let live=try hardware.mappingState()+confirmedFnMaps;mappingVerified=true
                if live != appliedMaps {
                    appliedMaps=live
                    if wasClean {maps=liveRawMaps;shortcuts=confirmedShortcuts}
                }
            }catch{mappingVerified=false}
        }
        if !connected {mappingVerified=false;rgbChecked=false;rgbStatus="Teclado desconectado"}
        if connected && !was && reapply,activeMaps != nil {
            readOnboardKeys();applyMapping(maps)
        }
    }
    func suspendShortcutsForExit() {
        if !appliedShortcuts.isEmpty,let activeMaps,let current=try? hardware.mappingState(),current.sorted(by:{$0.source<$1.source})==activeMaps.sorted(by:{$0.source<$1.source}) {try? hardware.applyMaps(activatedRawMaps.filter{!isFirmwareFn($0.source)})}
        let fnFile=folder.appendingPathComponent("Fn-State.json")
        if let saved=try? PrivateStorage.read(fnFile),let plan=try? hardware.prepareFn([],saved:saved) {
            if plan.before==plan.after || (try? hardware.writeKeys(plan.after)) != nil {try? FileManager.default.removeItem(at:fnFile)}
        }
        router.clear()
    }
    func report(_ e:Error) {message=e.localizedDescription;isError=true}
    func success(_ s:String) {message=s;isError=false}
    var confirmedFnMaps:[KeyMap] {activatedRawMaps.filter{isFirmwareFn($0.source) && onboardKeys?.fnKey($0.source&0xffffffff)==$0.target}}
    var confirmedFn:Set<UInt64> {Set(appliedShortcuts.enumerated().compactMap {slot,route in isFirmwareFn(route.source) && onboardKeys?.fnKey(route.source&0xffffffff)==0x700000068+UInt64(slot) ? route.source:nil})}
    var confirmedShortcuts:[AppShortcut] {Configuration.confirmedRoutes(maps:appliedMaps,routes:appliedShortcuts,firmware:confirmedFn)}
    var liveRawMaps:[KeyMap] {let sources=Set(confirmedShortcuts.map(\.source));return appliedMaps.filter{!sources.contains($0.source)}}
    var registeredFn:Set<UInt64> {Set(appliedShortcuts.filter{isFirmwareFn($0.source) && router.routes.contains($0)}.map(\.source))}
    var pendingFn:Set<UInt64> {onboardKeys==nil ? registeredFn:confirmedFn}
    var unverifiedRoutes:[AppShortcut] {appliedShortcuts.filter{!confirmedShortcuts.contains($0)}}
    var pendingChanges:[ConfigChange] {Configuration.differences(liveMaps:appliedMaps,liveRoutes:appliedShortcuts,draftMaps:maps,draftRoutes:shortcuts,firmware:pendingFn)}
    func currentAction(_ source:UInt64)->ConfigAction {Configuration.liveAction(source,maps:appliedMaps,routes:appliedShortcuts,firmware:pendingFn)}
    var selectedCurrent:ConfigAction {currentAction(selected)}
    var editorAction:ConfigAction {
        if editKind==2,let target=appTargets.first(where:{$0.id==selectedApp}) {return .open(target,shortcutModifiers)}
        return .key(editKind==0 ? (isFirmwareFn(selected) ? 0x700000000|(selected&0xffffffff):selected):destination)
    }
    var editorChanged:Bool {editorAction != selectedCurrent}
    func selectSource(_ id:UInt64) {
        selected=id
        switch Configuration.desiredAction(id,maps:maps,routes:shortcuts) {
        case .key(let target):destination=target;editKind=target==(isFirmwareFn(id) ? 0x700000000|(id&0xffffffff):id) ? 0:1;shortcutModifiers=0
        case .open(let target,let modifiers):selectedApp=target.id;editKind=2;destination=id;shortcutModifiers=modifiers
        }
    }
    func applyEditor() {
        guard editKind != 2 || appTargets.contains(where:{$0.id==selectedApp}) else {report(HardwareError(message:"Añade y selecciona una app o URL."));return}
        let beforeMaps=maps,beforeShortcuts=shortcuts
        switch editorAction {
        case .key(let target):destination=target;addMap()
        case .open:addShortcut()
        }
        applyMapping(maps)
        if isError {maps=beforeMaps;shortcuts=beforeShortcuts}
    }
    func discardPending() {maps=liveRawMaps;shortcuts=confirmedShortcuts;selectSource(selected);success("Se muestra la configuración que está aplicada ahora.")}
    func addMap() {
        shortcuts.removeAll{$0.source==selected}
        maps.removeAll{$0.source==selected}
        if (isFirmwareFn(selected) ? 0x700000000|(selected&0xffffffff):selected) != destination {maps.append(KeyMap(source:selected,target:destination))}
        success("Cambio preparado. Pulsa Aplicar teclas para activarlo.")
    }
    func readOnboardKeys() {
        do {onboardKeys=try hardware.inspectKeys();fnStatus="Capa Fn leída del teclado"}catch{onboardKeys=nil;fnStatus=error.localizedDescription}
    }
    func applyMapping(_ new:[KeyMap]) {
        busy=true;defer{busy=false}
        let previousRoutes=appliedShortcuts,previousMaps=appliedMaps
        let fnFile=folder.appendingPathComponent("Fn-State.json")
        let previousFn=try? PrivateStorage.read(fnFile)
        var plan:FnPlan?
        var fnTouched=false,hostTouched=false
        do {
            try InputValidation.name(profileName);try InputValidation.lighting(light)
            let effective=try ShortcutRouter.effectiveMaps(new,shortcuts:shortcuts)
            plan=try hardware.prepareFn(shortcuts,maps:new,saved:previousFn)
            try router.configure(shortcuts)
            if let plan {
                if previousFn==nil {
                    let backup=folder.appendingPathComponent("Fn Backups",isDirectory:true)
                    try PrivateStorage.ensureDirectory(backup)
                    try PrivateStorage.write(Data(plan.before.bytes),to:backup.appendingPathComponent(UUID().uuidString+".bin"))
                }
                try PrivateStorage.write(JSONEncoder().encode(plan.state),to:fnFile)
                if plan.before != plan.after {fnTouched=true;try hardware.writeKeys(plan.after)}
                onboardKeys=plan.after;fnStatus="Capa Fn aplicada y leída del teclado"
            }
            hostTouched=true;try hardware.applyMaps(effective)
            let active=Profile(name:profileName,maps:new,light:light,shortcuts:shortcuts)
            try PrivateStorage.write(JSONEncoder().encode(active),to:folder.appendingPathComponent("active.json"))
            if let plan,plan.after.bytes==plan.state.baseline {try? FileManager.default.removeItem(at:fnFile)}
            activeMaps=effective;activatedRawMaps=new;appliedMaps=effective+new.filter{isFirmwareFn($0.source)};appliedShortcuts=shortcuts;mappingVerified=true
            success("Configuración aplicada y confirmada. El dibujo muestra lo que hace el teclado ahora.")
        }catch{
            var failures:[String]=[]
            if fnTouched,let plan {do {try hardware.writeKeys(plan.before);onboardKeys=plan.before}catch{failures.append("Restaurar Fn: \(error.localizedDescription)")}}
            if hostTouched {do {try hardware.applyMaps(previousMaps.filter{!isFirmwareFn($0.source)})}catch{failures.append("Restaurar teclas: \(error.localizedDescription)")}}
            do {try router.configure(previousRoutes)}catch{failures.append(error.localizedDescription)}
            if failures.isEmpty {
                if let previousFn {try? PrivateStorage.write(previousFn,to:fnFile)}else{try? FileManager.default.removeItem(at:fnFile)}
            }
            report(error)
            if !failures.isEmpty {message += "\n"+failures.joined(separator:"\n")}
        }
    }
    func restoreMaps() {
        let prepared=shortcuts;shortcuts=[];applyMapping([])
        if !isError {maps=[];activeMaps=nil;reapply=false;try? FileManager.default.removeItem(at:folder.appendingPathComponent("active.json"))}
        else {shortcuts=prepared}
    }
    func addShortcut() {
        guard let target=appTargets.first(where:{$0.id==selectedApp}) else{return}
        guard shortcuts.count<8 || shortcuts.contains(where:{$0.source==selected}) else {report(HardwareError(message:"Máximo 8 accesos a apps o URLs."));return}
        shortcuts.removeAll{$0.source==selected};maps.removeAll{$0.source==selected}
        shortcuts.append(AppShortcut(source:selected,target:target,modifiers:shortcutModifiers))
        success("\(sourceLabel(selected)) abrirá \(target.name). Pulsa Aplicar teclas.")
    }
    func beginTargetEditor() {
        targetType=0;targetName="";targetAddress="";targetEditorError="";showTargetEditor=true
    }
    func chooseApp() {
        appPickerRequested=true;showTargetEditor=false
    }
    func presentRequestedAppPicker() {
        guard appPickerRequested else{return}
        appPickerRequested=false
        let picker=NSOpenPanel();picker.directoryURL=URL(fileURLWithPath:"/Applications");picker.canChooseDirectories=false;picker.canChooseFiles=true;picker.allowsMultipleSelection=false;picker.allowedContentTypes=[.application];picker.treatsFilePackagesAsDirectories=false;picker.prompt="Elegir aplicación"
        picker.begin { [weak self] response in
            guard let self else{return}
            DispatchQueue.main.async {
                if response == .OK,let url=picker.url {
                    self.targetAddress=url.path
                    if self.targetName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {self.targetName=FileManager.default.displayName(atPath:url.path).replacingOccurrences(of:".app",with:"")}
                    self.targetEditorError=""
                }
                self.showTargetEditor=true
            }
        }
    }

    func saveTarget() {
        do {
            let target:AppTarget
            if targetType==0 {
                guard !targetAddress.isEmpty else {throw HardwareError(message:"Selecciona una aplicación con Finder.")}
                target=try AppTarget.application(URL(fileURLWithPath:targetAddress),name:targetName)
            } else {target=try AppTarget.website(targetAddress,name:targetName)}
            var updated=appTargets
            if let index=updated.firstIndex(where:{$0.id==target.id}) {updated[index]=target}else{updated.append(target)}
            try PrivateStorage.write(JSONEncoder().encode(updated),to:folder.appendingPathComponent("targets.json"))
            appTargets=updated;selectedApp=target.id;showTargetEditor=false
            editKind=2
            success("Destino guardado. Pulsa Aplicar configuración para asignarlo a la tecla seleccionada.")
        }catch{targetEditorError=error.localizedDescription}
    }
    func preset(_ name:String) {
        func k(_ s:UInt64,_ t:UInt64)->KeyMap {KeyMap(source:0x700000000|s,target:0x700000000|t)}
        let changes:[KeyMap]
        switch name {
        case "caps":changes=[k(0x39,0x29)]
        case "mac":changes=[k(0xe2,0xe3),k(0xe3,0xe2)]
        case "arrows":changes=[k(0xe5,0x52),k(0xe6,0x50),k(0x65,0x51),k(0xe4,0x4f)]
        default:changes=[]
        }
        let sources=Set(changes.map(\.source));maps.removeAll{sources.contains($0.source)};shortcuts.removeAll{sources.contains($0.source)};maps+=changes
        success("Preset preparado. Revisa el mapa y pulsa Aplicar teclas.")
    }
    func saveProfile() {
        let name=profileName.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty else{return}
        do {try InputValidation.name(name);try InputValidation.maps(maps);try InputValidation.shortcuts(shortcuts);try InputValidation.lighting(light)}catch{report(error);return}
        if let i=profiles.firstIndex(where:{$0.name==name}) {profiles[i].maps=maps;profiles[i].light=light;profiles[i].shortcuts=shortcuts}
        else {profiles.append(Profile(name:name,maps:maps,light:light,shortcuts:shortcuts))}
        do {try PrivateStorage.write(JSONEncoder().encode(profiles),to:folder.appendingPathComponent("profiles.json"));success("Perfil guardado en tu Mac.")}catch{report(error)}
    }
    func load(_ p:Profile) {maps=p.maps;shortcuts=p.shortcuts;light=p.light;profileName=p.name;selectSource(selected);success("Perfil preparado. Revisa los cambios pendientes y aplícalos para activarlo.")}
    func remove(_ p:Profile) {
        profiles.removeAll{$0.id==p.id}
        do {try PrivateStorage.write(JSONEncoder().encode(profiles),to:folder.appendingPathComponent("profiles.json"))}catch{report(error)}
    }
    func inspectRGB() {
        busy=true;rgbChecked=false
        DispatchQueue.global(qos:.userInitiated).async {
            let result=Result {try self.hardware.inspectRGB()}
            DispatchQueue.main.async {
                self.busy=false
                switch result {
                case .success(let value):self.light=value;self.rgbChecked=true;self.rgbStatus="Configuración y paleta leídas por USB";self.success("Lectura RGB completada. Ya puedes preparar cambios.")
                case .failure(let error):self.rgbStatus="Acceso RGB sin confirmar";self.report(error)
                }
            }
        }
    }
    func applyRGB() {
        let requested=light;busy=true
        DispatchQueue.global(qos:.userInitiated).async {
            let result=Result {try self.hardware.applyRGB(requested,backupDirectory:self.folder.appendingPathComponent("RGB Backups",isDirectory:true))}
            DispatchQueue.main.async {
                self.busy=false
                switch result {
                case .success:self.success("Modo, brillo y color enviados y confirmados por USB. Comprueba las luces del teclado.")
                case .failure(let error):self.report(error)
                }
            }
        }
    }
    func restoreRGB() {
        busy=true
        DispatchQueue.global(qos:.userInitiated).async {
            let result=Result {try self.hardware.restoreRGB(backupDirectory:self.folder.appendingPathComponent("RGB Backups",isDirectory:true))}
            DispatchQueue.main.async {
                self.busy=false
                switch result {case .success:self.success("Iluminación anterior restaurada y confirmada por USB.");case .failure(let error):self.report(error)}
            }
        }
    }
    func requestPermission() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {NSWorkspace.shared.open(url)}
        success("Activa Machenike Control en Monitoreo de entrada y vuelve a abrir la app.")
    }
    var color:Color {
        get {Color(red:Double(light.red)/255,green:Double(light.green)/255,blue:Double(light.blue)/255)}
        set {let c=NSColor(newValue).usingColorSpace(.deviceRGB) ?? .white;light.red=Int((c.redComponent*255).rounded());light.green=Int((c.greenComponent*255).rounded());light.blue=Int((c.blueComponent*255).rounded())}
    }
}
