import Foundation
struct Key:Identifiable,Hashable {let label:String;let usage:UInt64;var width:Double=1;var page:UInt64=7;var id:UInt64 {(page<<32)|usage}}
let keyboardRows:[[Key]] = [
    [Key(label:"esc",usage:0x29)] + (1...9).map{Key(label:String($0),usage:UInt64(0x1d+$0))} + [Key(label:"0",usage:0x27),Key(label:"−",usage:0x2d),Key(label:"=",usage:0x2e),Key(label:"delete",usage:0x2a,width:2)],
    [Key(label:"tab",usage:0x2b,width:1.5)] + Array("QWERTYUIOP").map{Key(label:String($0),usage:UInt64(String($0.lowercased()).unicodeScalars.first!.value-97+4))} + [Key(label:"[",usage:0x2f),Key(label:"]",usage:0x30),Key(label:"\\",usage:0x31,width:1.5)],
    [Key(label:"caps",usage:0x39,width:1.75)] + Array("ASDFGHJKL").map{Key(label:String($0),usage:UInt64(String($0.lowercased()).unicodeScalars.first!.value-97+4))} + [Key(label:";",usage:0x33),Key(label:"'",usage:0x34),Key(label:"return",usage:0x28,width:2.25)],
    [Key(label:"shift",usage:0xe1,width:2.25)] + Array("ZXCVBNM").map{Key(label:String($0),usage:UInt64(String($0.lowercased()).unicodeScalars.first!.value-97+4))} + [Key(label:",",usage:0x36),Key(label:".",usage:0x37),Key(label:"/",usage:0x38),Key(label:"shift",usage:0xe5,width:2.75)],
    [Key(label:"ctrl",usage:0xe0,width:1.25),Key(label:"win",usage:0xe3,width:1.25),Key(label:"alt",usage:0xe2,width:1.25),Key(label:"space",usage:0x2c,width:6.25),Key(label:"alt",usage:0xe6,width:1.25),Key(label:"fn",usage:0xffff,width:1.25),Key(label:"menu",usage:0x65,width:1.25),Key(label:"ctrl",usage:0xe4,width:1.25)]
]
let functionKeys:[Key] = (1...24).map { (number:Int) -> Key in
    let usage:Int = number<=12 ? 0x39+number : 0x68+number-13
    return Key(label:"F\(number)",usage:UInt64(usage))
}
let extraKeys:[Key] = functionKeys + [Key(label:"Command derecho",usage:0xe7),Key(label:"←",usage:0x50),Key(label:"↓",usage:0x51),Key(label:"↑",usage:0x52),Key(label:"→",usage:0x4f),Key(label:"Insert",usage:0x49),Key(label:"Inicio",usage:0x4a),Key(label:"Fin",usage:0x4d),Key(label:"RePág",usage:0x4b),Key(label:"AvPág",usage:0x4e),Key(label:"Suprimir",usage:0x4c),Key(label:"Volumen +",usage:0xe9,page:12),Key(label:"Volumen −",usage:0xea,page:12),Key(label:"Silenciar",usage:0xe2,page:12),Key(label:"Play / Pausa",usage:0xcd,page:12),Key(label:"Siguiente pista",usage:0xb5,page:12),Key(label:"Anterior pista",usage:0xb6,page:12),Key(label:"ISO < >",usage:0x64)]
let baseKeys=keyboardRows.flatMap{$0}.filter{$0.usage != 0xffff}+extraKeys
func keyLabel(_ id:UInt64)->String {baseKeys.first{$0.id==id}.map {k in switch k.usage {case 0xe0:return "Ctrl izquierdo";case 0xe1:return "Shift izquierdo";case 0xe2 where k.page==7:return "Option / Alt izquierdo";case 0xe3:return "Command / Win";case 0xe4:return "Ctrl derecho";case 0xe5:return "Shift derecho";case 0xe6:return "Option / Alt derecho";default:return k.label}} ?? String(format:"0x%llx",id)}

// Factory Fn combinations emit these ordinary HID keys; Fn itself stays inside the keyboard.
let fnTargets:[UInt64:UInt64] = {
    var targets:[UInt64:UInt64]=[0x2f:0x49,0x30:0x4c,0x33:0x4a,0x34:0x4d,0x37:0x4b,0x38:0x4e,0x1a:0x52,0x04:0x50,0x16:0x51,0x07:0x4f]
    for n in 1...9 {targets[UInt64(0x1d+n)]=UInt64(0x39+n)}
    targets[0x27]=0x43;targets[0x2d]=0x44;targets[0x2e]=0x45
    return targets
}()
func fnSourceID(_ physicalUsage:UInt64)->UInt64? {if let key=fnTargets[physicalUsage] {return 0x700000000|key};return configurableFnLetters.contains(physicalUsage) ? firmwareFnID(physicalUsage):nil}
func sourceLabel(_ id:UInt64)->String {
    if isFirmwareFn(id) {return "Fn + \(keyLabel(0x700000000|(id&0xffffffff)))"}
    guard id>>32==7,let physical=fnTargets.first(where:{$0.value==id&0xffffffff})?.key,
          let key=keyboardRows.flatMap({$0}).first(where:{$0.usage==physical}) else{return keyLabel(id)}
    return "Fn + \(key.label) · \(keyLabel(id))"
}

func firmwareFnID(_ physical:UInt64)->UInt64 {0xff0100000000|physical}
func isFirmwareFn(_ source:UInt64)->Bool {source>>32==0xff01}
let configurableFnLetters=Set((UInt64(4)...UInt64(29)).filter{fnTargets[$0]==nil && $0 != 0x10})
let allKeys=baseKeys+configurableFnLetters.sorted().map{Key(label:"Fn + \(keyLabel(0x700000000|$0))",usage:$0,page:0xff01)}
