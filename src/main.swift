import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

enum RenderError: Error, CustomStringConvertible {
    case message(String)
    var description:String { switch self {case .message(let str):return str} }
}
func drawFrame(_ context:CGContext,_ film:Film,_ frame:Int) {
    let c=Canvas(context), timing=film.timing(frame:frame)
    let sc=film.edit.scenes[timing.i],t=timing.t
    c.image(backdrop)
    topRail(c,film,timing.i)
    switch sc.id {
    case "open":opening(c,film,t)
    case "rules":ruleDiagram(c,t)
    case "fable":profile(c,film,16,t)
    case "astra":profile(c,film,13,t)
    case "pair":pairScene(c,film,t)
    case "sol":profile(c,film,17,t)
    case "spread":spreadScene(c,film,t)
    case "spectrum":spectrumScene(c,film,t)
    case "board":boardScene(c,film,t)
    default:preconditionFailure("Unknown scene "+sc.id)
    }
    // Only the shot changes at the cut. The series masthead and captions stay anchored.
    let out=smooth(t,timing.length-0.18,timing.length)
    let enter=(timing.i>0 ? 1-smooth(t,0,0.22):0)
    let dim=0.72*max(out,enter)
    if dim>0 {c.rect(0,115,1920,761,ground.a(dim))}
    bottomRail(c,film,frame,timing.i,t)
    let left=Double(film.edit.frames-1-frame)/Double(film.edit.fps)
    if left<0.78 {c.rect(0,0,1920,1080,ground.a(1-smooth(left,0,0.78)))}
}
func writeImage(_ image:CGImage,_ file:String) throws {
    let url=URL(fileURLWithPath:file)
    let isPNG=url.pathExtension.lowercased()=="png"
    guard let dst=CGImageDestinationCreateWithURL(url as CFURL,(isPNG ? UTType.png : UTType.jpeg).identifier as CFString,1,nil) else {
        throw RenderError.message("Cannot create image destination "+file)
    }
    CGImageDestinationAddImage(dst,image,[kCGImageDestinationLossyCompressionQuality:0.92] as CFDictionary)
    guard CGImageDestinationFinalize(dst) else {throw RenderError.message("Cannot finish still "+file)}
}
func movie(_ film:Film,_ url:URL,_ begin:Int,_ end:Int) throws {
    guard begin>=0, end<=film.edit.frames, begin<end else {throw RenderError.message("Invalid frame range")}
    let writer=try AVAssetWriter(outputURL:url,fileType:.mp4)
    let settings:[String:Any]=[
        AVVideoCodecKey:AVVideoCodecType.h264,
        AVVideoWidthKey:W,AVVideoHeightKey:H,
        AVVideoColorPropertiesKey:[AVVideoColorPrimariesKey:AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey:AVVideoTransferFunction_ITU_R_709_2,AVVideoYCbCrMatrixKey:AVVideoYCbCrMatrix_ITU_R_709_2],
        AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000,
            AVVideoMaxKeyFrameIntervalKey:film.edit.fps*2,AVVideoAllowFrameReorderingKey:false,
            AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]]
    let input=AVAssetWriterInput(mediaType:.video,outputSettings:settings)
    input.expectsMediaDataInRealTime=false
    let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[
        kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H,
        kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true,
        kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
    guard writer.canAdd(input) else {throw RenderError.message("Cannot attach H.264 encoder")}
    writer.add(input)
    guard writer.startWriting() else {throw writer.error ?? RenderError.message("Cannot start video encoder")}
    writer.startSession(atSourceTime:.zero)
    guard let pool=adaptor.pixelBufferPool else {throw RenderError.message("Missing video pixel buffer pool")}
    let space=CGColorSpace(name:CGColorSpace.sRGB)!
    let tick=CMTimeScale(film.edit.fps)
    for f in begin..<end {
        while !input.isReadyForMoreMediaData {
            if writer.status != .writing {throw writer.error ?? RenderError.message("Video encoder stopped")}
            Thread.sleep(forTimeInterval:0.002)
        }
        try autoreleasepool {
            var pixel:CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil,pool,&pixel)==kCVReturnSuccess,let buf=pixel else {throw RenderError.message("Cannot allocate pixel buffer")}
            CVPixelBufferLockBaseAddress(buf,[])
            guard let ctx=CGContext(data:CVPixelBufferGetBaseAddress(buf),width:W,height:H,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(buf),space:space,
                bitmapInfo:CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                CVPixelBufferUnlockBaseAddress(buf,[]);throw RenderError.message("Cannot draw pixel buffer")
            }
            configure(ctx);drawFrame(ctx,film,f);ctx.flush()
            CVPixelBufferUnlockBaseAddress(buf,[])
            guard adaptor.append(buf,withPresentationTime:CMTime(value:Int64(f-begin),timescale:tick)) else {throw writer.error ?? RenderError.message("Cannot append video frame")}
        }
        if (f-begin)%300==0 {FileHandle.standardError.write(Data("Rendered \(f-begin)/\(end-begin) frames\n".utf8))}
    }
    writer.endSession(atSourceTime:CMTime(value:Int64(end-begin),timescale:tick))
    input.markAsFinished()
    let done=DispatchSemaphore(value:0)
    writer.finishWriting{done.signal()};done.wait()
    guard writer.status == .completed else {throw writer.error ?? RenderError.message("Video export did not finish")}
}
do {
    let args=Array(CommandLine.arguments.dropFirst()), film=try Film()
    guard let op=args.first else {throw RenderError.message("Use still SECONDS IMAGE or render VIDEO [FIRST_FRAME END_FRAME]")}
    if op=="still",args.count==3,let time=Double(args[1]){
        let ctx=bitmapContext();drawFrame(ctx,film,min(film.edit.frames-1,max(0,Int((time*Double(film.edit.fps)).rounded()))))
        try writeImage(ctx.makeImage()!,args[2])
    } else if op=="render",args.count==2 || args.count==4{
        try movie(film,URL(fileURLWithPath:args[1]),args.count==4 ? Int(args[2])! : 0,args.count==4 ? Int(args[3])! : film.edit.frames)
    } else {throw RenderError.message("Use still SECONDS IMAGE or render VIDEO [FIRST_FRAME END_FRAME]")}
} catch {
    FileHandle.standardError.write(Data(("Render failed: \(error)\n").utf8));exit(1)
}
