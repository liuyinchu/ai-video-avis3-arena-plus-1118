import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

enum CoverError: Error { case missingArt, render, write }
private let navy = Ink(0x060b18)
private let ivory = Ink(0xf6f2e8)
private let apricot = Ink(0xffbd83)

private func gradient(_ c: Canvas, _ colors: [Ink], _ stops: [CGFloat], from: CGPoint, to: CGPoint) {
    let g=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB)!,colors:colors.map(\.cg) as CFArray,locations:stops)!
    c.ctx.drawLinearGradient(g,start:from,end:to,options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
}

private func artwork(_ c: Canvas) throws {
    let url=URL(fileURLWithPath:"publish/isolator.png")
    guard let input=CIImage(contentsOf:url) else {throw CoverError.missingArt}
    let width=1640.0, scale=width/input.extent.width, height=input.extent.height*scale
    let picture=input.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
        .transformed(by:CGAffineTransform(translationX:310,y:1080-66-height))
        .clampedToExtent().cropped(to:CGRect(x:0,y:0,width:1920,height:1080))
    let ci=CIContext(options:[.workingColorSpace:CGColorSpace(name:CGColorSpace.sRGB)!])
    guard let frame=ci.createCGImage(picture,from:picture.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!) else {throw CoverError.render}
    c.image(frame)
    gradient(c,[navy.a(0.94),navy.a(0)], [0,1], from:CGPoint(x:0,y:0),to:CGPoint(x:0,y:190))
    gradient(c,[navy.a(0.94),navy.a(0.80),navy.a(0)],[0,0.62,1],
             from:CGPoint(x:0,y:0),to:CGPoint(x:1030,y:0))
    let foot=Ink(0x060b14)
    gradient(c,[foot.a(0),foot.a(0.86),foot.a(0.98)],[0,0.59,1],
             from:CGPoint(x:0,y:801),to:CGPoint(x:0,y:1080))
}

private func masthead(_ c: Canvas) {
    for (i,col) in [blue,orange,violet].enumerated() {
        let x=93+Double(i)*13.7
        c.path([(x,111),(x+15,72),(x+23,72),(x+8,111)],col,0,close:true,fill:col)
    }
    c.text("AVIS3",159,56,54,ivory,bold,kern:-1.8)
    c.text("ARENA PLUS",335,77,26,muted,monob,kern:1)
    c.line(529,78,529,107,muted.a(0.52),1.4)
    c.text("三份隔振答卷",555,67,33,ivory,cnm,kern:1)
}

private func comparison(_ c: Canvas,_ d: Results) {
    let x=96.0
    let a=c.text("Astra",x,195,52,blue,demi)
    let cross=c.text("×",x+a+21,197,45,muted,sans)
    c.text("Fable",x+a+cross+42,195,52,orange,demi)
    c.text("各领先十场",87,275,142,ivory,cnb,kern:-6)
    c.text("均分只差",100,486,55,ivory,cnm,kern:1)
    let width=c.text(fixed(d.paired.mean,2),83,529,243,apricot,"AvenirNext-Heavy",kern:-11)
    c.text("秒",101+width,676,78,ivory,cnb)
    c.text("每场领先方",100,815,22,muted,cnm)
    let start=251.0, step=25.5
    for (i,delta) in d.paired.delta.enumerated(){
        let color=delta>0 ? blue:orange
        c.rect(start+Double(i)*step,826,20.8,10,color)
    }
}

private func casts(_ c: Canvas,_ d: Results) {
    c.line(96,880,1824,880,muted.a(0.5),1.4)
    let lefts=[96.0,671.0,1274.0]
    for (i,n) in [13,16,17].enumerated(){
        let e=d.entrant(n),x=lefts[i],co=colorFor(n)
        if i>0 {c.line(x-43,920,x-43,1005,muted.a(0.28),1.2)}
        c.rect(x,924,31,4,co)
        c.text("第 \(e.rank) 名",x+44,906,27,co,cnm)
        c.text(" /  #\(e.number)",x+143,911,23,muted,mono)
        c.text(e.name,x-1,947,49,ivory,demi,kern:-0.65,maxWidth:505)
    }
}

@main struct Cover {
    static func main() throws {
        let results=try JSONDecoder().decode(Results.self,from:Data(contentsOf:URL(fileURLWithPath:"data/results.json")))
        precondition(results.paired.delta.count==20 && results.paired.astraWins==10 && results.paired.fableWins==10)
        let ctx=bitmapContext(),c=Canvas(ctx)
        try artwork(c);masthead(c);comparison(c,results);casts(c,results)
        guard let image=ctx.makeImage() else {throw CoverError.render}
        for (ext,type) in [("png",UTType.png),("jpg",UTType.jpeg)] {
            let url=URL(fileURLWithPath:"out/publish/AVIS3-Plus-1118-cover."+ext)
            guard let dest=CGImageDestinationCreateWithURL(url as CFURL,type.identifier as CFString,1,nil) else {throw CoverError.write}
            let options: CFDictionary? = ext=="jpg" ? [kCGImageDestinationLossyCompressionQuality:0.94] as CFDictionary : nil
            CGImageDestinationAddImage(dest,image,options)
            guard CGImageDestinationFinalize(dest) else {throw CoverError.write}
        }
    }
}
