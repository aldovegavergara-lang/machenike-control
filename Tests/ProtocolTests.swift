import Foundation
@main struct ProtocolTests {
    static func main()throws {
        func expect(_ b:Bool,_ label:String) {if !b {fatalError(label)};print("PASS",label)}
        let red=TestFixtures.palette()
        let green=try Hardware.paletteReport(red,lighting:Lighting(red:0,green:255,blue:0))
        expect(Array(green[29...31])==[0,255,0],"Static color uses the verified three-byte slot")
        expect(zip(red,green).enumerated().allSatisfy{[29,30,31].contains($0.offset) || $0.element.0==$0.element.1},"Palette preserves unrelated bytes")
        let config=TestFixtures.config(),changed=try Hardware.configReport(config,lighting:Lighting(mode:7,brightness:2))
        expect(changed[1]==3 && changed[21]==1 && changed[38]==7 && changed[39]==0x32,"RGB mode and brightness preserve the speed nibble")
        expect(zip(config,changed).enumerated().allSatisfy{[1,21,38,39].contains($0.offset) || $0.element.0==$0.element.1},"Preserve all unrelated config bytes")
        try Hardware.validateUSBReport(changed);try Hardware.validateUSBReport(green)
        for bad in [Lighting(mode:20),Lighting(brightness:-1),Lighting(brightness:5)] {
            do {_=try Hardware.configReport(config,lighting:bad);fatalError("Invalid lighting accepted")}catch{print("PASS Reject invalid RGB settings")}
        }
        do {_=try Hardware.paletteReport([6],lighting:Lighting());fatalError("Malformed palette accepted")}catch{print("PASS Reject malformed palette")}
        expect(Set(allKeys.map(\.id)).count==allKeys.count,"Remapping choices are unique")
    }
}
