import Foundation
import AppKit
@main struct SecurityTests {
    static func main()throws {
        _=NSApplication.shared
        var checks=0
        func expect(_ b:Bool,_ label:String) {if !b {fatalError(label)};checks+=1;print("PASS",label)}
        func reject(_ label:String,_ action:()throws->Void) {do {try action();fatalError(label)}catch{checks+=1;print("PASS",label)}}
        for url in ["javascript:alert(1)","data:text/html,example","file:///tmp/payload.command","ssh://example.com","https://user:pass@example.com","https://user@example.com","https://example.com\nother"] {
            reject("Reject unsafe persisted target") {
                let data=try JSONSerialization.data(withJSONObject:["name":"Example","url":url])
                _=try JSONDecoder().decode(AppTarget.self,from:data)
            }
        }
        reject("Reject target with control characters") {_=try AppTarget.website("https://example.com",name:"Example\nforged log")}
        let valid=AppTarget(name:"Example",url:"https://example.com/path?x=1#section")
        expect(try valid.validatedURL().absoluteString==valid.url,"Valid custom HTTPS destination remains usable")
        let router=ShortcutRouter();var rejectedBeforeLaunch=false
        router.onResult={message,error in rejectedBeforeLaunch=error && message.contains("Elige una aplicación")}
        router.routes=[AppShortcut(source:0x700000039,target:AppTarget(name:"Example",url:"file:///tmp/payload.command"))]
        router.launch(0)
        expect(rejectedBeforeLaunch,"Launcher revalidates direct in-memory targets before opening them")
        for routes in [[AppShortcut](repeating:AppShortcut(source:0x700000039,target:valid),count:9),[AppShortcut(source:UInt64.max,target:valid)],[AppShortcut(source:0x700000039,target:valid,modifiers:UInt32.max)]] {
            reject("Reject malformed hotkeys before USB access") {_=try Hardware().prepareFn(routes,saved:nil)}
        }
        reject("Reject unsupported HID page") {try InputValidation.maps([KeyMap(source:UInt64.max,target:0x700000029)])}
        reject("Reject duplicate mappings") {try InputValidation.maps([KeyMap(source:0x700000039,target:0x700000029),KeyMap(source:0x700000039,target:0x700000028)])}
        var profile=Profile(name:"Example",maps:[],light:Lighting())
        profile.light.brightness=Int.max
        reject("Reject hostile lighting integers during profile decode") {_=try JSONDecoder().decode(Profile.self,from:JSONEncoder().encode(profile))}
        for size in [0,1,7,181,1031,1033,2048] {
            reject("Reject malformed key matrix size") {_=try OnboardKeys([UInt8](repeating:0,count:size))}
            reject("Reject malformed outbound USB size") {try Hardware.validateUSBReport([UInt8](repeating:0,count:size))}
        }
        for opcode in 0...255 where ![0x83,0x84,0x88].contains(opcode) {
            do {try Hardware.validateUSBReport([5,UInt8(opcode),0,0,0,0]);fatalError("Unexpected USB opcode allowed")}catch{}
        }
        checks+=253;print("PASS Reject 253 unexpected USB request opcodes")
        for value in 0...255 {
            var b=TestFixtures.keys();b[96]=2;b[99]=UInt8(value)
            let matrix=try OnboardKeys(b)
            _=matrix.normalEntry(6);_=matrix.fnKey(6)
        }
        checks+=256;print("PASS 256 malformed/valid Fn selectors parse without bounds failures")
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:directory)}
        let file=directory.appendingPathComponent("state.json")
        try PrivateStorage.write(Data("example".utf8),to:file)
        let fm=FileManager.default
        expect((try fm.attributesOfItem(atPath:directory.path)[.posixPermissions] as? NSNumber)?.intValue==0o700,"Private state directory is owner-only")
        expect((try fm.attributesOfItem(atPath:file.path)[.posixPermissions] as? NSNumber)?.intValue==0o600,"Private state file is owner-only")
        let link=directory.appendingPathComponent("link.json")
        try fm.createSymbolicLink(at:link,withDestinationURL:file)
        reject("Reject symlink state read") {_=try PrivateStorage.read(link)}
        reject("Reject symlink state write") {try PrivateStorage.write(Data("changed".utf8),to:link)}
        expect(try PrivateStorage.read(file)==Data("example".utf8),"Symlink attempt did not modify destination")
        let parentLink=directory.appendingPathComponent("linked-directory")
        try fm.createSymbolicLink(at:parentLink,withDestinationURL:directory)
        reject("Reject symlink parent state read") {_=try PrivateStorage.read(parentLink.appendingPathComponent("state.json"))}
        reject("Reject symlink parent state write") {try PrivateStorage.write(Data("changed".utf8),to:parentLink.appendingPathComponent("state.json"))}
        let oversized=directory.appendingPathComponent("large.json")
        try Data(repeating:0,count:PrivateStorage.limit+1).write(to:oversized)
        reject("Reject oversized persisted data") {_=try PrivateStorage.read(oversized)}
        print("Security checks:",checks,"No keyboard writes or external launches performed.")
    }
}
