import Foundation
@main struct TargetTests {
    static func main()throws {
        func expect(_ value:Bool,_ name:String) {if !value {fatalError(name)};print("PASS",name)}
        let site=try AppTarget.website("example.com/tools?q=keyboard#rgb",name:"Mi herramienta")
        expect(site.name=="Mi herramienta" && site.url=="https://example.com/tools?q=keyboard#rgb" && !site.isApplication,"Custom website preserves path, query, fragment and label")
        let plain=try AppTarget.website("  https://example.com  ")
        expect(plain.name=="example.com","URL hostname supplies an optional name")
        for bad in ["", "https:///", "file:///tmp/example.app", "javascript:alert(1)", "https://bad host.com"] {
            do {_=try AppTarget.website(bad);fatalError("Accepted invalid web URL")}catch{print("PASS Reject invalid URL")}
        }
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let location=folder.appendingPathComponent("Example App.app")
        defer {try? FileManager.default.removeItem(at:folder)}
        try FileManager.default.createDirectory(at:location.appendingPathComponent("Contents"),withIntermediateDirectories:true)
        let info:[String:Any]=["CFBundleIdentifier":"org.example.test-app","CFBundleName":"Example App"]
        try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:location.appendingPathComponent("Contents/Info.plist"))
        let app=try AppTarget.application(location,name:"Mi navegador")
        expect(app.isApplication && app.name=="Mi navegador","App picker supports a named application path containing spaces")
        do {_=try AppTarget.application(URL(fileURLWithPath:"/tmp/not-an-app.txt"));fatalError("Accepted non-app")}catch{print("PASS Reject non-application picker destinations")}
        let custom=[site,app]
        let encoded=try JSONEncoder().encode(custom)
        expect(try JSONDecoder().decode([AppTarget].self,from:encoded)==custom,"Custom app and URL library survives persistence")
        let route=[AppShortcut(source:0x70000003a,target:site)]
        expect(try ShortcutRouter.effectiveMaps([],shortcuts:route)==[KeyMap(source:0x70000003a,target:0x700000068)],"Fn URL shortcuts use the existing verified route")
    }
}
