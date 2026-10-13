import SwiftUI

let ink=Color(red:0.965,green:0.966,blue:0.973)
let panel=Color.white
let aqua=Color(red:0.22,green:0.36,blue:0.92)
let graphite=Color(red:0.13,green:0.14,blue:0.18)
let muted=Color(red:0.49,green:0.51,blue:0.56)
let hairline=Color.black.opacity(0.065)

struct Surface:ViewModifier {
    var padding:CGFloat=22
    func body(content:Content)->some View {
        content.padding(padding).background(panel,in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(hairline,lineWidth:1))
    }
}
extension View {
    func surface(_ padding:CGFloat=22)->some View {modifier(Surface(padding:padding))}
}
struct QuietButton:ButtonStyle {
    func makeBody(configuration:ButtonStyleConfiguration)->some View {
        configuration.label.font(.system(size:12,weight:.medium)).foregroundStyle(graphite)
            .padding(.horizontal,12).padding(.vertical,8)
            .background(Color.black.opacity(configuration.isPressed ? 0.08:0.035),in:RoundedRectangle(cornerRadius:8))
    }
}
