import Foundation

private func panel(_ c:Canvas,_ color:Ink,_ title:String) {
    c.box(827,163,995,666,surface.a(0.77),grid.a(0.35),5)
    c.rect(827,163,125,3,color)
    c.text("选手自述  /  策略示意",864,194,22,color,cnm,kern:1)
    c.text(title,860,239,47,paper,cnb,kern:-1,maxWidth:924)
    c.line(864,320,1785,320,grid.a(0.36),1)
}
private func lowerLine(_ c:Canvas,_ left:String,_ right:String,_ ink:Ink){
    c.line(864,691,1785,691,grid.a(0.36),1)
    c.text(left,866,718,25,ink,cnm)
    c.text(right,866,762,29,paper,cnm,maxWidth:909)
}
func profile(_ c:Canvas,_ f:Film,_ number:Int,_ t:Double) {
    let e=f.data.entrant(number), co=colorFor(number)
    c.box(100,163,121,46,co.a(0.10),co.a(0.50),3)
    c.text("选手 "+two(number),160,168,23,co,cnm,.center)
    c.text(e.platform,244,165,31,paper,demi)
    c.text(e.date.replacingOccurrences(of:"-",with:"."),99,229,22,quiet,mono,kern:1.2)
    c.text(e.name,94,272+(1-ease(t,0,0.6))*10,72,paper,bold,kern:-2,maxWidth:692)
    c.line(100,391,757,391,grid.a(0.55),1)
    c.text("20 轮正式均分",103,419,27,muted,cnm)
    let scoreWidth=c.text(fixed(e.mean),92,451,119,co,demi,kern:-5,maxWidth:545)
    c.text("s",110+scoreWidth,504,48,co,demi)
    c.line(100,610,757,610,grid.a(0.36),1)
    c.text("总榜名次",102,628,23,quiet,cnm)
    c.text("样本标准差",408,628,23,quiet,cnm)
    c.text(two(e.rank)+" / 17",102,664,42,paper,demi)
    c.text(fixed(e.std)+" s",407,664,42,paper,demi)
    c.text("单轮范围",103,752,23,quiet,cnm)
    c.text(fixed(e.min)+" – "+fixed(e.max)+" s",249,748,30,paper,demi)
    c.text("20 / 20 轮完成    ·    0 轮规则失败",103,809,23,muted,cnm)
    switch number {
    case 16: fableMechanism(c,t)
    case 13: astraMechanism(c,t)
    default: solMechanism(c,t)
    }
}
private func fableMechanism(_ c:Canvas,_ t:Double){
    panel(c,orange,"小幅修正执行器的相对增益")
    c.text("速度观测",887,365,25,paper,cnm)
    c.text("实际限幅动作",887,500,25,paper,cnm)
    plotGrid(c,887,410,212,66,22);plotGrid(c,887,545,212,66,22)
    for i in 0...1 {ribbon(c,891,440+Double(i)*5,201,10-Double(i)*4,1.8+Double(i),t*0.15+Double(i)*0.17,orange.a(i==0 ? 0.90 : 0.39))}
    let act:[XY]=(0...85).map{i in
        let x=Double(i)/85
        let v=max(-0.66,min(0.66,1.5*sin((x*2.15+t*0.12)*2*Double.pi)))
        return (891+x*201,579-v*20)
    }
    c.path(act,orange,3)
    let top:[XY]=[(1105,442),(1145,442),(1182,502),(1204,502)],bot:[XY]=[(1105,578),(1145,578),(1182,515),(1204,515)]
    c.path(top,grid,2);c.path(bot,grid,2)
    c.dotAlong(top,phase(t,2.4),orange,3);c.dotAlong(bot,phase(t+1,2.4),orange,3)
    c.box(1206,418,198,177,orange.a(0.055),orange.a(0.45),4)
    for j in 0..<11{
        let h=15+42*abs(sin(Double(j)*1.55+0.5))*ease(t,0.1+Double(j)*0.02,0.7)
        c.rect(1227+Double(j)*14,503-h,6,h,orange.a(0.49+Double(j%3)*0.16))
    }
    c.text("频域投影",1305,535,27,paper,cnm,.center)
    c.arrow(1413,506,1483,506,orange,2.5)
    c.text("修正限幅",1636,385,24,muted,cnm,.center)
    c.text("±2%",1633,425,73,orange,bold,.center,kern:-3)
    c.line(1514,548,1760,548,orange.a(0.68),3)
    for j in 0...8 {let x=1514+Double(j)*30.75, h=j%4==0 ? 14.0:7.0;c.line(x,548-h,x,548+h,orange.a(0.77),2)}
    c.text("−2%",1512,573,21,muted,mono)
    c.text("+2%",1762,573,21,muted,mono,.right)
    c.text("平滑应用",1637,622,25,paper,cnm,.center)
    lowerLine(c,"182 态控制器","启动时标定，运行中保留实际动作反馈与安全回退。",orange)
}
private func astraMechanism(_ c:Canvas,_ t:Double){
    panel(c,blue,"从三音探测到限幅分配")
    c.text("三音探测",885,350,25,blue,cnm)
    for j in 0..<3 {
        let y=423+Double(j)*68
        c.line(885,y,1131,y,grid.a(0.35),1)
        let col=blue.a(0.59+Double(j)*0.18)
        ribbon(c,893,y,225,16,1.4+Double(j)*1.4,t*0.22,col)
        c.circle(1134,y,3,col)
    }
    let paths:[([XY], Double)] = [([(1142,423),(1160,423),(1191,480)],0), ([(1142,491),(1191,491)],0.5), ([(1142,559),(1160,559),(1191,502)],1)]
    for (points,offset) in paths {c.path(points,grid,2);c.dotAlong(points,phase(t+offset,1.8),blue,3)}
    c.box(1197,418,250,150,blue.a(0.06),blue.a(0.4),4)
    c.text("扣除",1322,436,36,paper,cnb,.center)
    c.text("名义模型响应",1322,502,25,muted,cnm,.center)
    c.arrow(1455,493,1516,493,blue,2.4)
    c.box(1526,418,234,150,blue.a(0.095),blue.a(0.52),4)
    c.text("在线辨识",1643,441,32,paper,cnb,.center)
    c.text("执行器增益",1643,503,25,muted,cnm,.center)
    c.text("同步使用限幅后实际施加的力",1480,606,24,muted,cnm,.center)
    c.line(864,691,1785,691,grid.a(0.36),1)
    let words=["多尺度预测","低频补偿","限幅下分配控制力"], xs=[867.0,1160,1446]
    for i in 0..<3{
        c.rect(xs[i],729,36+Double(i)*24,3,blue.a(0.75))
        c.text(words[i],xs[i],755,27,paper,cnm)
        if i<2{c.arrow(xs[i]+189,774,xs[i]+254,774,grid,2)}
    }
}
private func solMechanism(_ c:Canvas,_ t:Double){
    panel(c,violet,"先并行预演，再短时试用")
    c.text("观测创新",887,362,26,violet,cnm)
    c.text("当前观测 − 名义预测",887,402,23,muted,cnm)
    plotGrid(c,888,467,208,101,25)
    ribbon(c,891,520,203,16,2.5,t*0.17,violet)
    c.line(1101,520,1148,520,grid,2)
    for (j,lab) in ["候选滤波器 A","候选滤波器 B","其余候选"].enumerated(){
        let y=399+Double(j)*93
        let p:[XY]=[(1148,520),(1179,520),(1210,y+32),(1230,y+32)]
        c.path(p,grid.a(0.8),2);c.dotAlong(p,phase(t+Double(j)*0.5,2.5),violet,3)
        c.box(1230,y,209,65,violet.a(0.066),violet.a(0.42),4)
        c.text(lab,1335,y+14,24,paper,cnm,.center)
        c.path([(1440,y+32),(1464,y+32),(1491,520)],grid.a(0.8),2)
    }
    c.line(1491,520,1510,520,violet,2)
    c.line(1510,443,1510,604,grid.a(0.72),1.7)
    for j in 0..<3 {let y=443+Double(j)*81;c.arrow(1510,y,1532,y,violet.a(0.82),1.8)}
    c.text("三档反馈",1652,361,26,violet,cnm,.center)
    for j in 0..<3 {
        let y=413+Double(j)*81, x=1537.0
        c.box(x,y,229,59,violet.a(0.065),violet.a(0.35),3)
        for k in 0...j{c.rect(x+19+Double(k)*12,y+29-Double(k)*5,6,11+Double(k)*5,violet)}
        c.text("档位 "+String(j+1),x+139,y+10,25,paper,cnm,.center)
    }
    let route:[XY]=[(1768,602),(1780,602),(1780,666),(1531,666),(1531,611)]
    c.path(route,violet.a(0.57),1.8,dash:[6,5]);c.arrow(1531,636,1531,608,violet.a(0.8),2)
    lowerLine(c,"短时试用与回退","用同一段创新比较预测速度和限幅情况，再选择反馈档位。",violet)
}
