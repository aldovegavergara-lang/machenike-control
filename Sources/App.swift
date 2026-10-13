import SwiftUI
import AppKit
import ServiceManagement

final class AppDelegate:NSObject,NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    func applicationDidFinishLaunching(_ notification:Notification) {
        guard CommandLine.arguments.contains("--diagnostics"),let m=Model.current else{return}
        let values:[String:Any]=["connected":m.connected,"fnReadable":m.onboardKeys != nil,"fnStatus":m.fnStatus,"error":m.isError,"message":m.message,"confirmedShortcuts":m.confirmedShortcuts.map(\.combination),"registeredShortcuts":m.router.routes.map(\.combination),"handlers":m.router.references.count]
        if let data=try? JSONSerialization.data(withJSONObject:values,options:[.prettyPrinted,.sortedKeys]) {try? PrivateStorage.write(data,to:m.folder.appendingPathComponent("diagnostics.json"))}
    }
    func applicationWillTerminate(_ notification:Notification) {Model.current?.suspendShortcutsForExit()}
}
@main struct MachenikeApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var model=Model()
    var body:some Scene {
        MenuBarExtra("Machenike Control",systemImage:"keyboard") {MenuPanel().environmentObject(model)}.menuBarExtraStyle(.window)
        Window("Machenike Control",id:"main") {ContentView().environmentObject(model).preferredColorScheme(.light).frame(minWidth:1020,minHeight:740)}
        .defaultSize(width:1160,height:820)
        .defaultLaunchBehavior(CommandLine.arguments.contains("--show-settings") ? .presented:.suppressed)
        .commands {CommandGroup(replacing:.newItem) {}; CommandMenu("Teclado") {
            Button("Actualizar conexión") {model.refresh()}.keyboardShortcut("r")
            Button("Aplicar reasignaciones") {model.applyMapping(model.maps)}.keyboardShortcut("s")
            Button("Restaurar teclas") {model.restoreMaps()}
        }}
    }
}
