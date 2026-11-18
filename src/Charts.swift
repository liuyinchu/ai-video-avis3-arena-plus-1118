import Foundation

private func roundTicks(_ c:Canvas,_ left:Double,_ right:Double,_ y:Double) {
    let step=(right-left)/20
    for j in 0..<20 {
        let x=left+(Double(j)+0.5)*step
        c.line(x,y,x,y+6,grid.a(0.75),1)
        c.text(two(j+1),x,y+12,20,muted,mono,.center)
    }
    c.text("共同场景编号",right,y+57,22,quiet,cnm,.right)
}
func pairScene(_ c:Canvas,_ f:Film,_ t:Double){
    sectionTitle(c,"13 号 Astra  /  16 号 Fable","各领先十场，为什么 Astra 排在前面？")
    let d=f.data.paired
    c.text("领先场数",101,340,27,muted,cnm)
    c.text(String(d.astraWins),95,387,98,blue,bold,kern:-5)
    c.text("∶",242,397,76,quiet,cnm)
    c.text(String(d.fableWins),308,387,98,orange,bold,kern:-5)
    c.text("Astra",101,517,30,blue,demi);c.text("Fable",313,517,30,orange,demi)
    c.line(100,597,532,597,grid.a(0.50),1)
    c.text("20 场平均差",101,633,25,muted,cnm)
    c.text("+"+fixed(d.mean,3)+" s",95,675,64,paper,demi,kern:-2)
    c.text("13 号积分减去 16 号积分",101,773,23,muted,cnm)
    let left=650.0,right=1795.0,top=366.0,bottom=750.0, hi=7.6,lo = -3.0
    func y(_ v:Double)->Double {top+(hi-v)/(hi-lo)*(bottom-top)}
    c.text("积分差 / s",left,306,25,muted,cnm)
    c.text("Astra 领先 ↑",right-193,306,24,blue,cnm,.right)
    c.text("Fable 领先 ↓",right,306,24,orange,cnm,.right)
    let zero=y(0)
    c.rect(left,top,right-left,zero-top,blue.a(0.023));c.rect(left,zero,right-left,bottom-zero,orange.a(0.026))
    for v in [-2,0,2,4,6] {
        let yy=y(Double(v))
        c.line(left,yy,right,yy,v==0 ? muted.a(0.79):grid.a(0.38),v==0 ? 2.2:1,v==0 ? []:[3,6])
        c.text(v>0 ? "+"+String(v):String(v),left-19,yy-15,23,muted,mono,.right)
    }
    let step=(right-left)/20
    for (i,v) in d.delta.enumerated() {
        let x=left+(Double(i)+0.5)*step
        let p=ease(t,0.15+Double(i)*0.055,0.78)
        let yy=y(v*p), co=v>0 ? blue:orange
        c.rect(x-step*0.29,min(zero,yy),step*0.58,max(1,abs(zero-yy)),co.a(0.81))
        c.line(x-step*0.29,yy,x+step*0.29,yy,co,3)
    }
    let a=d.delta.firstIndex(of:d.delta.max()!)!, b=d.delta.firstIndex(of:d.delta.min()!)!
    for j in [a,b] {
        let v=d.delta[j],x=left+(Double(j)+0.5)*step,up=v>0,yy=y(v)
        let p=ease(t,1.7,0.5),co=up ? blue:orange
        c.text((up ? "+":"")+fixed(v),x,up ? yy-42:yy+7,23,co.a(p),monob,.center)
    }
    roundTicks(c,left,right,757)
}
func spreadScene(_ c:Canvas,_ f:Film,_ t:Double){
    sectionTitle(c,"17 号 Sol  /  正式逐轮记录","同一份规则，积分从 1.89 s 到 755.54 s",violet)
    let e=f.data.entrant(17)
    c.text("低于 100 s",101,342,28,muted,cnm)
    c.text(String(f.data.spread.below100),94,380,100,violet,bold,kern:-4)
    c.text("场",184,440,34,paper,cnm)
    c.line(101,520,504,520,grid.a(0.4),1)
    c.text("高于 700 s",101,548,28,muted,cnm)
    c.text(String(f.data.spread.above700),94,587,100,violet,bold,kern:-4)
    c.text("场",184,647,34,paper,cnm)
    c.text("中间区间还有 \(20-f.data.spread.above700-f.data.spread.below100) 场",101,765,26,muted,cnm)
    let left=650.0,right=1795.0,top=378.0,bottom=749.0
    func y(_ v:Double)->Double {bottom-v/800*(bottom-top)}
    c.text("单轮原始积分 / s",left,306,25,muted,cnm)
    c.text("20/20 完成    ·    0 规则失败",right,306,24,violet,cnm,.right)
    for v in [0,100,400,700,800]{
        let yy=y(Double(v)),threshold=v==100 || v==700
        c.line(left,yy,right,yy,threshold ? violet.a(0.62):grid.a(0.40),threshold ? 1.7 : 1,threshold ? [7,6]:[])
        c.text(String(v),left-18,yy-14,22,threshold ? violet:muted,mono,.right)
    }
    let step=(right-left)/20
    for (j,v) in e.scores.enumerated() {
        let x=left+(Double(j)+0.5)*step, yy=y(v*ease(t,0.1+0.05*Double(j),0.75))
        let co=violet.a(v>700 ? 1:v<100 ? 0.6:0.78)
        c.rect(x-step*0.28,yy,step*0.56,bottom-yy,co.a(0.74))
        c.line(x-step*0.28,yy,x+step*0.28,yy,co,2.5)
    }
    let jMin=e.scores.firstIndex(of:e.min)!, jMax=e.scores.firstIndex(of:e.max)!
    for idx in [jMin,jMax] {
        let x=left+(Double(idx)+0.5)*step,yy=y(e.scores[idx])
        let p=ease(t,1.7,0.5), off=idx==jMin ? 48.0 : 9.0
        c.line(x,yy-3,x,yy-off,violet.a(p),1.6)
        c.text(fixed(e.scores[idx]),x,yy-off-32,22,paper.a(p),monob,.center)
    }
    roundTicks(c,left,right,757)
}
func spectrumScene(_ c:Canvas,_ f:Film,_ t:Double){
    sectionTitle(c,"第 1 个共同场景  /  输出 y₁","把同一场的振动按频率展开",mint)
    let s=f.spectrum, band=s.band08to12
    c.text("选定频带",101,345,25,muted,cnm)
    c.text("0.8–1.2 Hz",96,382,60,paper,demi,kern:-1)
    c.text("带内 ASD 均方根 / 无控制基线",101,475,25,muted,cnm,maxWidth:455)
    let labels:[(String,String,Ink)]=[("n13","#13  Astra",blue),("n16","#16  Fable",orange),("n17","#17  Sol",violet)]
    for (j,row) in labels.enumerated() {
        let y=544+Double(j)*75
        c.rect(102,y+7,4,31,row.2)
        c.text(row.1,119,y,29,row.2,demi)
        let ratio=band[row.0]![0]/band["baseline"]![0]
        c.text(fixed(ratio,ratio<1 ? 4:2)+"×",542,y,28,paper,monob,.right)
        c.line(103,y+54,541,y+54,grid.a(0.35),1)
    }
    c.text("第 1 场原始积分 / s",102,768,21,muted,cnm)
    let values=[13,16,17].map { n in "#"+two(n)+" "+fixed(f.data.entrant(n).scores[0]) }
    c.text(values.joined(separator:"   "),102,809,22,paper,mono,maxWidth:445)
    let x0=682.0,x1=1795.0,y0=384.0,y1=742.0
    func xx(_ hz:Double)->Double { x0+(log10(hz)+2)/4*(x1-x0) }
    func yy(_ val:Double)->Double { y1-(log10(val)+12)/10*(y1-y0) }
    c.text("位移等效 ASD（m/√Hz）",x0,302,25,muted,cnm)
    let keys=["baseline","n13","n16","n17"], tags=["无控制","#13","#16","#17"], colors=[muted,blue,orange,violet]
    let lx=[1265.0,1425,1561,1697], patterns:[[CGFloat]]=[[7,6],[],[11,5],[]]
    for j in 0..<4{
        c.line(lx[j],327,lx[j]+35,327,colors[j],3,patterns[j])
        c.text(tags[j],lx[j]+45,309,22,colors[j],j==0 ? cnm : mono)
    }
    let hlx=xx(0.8),hlw=xx(1.2)-hlx
    c.rect(hlx,y0,hlw,y1-y0,mint.a(0.15));c.line(hlx,y0,hlx,y1,mint.a(0.64),1);c.line(hlx+hlw,y0,hlx+hlw,y1,mint.a(0.64),1)
    let powers=[(-12,"10⁻¹²"),(-10,"10⁻¹⁰"),(-8,"10⁻⁸"),(-6,"10⁻⁶"),(-4,"10⁻⁴"),(-2,"10⁻²")]
    for (v,l) in powers{
        let y=yy(pow(10,Double(v)))
        c.line(x0,y,x1,y,grid.a(0.40),1,[3,6]);c.text(l,x0-15,y-15,22,muted,sans,.right)
    }
    for (hz,label) in [(0.01,"0.01"),(0.1,"0.1"),(1,"1"),(10,"10"),(100,"100")]{
        let x=xx(hz)
        c.line(x,y0,x,y1,grid.a(0.28),1);c.text(label,x,y1+13,23,muted,mono,.center)
    }
    c.cropped(x0-1,y0-1,(x1-x0+2)*ease(t,0.10,2.2),y1-y0+3) {
        // Keep the line styles distinct where the two leading entries almost coincide.
        for j in [0,3,1,2]{
            let values=s.series[keys[j]]![0]
            let points=s.frequency.indices.map{i in (xx(s.frequency[i]),yy(values[i]))}
            c.path(points,colors[j],j==1 ? 4.5:2.8,dash:patterns[j])
        }
    }
    c.text("曲线按对数频带作功率平均",x0,814,21,quiet,cnm)
    c.text("频率 / Hz（对数轴）",x1,802,23,muted,cnm,.right)
}
