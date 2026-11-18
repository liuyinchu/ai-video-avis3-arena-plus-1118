import AppKit
import CoreGraphics
import CoreText
import Foundation

let W = 1920, H = 1080
struct Ink {
    let r, g, b, alpha: Double
    init(_ hex: UInt32, _ a: Double = 1) {
        r=Double((hex>>16)&255)/255; g=Double((hex>>8)&255)/255; b=Double(hex&255)/255; alpha=a
    }
    private init(_ r: Double,_ g: Double,_ b: Double,_ alpha: Double) { self.r=r; self.g=g; self.b=b; self.alpha=alpha }
    func a(_ opacity: Double) -> Ink { Ink(r,g,b,alpha*max(0,min(1,opacity))) }
    var cg: CGColor { CGColor(srgbRed:r,green:g,blue:b,alpha:alpha) }
}
let paper=Ink(0xf3f0e8), muted=Ink(0xb2beca), quiet=Ink(0x8293a3), grid=Ink(0x697b8a)
let ground=Ink(0x080c12), surface=Ink(0x101923), deep=Ink(0x0b111a)
let blue=Ink(0x68cfff), orange=Ink(0xff9d68), violet=Ink(0xb79aff), mint=Ink(0x99e4c3)
let sans="AvenirNext-Medium", bold="AvenirNext-Bold", demi="AvenirNext-DemiBold"
let cn="PingFangSC-Regular", cnm="PingFangSC-Medium", cnb="PingFangSC-Semibold"
let mono="Menlo-Regular", monob="Menlo-Bold"
func colorFor(_ n: Int) -> Ink { n==13 ? blue : n==16 ? orange : n==17 ? violet : muted }
typealias XY = (Double,Double)
enum Align { case left, center, right }

private struct LineKey: Hashable { let str, font: String; let size, kern: Double }
private struct Typeset { let line: CTLine; let width, ascent: Double }
private var lines = [LineKey:Typeset]()
private func typeset(_ text: String, _ font: String, _ size: Double, _ tracking: Double) -> Typeset {
    let key = LineKey(str:text,font:font,size:size,kern:tracking)
    if let cached=lines[key] { return cached }
    let ct=CTFontCreateWithName(font as CFString,size,nil)
    let at=NSAttributedString(string:text,attributes:[
        NSAttributedString.Key(kCTFontAttributeName as String):ct,
        NSAttributedString.Key(kCTKernAttributeName as String):tracking,
        NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String):true])
    let line=CTLineCreateWithAttributedString(at)
    let box=Typeset(line:line,width:CTLineGetTypographicBounds(line,nil,nil,nil),ascent:CTFontGetAscent(ct))
    lines[key]=box
    return box
}
func textWidth(_ text: String,_ size: Double,_ face: String=cnm,_ tracking: Double=0) -> Double {
    typeset(text,face,size,tracking).width
}
final class Canvas {
    let ctx: CGContext
    init(_ ctx: CGContext) { self.ctx=ctx }
    @discardableResult func text(_ s: String,_ x: Double,_ y: Double,_ size: Double,_ ink: Ink=paper,
              _ font: String=cnm,_ align: Align = .left, kern: Double=0, maxWidth: Double?=nil) -> Double {
        var b=typeset(s,font,size,kern)
        if let width=maxWidth, b.width>width { b=typeset(s,font,size*width/b.width,kern*width/b.width) }
        let left = align == .center ? x-b.width/2 : align == .right ? x-b.width : x
        ctx.saveGState()
        ctx.setFillColor(ink.cg)
        ctx.translateBy(x:left,y:y+b.ascent)
        ctx.scaleBy(x:1,y:-1)
        ctx.textMatrix = .identity
        ctx.textPosition = .zero
        CTLineDraw(b.line,ctx)
        ctx.restoreGState()
        return b.width
    }
    func rect(_ x: Double,_ y: Double,_ w: Double,_ h: Double,_ ink: Ink) {
        guard w>0 && h>0 else { return }
        ctx.setFillColor(ink.cg);ctx.fill(CGRect(x:x,y:y,width:w,height:h))
    }
    func box(_ x: Double,_ y: Double,_ w: Double,_ h: Double,_ fill: Ink,_ border: Ink?=nil,_ radius: Double=0) {
        let p=CGPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerWidth:radius,cornerHeight:radius,transform:nil)
        ctx.setFillColor(fill.cg);ctx.addPath(p);ctx.fillPath()
        if let b=border {ctx.setStrokeColor(b.cg);ctx.setLineWidth(1.25);ctx.addPath(p);ctx.strokePath()}
    }
    func line(_ x1: Double,_ y1: Double,_ x2: Double,_ y2: Double,_ ink: Ink,_ width: Double=2,_ dash: [CGFloat]=[]) {
        path([(x1,y1),(x2,y2)],ink,width,dash:dash)
    }
    func path(_ points: [XY],_ ink: Ink,_ width: Double=2,dash: [CGFloat]=[], close: Bool=false,fill: Ink?=nil) {
        guard let first=points.first else{return}
        ctx.saveGState()
        ctx.beginPath();ctx.move(to:CGPoint(x:first.0,y:first.1))
        for p in points.dropFirst(){ctx.addLine(to:CGPoint(x:p.0,y:p.1))}
        if close {ctx.closePath()}
        ctx.setLineJoin(.round);ctx.setLineCap(dash.isEmpty ? .round : .butt)
        ctx.setLineWidth(width);ctx.setStrokeColor(ink.cg);ctx.setLineDash(phase:0,lengths:dash)
        if let f=fill { ctx.setFillColor(f.cg);ctx.drawPath(using:width>0 ? .fillStroke : .fill) } else {ctx.strokePath()}
        ctx.restoreGState()
    }
    func circle(_ x: Double,_ y: Double,_ radius: Double,_ fill: Ink,_ outline: Ink?=nil,_ lw: Double=2) {
        let r=CGRect(x:x-radius,y:y-radius,width:radius*2,height:radius*2)
        ctx.setFillColor(fill.cg);ctx.fillEllipse(in:r)
        if let c=outline {ctx.setStrokeColor(c.cg);ctx.setLineWidth(lw);ctx.strokeEllipse(in:r)}
    }
    func arrow(_ x:Double,_ y:Double,_ u:Double,_ v:Double,_ ink:Ink,_ lw:Double=2.4) {
        line(x,y,u,v,ink,lw)
        let angle=atan2(v-y,u-x)
        for d in [-0.52,0.52] {line(u,v,u-11*cos(angle+d),v-11*sin(angle+d),ink,lw)}
    }
    func dotAlong(_ points:[XY],_ progress:Double,_ ink:Ink,_ r:Double=5) {
        guard points.count>1 else{return}
        let lengths=zip(points,points.dropFirst()).map{hypot($1.0-$0.0,$1.1-$0.1)}
        var length=clamp(progress)*lengths.reduce(0,+)
        for i in lengths.indices {
            if length<=lengths[i] || i==lengths.count-1 {
                let f=length/max(0.001,lengths[i])
                let x=points[i].0+(points[i+1].0-points[i].0)*f, y=points[i].1+(points[i+1].1-points[i].1)*f
                circle(x,y,r+4,ink.a(0.16));circle(x,y,r,ink);return
            }
            length-=lengths[i]
        }
    }
    func image(_ img:CGImage,_ x:Double=0,_ y:Double=0,_ w:Double=1920,_ h:Double=1080){
        ctx.saveGState();ctx.translateBy(x:x,y:y+h);ctx.scaleBy(x:1,y:-1)
        ctx.draw(img,in:CGRect(x:0,y:0,width:w,height:h));ctx.restoreGState()
    }
    func cropped(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ work:()->Void) {
        guard w>0 && h>0 else{return};ctx.saveGState()
        ctx.clip(to:CGRect(x:x,y:y,width:w,height:h));work();ctx.restoreGState()
    }
    func stamp(_ text:String,_ x:Double,_ y:Double,_ ink:Ink) {
        let width=textWidth(text,22,cnm,1)+36
        box(x,y,width,40,ink.a(0.08),ink.a(0.35),4)
        self.text(text,x+18,y+4,22,ink,cnm,kern:1)
    }
}
func bitmapContext() -> CGContext {
    let c=CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:W*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,
        bitmapInfo:CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)!
    configure(c);return c
}
func configure(_ c: CGContext) {
    c.translateBy(x:0,y:CGFloat(H));c.scaleBy(x:1,y:-1)
    c.setShouldAntialias(true);c.setShouldSmoothFonts(false)
}
let backdrop: CGImage = {
    let context=bitmapContext(), c=Canvas(context)
    c.rect(0,0,1920,1080,ground)
    let space=CGColorSpace(name:CGColorSpace.sRGB)!
    func glow(_ x:Double,_ y:Double,_ rad:Double,_ col:Ink) {
        let g=CGGradient(colorsSpace:space,colors:[col.cg,col.a(0).cg] as CFArray,locations:[0,1])!
        context.drawRadialGradient(g,startCenter:CGPoint(x:x,y:y),startRadius:0,endCenter:CGPoint(x:x,y:y),endRadius:rad,options:[])
    }
    glow(520,125,1250,Ink(0x182d41,0.53));glow(1700,880,990,Ink(0x382722,0.24))
    for row in 0..<24 {for col in 0..<42 {
        let x=Double(col)*48+23,y=Double(row)*48+18
        let alpha=0.13+0.04*sin(Double(row*97+col*19))
        c.rect(x,y,1.35,1.35,quiet.a(alpha))
    }}
    return context.makeImage()!
}()
func plotGrid(_ c:Canvas,_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ spacing:Double=32) {
    var j=0.0;while j<=w {c.line(x+j,y,x+j,y+h,grid.a(0.10),1);j+=spacing}
    j=0;while j<=h {c.line(x,y+j,x+w,y+j,grid.a(0.10),1);j+=spacing}
}
func phase(_ t:Double,_ period:Double) -> Double { (t/period).truncatingRemainder(dividingBy:1) }
func ribbon(_ c:Canvas,_ x:Double,_ y:Double,_ w:Double,_ amp:Double,_ cycles:Double,_ t:Double,_ color:Ink) {
    let p:[XY]=(0...96).map { i in let z=Double(i)/96;return (x+z*w,y+sin(2*Double.pi*(z*cycles+t))*amp) }
    c.path(p,color,3)
}
