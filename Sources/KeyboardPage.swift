import SwiftUI

struct KeyboardPage:View {
    @EnvironmentObject var m:Model
    @State var layer=0
    @State var showSystem=false
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18) {
                KeyboardDiagram(layer:$layer)
                inspector
                if !m.liveRawMaps.isEmpty || !m.appliedShortcuts.isEmpty {currentChanges}
                if !m.pendingChanges.isEmpty {pendingChanges}
                DisclosureGroup("Atajos de macOS",isExpanded:$showSystem) {
                    VStack(spacing:12) {
                        ForEach(m.macArrowShortcuts) {shortcut in HStack {
                            Text("⌃ + Fn + \(["←":"A","→":"D","↑":"W","↓":"S"][shortcut.arrow] ?? shortcut.arrow)").font(.system(size:12,weight:.medium)).frame(width:140,alignment:.leading)
                            Text(shortcut.action).font(.system(size:12)).foregroundStyle(muted)
                            Spacer()
                            Image(systemName:shortcut.available ? "checkmark":"minus").font(.system(size:10)).foregroundStyle(muted).help(shortcut.status)
                        }}
                    }.padding(.top,16)
                }.font(.system(size:12,weight:.medium)).foregroundStyle(muted).surface(18)
            }.padding(.bottom,4)
        }.scrollIndicators(.hidden)
    }
    var inspector:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) {
                    Text(inputName(m.selected)).font(.system(size:21,weight:.semibold))
                    HStack(spacing:5) {
                        Text("Actual").foregroundStyle(muted)
                        Text(currentTitle).foregroundStyle(graphite)
                        if isFirmwareFn(m.selected) && m.onboardKeys==nil {Image(systemName:"info.circle").foregroundStyle(muted).help("El atajo está registrado. La lectura USB de la capa Fn sigue pendiente.")}
                    }.font(.system(size:12))
                }
                Spacer()
                Picker("Seleccionar tecla",selection:Binding(get:{m.selected},set:{m.selectSource($0)})) {ForEach(allKeys) {key in Text(inputName(key.id)).tag(key.id)}}.labelsHidden().frame(width:175)
            }
            Divider().opacity(0.5)
            HStack(alignment:.bottom,spacing:18) {
                VStack(alignment:.leading,spacing:7) {
                    fieldLabel("Acción")
                    Picker("Acción",selection:$m.editKind) {Text("Original").tag(0);Text("Otra función").tag(1);Text("App o URL").tag(2)}.labelsHidden().frame(width:170)
                }
                VStack(alignment:.leading,spacing:7) {
                    fieldLabel(m.editKind==2 ? "Destino":"Función")
                    if m.editKind==0 {Text(functionName(isFirmwareFn(m.selected) ? 0x700000000|(m.selected&0xffffffff):m.selected)).font(.system(size:12)).foregroundStyle(muted).frame(height:22,alignment:.leading)}
                    else if m.editKind==1 {
                        Picker("Función",selection:$m.destination) {ForEach(baseKeys) {key in Text(functionName(key.id)).tag(key.id)}}.labelsHidden()
                    } else {
                        HStack(spacing:7) {
                            if m.appTargets.isEmpty {Button("Elegir destino…") {m.beginTargetEditor()}.buttonStyle(.borderless)}
                            else {Picker("Destino",selection:$m.selectedApp) {ForEach(m.appTargets) {target in Text(target.name).tag(target.id)}}.labelsHidden()}
                            Button {m.beginTargetEditor()} label:{Image(systemName:"plus").font(.system(size:11,weight:.medium)).frame(width:22,height:22)}.buttonStyle(.plain).help("Añadir app o URL")
                        }
                    }
                }.frame(maxWidth:.infinity,alignment:.leading)
                if m.editKind==2 && (isFirmwareFn(m.selected) || fnTargets.values.contains(m.selected&0xffffffff)) {
                    VStack(alignment:.leading,spacing:7) {
                        fieldLabel("Además")
                        Picker("Modificador",selection:$m.shortcutModifiers) {Text("Ninguno").tag(UInt32(0));Text("⇧ Shift").tag(UInt32(512))}.labelsHidden().frame(width:100)
                    }
                }
                Button("Guardar") {m.applyEditor()}.buttonStyle(.borderedProminent).controlSize(.regular)
                    .disabled(!m.connected || m.busy || (!m.editorChanged && m.pendingChanges.isEmpty) || (m.editKind==2 && m.appTargets.isEmpty))
            }
            if m.editKind==2 {
                Text((isFirmwareFn(m.selected) || fnTargets.values.contains(m.selected&0xffffffff)) ? "\(m.shortcutModifiers==512 ? "Shift + ":"")\(inputName(m.selected)) → \(m.appTargets.first{$0.id==m.selectedApp}?.name ?? "elige un destino"). La tecla sin Fn conserva su función.":"Esta tecla abrirá el destino y dejará de escribir.")
                    .font(.system(size:11)).foregroundStyle(muted)
            }
            if m.editorChanged {Label("Sin guardar",systemImage:"circle.fill").font(.system(size:10)).foregroundStyle(aqua)}
        }.surface()
    }
    var currentTitle:String {
        switch m.selectedCurrent {
        case .key(let key):return functionName(key)
        case .open(let target,let modifiers):return (modifiers==512 ? "⇧ · ":"")+target.name
        }
    }
    func fieldLabel(_ text:String)->some View {Text(text).font(.system(size:11)).foregroundStyle(muted)}
    var currentChanges:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Tus ajustes").font(.system(size:14,weight:.semibold))
            ForEach(m.liveRawMaps) {map in adjustment(source:map.source,label:inputName(map.source),destination:diagramLabel(map.target),icon:"arrow.left.arrow.right")}
            ForEach(m.appliedShortcuts) {route in adjustment(source:route.source,label:route.combination,destination:route.target.name,icon:route.target.isApplication ? "app":"link")}
        }.surface()
    }
    func adjustment(source:UInt64,label:String,destination:String,icon:String)->some View {
        Button {m.selectSource(source);layer=(isFirmwareFn(source) || fnTargets.values.contains(source&0xffffffff)) ? 2:0} label:{
            HStack(spacing:12) {
                Image(systemName:icon).font(.system(size:12)).foregroundStyle(muted).frame(width:26,height:26).background(ink,in:RoundedRectangle(cornerRadius:7))
                Text(label).font(.system(size:12,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading)
                Text(destination).font(.system(size:12)).foregroundStyle(muted)
                Image(systemName:"chevron.right").font(.system(size:9,weight:.medium)).foregroundStyle(muted.opacity(0.6))
            }
        }.buttonStyle(.plain)
    }
    var pendingChanges:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Text("Cambios sin aplicar").font(.system(size:13,weight:.semibold));Spacer();Button("Descartar") {m.discardPending()}.buttonStyle(.borderless)}
            ForEach(m.pendingChanges) {change in HStack {Text(inputName(change.source));Spacer();Text("\(change.current.label) → \(change.prepared.label)").foregroundStyle(muted)}.font(.system(size:11))}
            Button("Aplicar cambios") {m.applyMapping(m.maps)}.buttonStyle(.borderedProminent).disabled(!m.connected || m.busy)
        }.surface()
    }
}
