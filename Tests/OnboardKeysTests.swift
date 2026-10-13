import Foundation
@main struct OnboardKeysTests {
 static func main()throws {
  func expect(_ b:Bool,_ name:String) {if !b {fatalError(name)};print("PASS",name)}
  let original=try OnboardKeys(TestFixtures.keys())
  expect(original.normalEntry(0x06)==[0,0,0,6],"C original keeps normal C")
  expect(original.fnKey(0x1e)==0x70000003a,"Fn + 1 decoded from protocol fixture is F1")
  expect(original.fnKey(0x04)==0x700000050,"Fn + A decoded from protocol fixture is left arrow")
  var patched=original;try patched.assignFn(6,key:0x68)
  expect(patched.normalEntry(6)==[0,0,0,6],"Fn edit preserves plain C")
  expect(patched.fnKey(6)==0x700000068,"Fn + C has its own output")
  let changes=zip(original.bytes,patched.bytes).enumerated().filter{$0.element.0 != $0.element.1}.map(\.offset)
  expect(changes==[96,99,659,851],"Only C selector and its allocated pair change")
  expect(Array(patched.writeReport.prefix(8))==[6,4,0xd4,0,0x40,0,0,0],"Write header matches recorded official driver report")
  print("changed offsets",changes)
 }
}
