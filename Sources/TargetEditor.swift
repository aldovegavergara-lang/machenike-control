import SwiftUI
struct TargetEditor:View {
    @EnvironmentObject var m:Model
    var body:some View {
        VStack(alignment:.leading,spacing:24) {
            VStack(alignment:.leading,spacing:7) {Text("Nuevo destino").font(.system(size:24,weight:.semibold));Text("Una app o una dirección web.").font(.system(size:12)).foregroundStyle(muted)}
            Picker("Tipo",selection:$m.targetType) {Text("Aplicación").tag(0);Text("URL").tag(1)}.pickerStyle(.segmented).onChange(of:m.targetType) {_,_ in m.targetAddress="";m.targetName="";m.targetEditorError=""}
            VStack(alignment:.leading,spacing:8) {Text("Nombre").font(.system(size:11)).foregroundStyle(muted);TextField("Opcional",text:$m.targetName).textFieldStyle(.roundedBorder).controlSize(.large)}
            if m.targetType==0 {
                Button {m.chooseApp()} label:{HStack {Image(systemName:"folder");Text(m.targetAddress.isEmpty ? "Elegir aplicación…":URL(fileURLWithPath:m.targetAddress).deletingPathExtension().lastPathComponent);Spacer();Image(systemName:"chevron.right").font(.system(size:10))}.padding(16).frame(maxWidth:.infinity).background(ink,in:RoundedRectangle(cornerRadius:10))}.buttonStyle(.plain)
            } else {
                VStack(alignment:.leading,spacing:8) {Text("Dirección web").font(.system(size:11)).foregroundStyle(muted);TextField("https://ejemplo.com",text:$m.targetAddress).textFieldStyle(.roundedBorder).controlSize(.large)}
            }
            if !m.targetEditorError.isEmpty {Text(m.targetEditorError).font(.system(size:12)).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true)}
            HStack {Spacer();Button("Cancelar") {m.showTargetEditor=false}.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction);Button("Añadir") {m.saveTarget()}.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)}
        }.padding(30).frame(width:430).background(panel).foregroundStyle(graphite).preferredColorScheme(.light).tint(aqua)
    }
}
