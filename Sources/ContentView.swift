import SwiftUI
import AppKit
import ServiceManagement

struct ContentView:View {
    @EnvironmentObject var m:Model
    @State var section=0
    var body:some View {
        HStack(spacing:0) {
            sidebar
            Rectangle().fill(hairline).frame(width:1)
            VStack(alignment:.leading,spacing:26) {
                header
                if section==0 {KeyboardPage()}
                else {ScrollView {VStack(alignment:.leading,spacing:20) {
                    if section==1 {lightingPage}
                    else if section==2 {profilesPage}
                    else {connectionPage}
                }.padding(.bottom,4)}.scrollIndicators(.hidden)}
                if m.isError {
                    HStack(spacing:8) {Image(systemName:"exclamationmark.circle").foregroundStyle(.orange);Text(m.message).lineLimit(2);Spacer();Button {m.isError=false} label:{Image(systemName:"xmark")}.buttonStyle(.plain)}.font(.system(size:11)).foregroundStyle(muted).padding(12).background(Color.orange.opacity(0.06),in:RoundedRectangle(cornerRadius:9)).help(m.message)
                }
            }.padding(30).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        }.background(ink).foregroundStyle(graphite).tint(aqua)
        .sheet(isPresented:$m.showTargetEditor,onDismiss:{m.presentRequestedAppPicker()}) {TargetEditor().environmentObject(m)}
    }
    var sidebar:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:9) {Image(systemName:"keyboard").font(.system(size:18,weight:.medium));Text("Machenike").font(.system(size:16,weight:.semibold))}.padding(.top,12)
            Text("K500 · B61").font(.system(size:11)).foregroundStyle(muted).padding(.top,6).padding(.leading,29)
            Spacer().frame(height:40)
            nav("Teclado","keyboard",0)
            nav("Iluminación","sun.max",1)
            nav("Perfiles","square.stack",2)
            Spacer()
            nav("Ajustes","slider.horizontal.3",3)
            HStack(spacing:7) {Circle().fill(m.connected ? Color.green:Color.orange).frame(width:5,height:5);Text(m.connected ? "Conectado":"Desconectado").font(.system(size:10)).foregroundStyle(muted)}.padding(.leading,12).padding(.top,16)
        }.padding(20).frame(width:184).frame(maxHeight:.infinity).background(Color.white.opacity(0.5))
    }
    var header:some View {
        HStack(alignment:.center) {
            VStack(alignment:.leading,spacing:6) {
                Text(["Teclado","Iluminación","Perfiles","Ajustes"][section]).font(.system(size:27,weight:.semibold))
                Text(["Tu distribución, a tu manera.","Un color para tu espacio.","Guarda tus configuraciones.","Conexión y preferencias."][section]).font(.system(size:12)).foregroundStyle(muted)
            }
            Spacer()
            if m.busy {ProgressView().controlSize(.small)}
            Button {m.refresh();if section==0 {m.readOnboardKeys()}} label:{Image(systemName:"arrow.clockwise").font(.system(size:13)).foregroundStyle(muted).frame(width:32,height:32).background(Color.white,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain).help("Actualizar")
        }
    }
    func nav(_ title:String,_ icon:String,_ value:Int)->some View {
        Button {section=value} label:{HStack(spacing:11) {Image(systemName:icon).font(.system(size:13)).frame(width:18);Text(title).font(.system(size:12,weight:section==value ? .semibold:.regular)).lineLimit(1);Spacer(minLength:0)}.foregroundStyle(section==value ? aqua:muted).padding(.horizontal,12).padding(.vertical,11).background(section==value ? aqua.opacity(0.075):Color.clear,in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain).padding(.bottom,4)
    }
    var lightingPage:some View {
        VStack(alignment:.leading,spacing:20) {
            KeyboardDiagram(layer:.constant(0),interactive:false,rgbPreview:true)
            VStack(alignment:.leading,spacing:24) {
                HStack(alignment:.top,spacing:34) {
                    VStack(alignment:.leading,spacing:18) {
                        Text("Color").font(.system(size:14,weight:.semibold))
                        Picker("Modo",selection:$m.light.mode) {Text("Fijo").tag(0);Text("Multicolor").tag(7)}.pickerStyle(.segmented)
                        ColorPicker("Personalizado",selection:Binding(get:{m.color},set:{m.color=$0}),supportsOpacity:false).font(.system(size:12)).disabled(m.light.mode != 0)
                        HStack(spacing:12) {ForEach(0..<6,id:\.self) {i in
                            let colors:[Color]=[aqua,.cyan,.mint,.purple,.pink,.orange]
                            Button {m.color=colors[i]} label:{Circle().fill(colors[i]).frame(width:22,height:22).overlay(Circle().stroke(.white,lineWidth:2))}.buttonStyle(.plain).disabled(m.light.mode != 0)
                        }}
                    }.frame(maxWidth:.infinity)
                    Rectangle().fill(hairline).frame(width:1,height:140)
                    VStack(alignment:.leading,spacing:18) {
                        HStack {Text("Brillo").font(.system(size:14,weight:.semibold));Spacer();Text("\(m.light.brightness * 25)%").font(.system(size:12)).foregroundStyle(muted)}
                        Slider(value:Binding(get:{Double(m.light.brightness)},set:{m.light.brightness=Int($0)}),in:0...4,step:1)
                        Text(m.rgbChecked ? "Listo para aplicar":"Lee el teclado para activar los controles.").font(.system(size:11)).foregroundStyle(muted)
                        HStack {Button("Leer teclado") {m.inspectRGB()}.buttonStyle(QuietButton()).disabled(!m.connected || m.busy);Button("Aplicar") {m.applyRGB()}.buttonStyle(.borderedProminent).disabled(!m.connected || !m.rgbChecked || m.busy)}
                    }.frame(maxWidth:.infinity)
                }
                Divider().opacity(0.5)
                HStack {Text("Color fijo y multicolor").font(.system(size:11)).foregroundStyle(muted);Spacer();Button("Deshacer último cambio") {m.restoreRGB()}.font(.system(size:11)).buttonStyle(.borderless).disabled(!m.connected || m.busy)}
            }.surface()
        }
    }
    var profilesPage:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:16) {TextField("Nombre del perfil",text:$m.profileName).textFieldStyle(.roundedBorder).controlSize(.large);Button("Guardar perfil") {m.saveProfile()}.buttonStyle(.borderedProminent)}.surface()
            if m.profiles.isEmpty {
                VStack(spacing:12) {Image(systemName:"square.stack").font(.system(size:30)).foregroundStyle(muted.opacity(0.5));Text("Tu primer perfil").font(.system(size:18,weight:.semibold));Text("Guarda tu distribución y tus colores para volver a ellos.").font(.system(size:12)).foregroundStyle(muted)}.frame(maxWidth:.infinity).padding(.vertical,70)
            }
            ForEach(m.profiles) {p in HStack(spacing:15) {
                Image(systemName:"keyboard").foregroundStyle(muted).frame(width:40,height:40).background(ink,in:RoundedRectangle(cornerRadius:10))
                VStack(alignment:.leading,spacing:5) {Text(p.name).font(.system(size:14,weight:.medium));Text("\(p.maps.count) funciones · \(p.shortcuts.count) accesos").font(.system(size:11)).foregroundStyle(muted)}
                Spacer();Button("Cargar") {m.load(p)}.buttonStyle(QuietButton());Button {m.remove(p)} label:{Image(systemName:"trash").font(.system(size:12))}.buttonStyle(.plain).foregroundStyle(muted)
            }.surface(20)}
            Text("Carga un perfil y aplica los cambios desde Teclado o Iluminación.").font(.system(size:11)).foregroundStyle(muted)
        }
    }
    var connectionPage:some View {
        VStack(alignment:.leading,spacing:20) {
            VStack(alignment:.leading,spacing:18) {
                HStack {Text("Conexión").font(.system(size:14,weight:.semibold));Spacer();Label(m.connected ? "Conectado":"Desconectado",systemImage:"circle.fill").font(.system(size:10)).foregroundStyle(m.connected ? Color.green:Color.orange)}
                Text(m.usbSummary).font(.system(size:12)).foregroundStyle(muted).textSelection(.enabled)
                HStack {Button("Actualizar") {m.refresh()}.buttonStyle(QuietButton());Button("Comprobar RGB") {m.inspectRGB()}.buttonStyle(QuietButton()).disabled(m.busy || !m.connected)}
            }.surface()
            VStack(alignment:.leading,spacing:18) {
                Text("Preferencias").font(.system(size:14,weight:.semibold))
                Toggle("Abrir al iniciar sesión",isOn:Binding(get:{SMAppService.mainApp.status == .enabled},set:{enabled in do {if enabled {try SMAppService.mainApp.register()}else{try SMAppService.mainApp.unregister()};m.success(enabled ? "Inicio automático activado.":"Inicio automático desactivado.")}catch{m.report(error)}})).font(.system(size:12))
                Text("Al cerrar esta ventana, la app sigue activa en la barra superior.").font(.system(size:11)).foregroundStyle(muted)
            }.surface()
            VStack(alignment:.leading,spacing:16) {
                Text("Acceso al teclado").font(.system(size:14,weight:.semibold))
                Text("Para editar Fn y RGB, activa Machenike Control en Monitoreo de entrada y vuelve a abrir la app.").font(.system(size:12)).foregroundStyle(muted)
                Button("Abrir permisos de macOS") {m.requestPermission()}.buttonStyle(QuietButton())
                DisclosureGroup("Estado de acceso") {Text(m.fnStatus+"\n"+m.rgbStatus).font(.system(size:11)).foregroundStyle(muted).textSelection(.enabled).padding(.top,8)}.font(.system(size:11)).foregroundStyle(muted)
            }.surface()
            HStack {Image(systemName:"folder").foregroundStyle(muted);Text("Perfiles y respaldos").font(.system(size:12));Spacer();Button("Abrir carpeta") {NSWorkspace.shared.open(m.folder)}.buttonStyle(QuietButton())}.surface(18)
        }
    }
}
