import Foundation
import AppKit
@main struct FnShortcutTests {
 static func main()throws {
  _=NSApplication.shared
  func expect(_ b:Bool,_ name:String) {if !b {fatalError(name)};print("PASS",name)}
  let target=AppTarget(name:"Chrome",url:"https://example.com/")
  let route=AppShortcut(source:firmwareFnID(6),target:target,modifiers:512)
  expect(route.combination=="Shift + Fn + C","Combination label is explicit")
  expect(try ShortcutRouter.effectiveMaps([],shortcuts:[route]).isEmpty,"Firmware Fn route does not hijack plain C in macOS")
  let router=ShortcutRouter();try router.configure([route]);expect(router.references.count==1,"Shift + F13 global handler registered");router.clear()
  let decoded=try JSONDecoder().decode(AppShortcut.self,from:JSONEncoder().encode(route));expect(decoded==route,"Shift and Fn route survive restart")
  let old=Data("{\"source\":30064771130,\"target\":{\"name\":\"Chrome\",\"url\":\"https://example.com\"}}".utf8)
  expect(try JSONDecoder().decode(AppShortcut.self,from:old).modifiers==0,"Existing profiles remain compatible")
  expect(Configuration.confirmedRoutes(maps:[],routes:[route]).isEmpty,"Unread Fn route is not presented as verified")
  expect(Configuration.confirmedRoutes(maps:[],routes:[route],firmware:[route.source])==[route],"Read-back onboard route confirms current action")
  let before=Configuration.liveAction(route.source,maps:[],routes:[])
  expect(before == .key(0x700000006),"Unconfigured Fn + C reports C")
  let changed=Configuration.differences(liveMaps:[],liveRoutes:[route],draftMaps:[],draftRoutes:[AppShortcut(source:route.source,target:target)],firmware:[route.source])
  expect(changed.count==1,"Changing Shift requirement is shown as a pending change")
 }
}
