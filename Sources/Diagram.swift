import SwiftUI
import AppKit

let fnGuide:[UInt64:String] = {
    var f:[UInt64:String]=[0x29:"~ / reset",0x2f:"Insert",0x30:"Suprimir",0x33:"Inicio",0x34:"Fin",0x37:"RePág",0x38:"AvPág",0x1a:"↑",0x04:"←",0x16:"↓",0x07:"→",0x10:"Brillo RGB",0x36:"Velocidad",0x2c:"Elegir color",0xe6:"Efecto RGB",0xe3:"Bloquear Win"]
    for n in 1...9 {f[UInt64(0x1d+n)]="F\(n)"};f[0x27]="F10";f[0x2d]="F11";f[0x2e]="F12"
    return f
}()
func diagramLabel(_ id:UInt64)->String {
    switch id {
    case 0x7000000e0,0x7000000e4:return "Ctrl"
    case 0x7000000e1,0x7000000e5:return "Shift"
    case 0x7000000e2,0x7000000e6:return "Option"
    case 0x7000000e3,0x7000000e7:return "Command"
    case 0x700000035:return "~ / `"
    case 0xc000000e9:return "Vol +"
    case 0xc000000ea:return "Vol −"
    case 0xc000000e2:return "Mute"
    case 0xc000000cd:return "▶ / Ⅱ"
    default:return keyLabel(id)
    }
}
struct KeyboardDiagram:View {
    @EnvironmentObject var m:Model
    @Binding var layer:Int
    var interactive=true
    var rgbPreview=false
    var exportMode=false
    var draftFn=false
    var compact=false
    var body:some View {
        VStack(alignment:.leading,spacing:22) {
            HStack {
                if exportMode {
                    Text(layer==2 ? "Capa Fn":"Capa principal").font(.system(size:15,weight:.semibold))
                }else if !rgbPreview {
                    Text("Distribución").font(.system(size:14,weight:.semibold))
                    Spacer()
                    HStack(spacing:3) {
                        layerButton("Principal",0)
                        layerButton("Fn",2)
                        layerButton("Ctrl + Fn",3)
                    }.padding(3).background(ink,in:RoundedRectangle(cornerRadius:9))
                }else {Text("Vista previa").font(.system(size:14,weight:.semibold));Spacer();Circle().fill(m.color).frame(width:8,height:8)}
            }
            GeometryReader {g in
                let unit=(g.size.width-70)/15
                VStack(spacing:6) {ForEach(0..<keyboardRows.count,id:\.self) {i in HStack(spacing:5) {ForEach(keyboardRows[i]) {key in button(key,unit:unit)}}}}
            }.frame(height:compact ? 214:264)
            HStack(spacing:14) {
                Text(layer==3 ? "Cambiar escritorio · Control + Fn + A / D":layer==2 ? "Mantén Fn. ⇧ indica Shift.":"Selecciona una tecla para editarla.").font(.system(size:11)).foregroundStyle(muted)
                Spacer()
                Circle().fill(aqua).frame(width:5,height:5)
                Text("Personalizada").font(.system(size:10)).foregroundStyle(muted)
                if layer==2 && m.onboardKeys==nil {
                    Image(systemName:"info.circle").foregroundStyle(muted).help("Se muestran las funciones del manual y los atajos guardados. La lectura USB sigue pendiente.")
                }
            }
        }.foregroundStyle(graphite).surface(compact ? 18:24)
    }
    func layerButton(_ title:String,_ value:Int)->some View {
        Button {layer=value} label:{Text(title).font(.system(size:11,weight:layer==value ? .semibold:.regular)).padding(.horizontal,13).padding(.vertical,6).foregroundStyle(layer==value ? graphite:muted).background(layer==value ? Color.white:Color.clear,in:RoundedRectangle(cornerRadius:7)).shadow(color:.black.opacity(layer==value ? 0.04:0),radius:2,y:1)}.buttonStyle(.plain)
    }
    func button(_ key:Key,unit:Double)->some View {
        let maps=(layer==0 || ((layer==2 || layer==3) && !draftFn)) ? m.appliedMaps:m.maps
        let shortcuts=(layer==0 || ((layer==2 || layer==3) && !draftFn)) ? m.confirmedShortcuts:m.shortcuts
        let source=(layer==2 || layer==3) ? fnSourceID(key.usage):key.id
        let shortcut=source.flatMap {id in shortcuts.first{$0.source==id} ?? ((layer==2 && m.onboardKeys==nil) ? m.unverifiedRoutes.first{$0.source==id}:nil)}
        let map=source.flatMap {id in maps.first{$0.source==id}}
        let readFnTitle=m.onboardKeys?.fnKey(key.usage).map{diagramLabel($0)}
        let normalTitle=key.usage==0xffff ? "Fn":(layer==2 || layer==3) ? readFnTitle ?? fnGuide[key.usage] ?? "·":diagramLabel(key.id)
        let ordinaryTitle=shortcut?.target.name.replacingOccurrences(of:" · web",with:"") ?? map.map{diagramLabel($0.target)} ?? normalTitle
        let title=layer==3 ? controlTitle(source:(m.onboardKeys?.fnKey(key.usage) ?? source),mapped:map?.target):((shortcut?.modifiers ?? 0)==512 ? "⇧ +\n"+ordinaryTitle:ordinaryTitle)
        let selected=interactive && source==m.selected && !rgbPreview
        let custom=map != nil || (shortcut != nil && layer != 3)
        return Button {
            if let source,key.usage != 0xffff {m.selectSource(source)}
        } label:{
            VStack(spacing:3) {
                Text(title).font(.system(size:compact ? 10:11,weight:custom ? .semibold:.medium)).lineLimit(2).minimumScaleFactor(0.65).multilineTextAlignment(.center)
                if layer==2 || layer==3 || title.lowercased() != key.label.lowercased() {
                    Text(key.label).font(.system(size:8,weight:.medium)).foregroundStyle(muted)
                }
            }.padding(.horizontal,3)
                .frame(width:max(20,unit*key.width+(key.width-1)*5),height:compact ? 38:48)
                .foregroundStyle(custom || selected ? aqua:graphite.opacity(0.82))
                .background(rgbPreview ? m.color.opacity(0.1):selected ? aqua.opacity(0.08):Color(red:0.972,green:0.974,blue:0.979),in:RoundedRectangle(cornerRadius:7))
                .overlay(RoundedRectangle(cornerRadius:7).stroke(selected ? aqua.opacity(0.65):custom ? aqua.opacity(0.22):Color.black.opacity(0.085),lineWidth:selected ? 1.4:1))
                .shadow(color:.black.opacity(0.035),radius:0,y:2)
        }.buttonStyle(.plain).allowsHitTesting(interactive && !rgbPreview && key.usage != 0xffff && source != nil && layer != 3)
        .help(layer==3 ? title:layer==2 ? "Fn + \(key.label): \(shortcut?.target.name ?? title)" : "\(keyLabel(key.id)) → \(shortcut?.target.name ?? keyLabel(map?.target ?? key.id))")
    }
    func controlTitle(source:UInt64?,mapped:UInt64?)->String {
        guard let source else{return "·"}
        let target=mapped ?? (isFirmwareFn(source) ? 0x700000000|(source&0xffffffff):source)
        let arrow:[UInt64:String]=[0x700000050:"←",0x70000004f:"→",0x700000052:"↑",0x700000051:"↓"]
        if let glyph=arrow[target],let entry=m.macArrowShortcuts.first(where:{$0.arrow==glyph}),entry.available {
            switch glyph {case "←":return "Escritorio ←";case "→":return "Escritorio →";case "↑":return "Mission Control";default:return "Ventanas app"}
        }
        return "Ctrl + \(diagramLabel(target))"
    }

}
struct MenuPanel:View {
    @EnvironmentObject var m:Model
    @Environment(\.openWindow) var openWindow
    @State var layer=0
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                VStack(alignment:.leading,spacing:3) {Text("Machenike").font(.system(size:18,weight:.semibold));Text("K500 · B61").font(.system(size:11)).foregroundStyle(muted)}
                Spacer()
                Circle().fill(m.connected ? Color.green:aqua).frame(width:6,height:6)
                Button {openWindow(id:"main");NSApp.activate(ignoringOtherApps:true)} label:{Image(systemName:"slider.horizontal.3").frame(width:28,height:28)}.buttonStyle(.plain).help("Configuración")
            }
            KeyboardDiagram(layer:$layer,interactive:true,draftFn:false,compact:true)
            HStack {
                Text(inputName(m.selected)).font(.system(size:12,weight:.medium))
                Image(systemName:"arrow.right").font(.system(size:10)).foregroundStyle(muted)
                Text(detail).font(.system(size:12)).foregroundStyle(muted).lineLimit(1)
                Spacer()
                Button("Editar") {openWindow(id:"main");NSApp.activate(ignoringOtherApps:true)}.buttonStyle(QuietButton())
            }
            if !m.appliedShortcuts.isEmpty {
                HStack {ForEach(m.appliedShortcuts) {s in Label("\(s.combination) · \(s.target.name)",systemImage:s.target.isApplication ? "app":"link").font(.system(size:10)).foregroundStyle(muted).lineLimit(1)};Spacer()}
            }
            Divider().opacity(0.4)
            HStack {Text(m.connected ? "Conectado por USB":"Teclado desconectado").font(.system(size:10)).foregroundStyle(muted);Spacer();Button("Salir") {NSApp.terminate(nil)}.buttonStyle(.plain).font(.system(size:10)).foregroundStyle(muted)}
        }.padding(22).frame(width:710).background(ink).foregroundStyle(graphite).preferredColorScheme(.light).tint(aqua)
    }
    var detail:String {
        if layer==3 {return "Control + \(functionName(m.appliedMaps.first{$0.source==m.selected}?.target ?? m.selected))"}
        return m.appliedShortcuts.first{$0.source==m.selected}.map{($0.modifiers==512 ? "⇧ · ":"")+"Abrir \($0.target.name)"} ?? functionName(m.appliedMaps.first{$0.source==m.selected}?.target ?? m.selected)
    }
}
