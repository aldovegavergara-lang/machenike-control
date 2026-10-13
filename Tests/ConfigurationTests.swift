import Foundation
@main struct ConfigurationTests {
    static func main()throws {
        func expect(_ value:Bool,_ name:String) {if !value {fatalError(name)};print("PASS",name)}
        let option=UInt64(0x7000000e2),command=UInt64(0x7000000e3),f1=UInt64(0x70000003a)
        let swap=[KeyMap(source:command,target:option),KeyMap(source:option,target:command)]
        expect(Configuration.differences(liveMaps:swap,liveRoutes:[],draftMaps:swap,draftRoutes:[]).isEmpty,"Applied modifier swaps are not shown as pending changes")
        expect(Configuration.liveAction(command,maps:swap,routes:[]) == .key(option),"Win current action reflects the map read from macOS")
        let chrome=AppTarget(name:"Chrome",url:"https://example.com/")
        let route=[AppShortcut(source:f1,target:chrome)]
        expect(Configuration.liveAction(f1,maps:swap,routes:route) == .key(f1),"A saved app shortcut without an active HID route is not shown as active")
        let live=swap+[KeyMap(source:f1,target:0x700000068)]
        expect(Configuration.liveAction(f1,maps:live,routes:route) == .open(chrome),"Read-back HID route and app handler together confirm an app action")
        expect(Configuration.differences(liveMaps:live,liveRoutes:route,draftMaps:swap,draftRoutes:route).isEmpty,"Internal routing key is hidden from pending changes")
        let pending=Configuration.differences(liveMaps:swap,liveRoutes:[],draftMaps:swap,draftRoutes:route)
        expect(pending.count==1 && pending[0].current == .key(f1) && pending[0].prepared == .open(chrome),"Pending app assignment shows true before and after actions")
        expect(inputName(command)=="Win" && functionName(option)=="Option izquierdo (⌥)","Physical key name and current macOS function have separate labels")
        expect(inputName(f1)=="Fn + 1","Normal interface hides internal F1 code from the combination name")
    }
}
