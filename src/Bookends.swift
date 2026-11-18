import Foundation

func topRail(_ c:Canvas,_ film:Film,_ i:Int) {
    for (k,col) in [blue,orange,violet].enumerated() {
        let x=98+Double(k)*11
        c.path([(x,82),(x+12,52),(x+18,52),(x+6,82)],col,0,close:true,fill:col)
    }
    c.text("AVIS3",152,40,42,paper,bold,kern:-1.8)
    c.text("ARENA PLUS",288,57,21,muted,monob,kern:1.6)
    c.line(471,57,471,79,grid.a(0.55),1)
    c.text("Evaluation-1108",498,54,23,muted,mono)
    c.text("增补测评",1457,52,22,muted,cnm)
    c.line(1570,58,1570,79,grid.a(0.55),1)
    c.text("2026.11.18",1820,54,23,paper,mono,.right,kern:1)
    c.line(98,112,1822,112,grid.a(0.50),1)
}
func bottomRail(_ c:Canvas,_ film:Film,_ frame:Int,_ i:Int,_ t:Double){
    let sc=film.edit.scenes[i]
    let cue=sc.cues.last { $0.at<=t && t<($0.until ?? Double.infinity) }
    c.line(98,881,1822,881,grid.a(0.44),1)
    if let q=cue {
        let ink=q.kind=="自述" ? violet : q.kind=="赛制" ? mint : blue
        c.stamp(q.kind,100,915,ink)
        let p=ease(t,q.at,0.16), x=223.0, w=1590.0, size=37.0
        if textWidth(q.text,size,cnm)<=w*1.13 {
            c.text(q.text,x,903+(1-p)*4,size,paper.a(p),cnm,maxWidth:w)
        } else {
            let chars=Array(q.text)
            let preferred=chars.indices.filter{ "，。、；".contains(chars[$0]) && $0>chars.count/4 && $0<3*chars.count/4 }
            let cut=(preferred.min{abs($0-chars.count/2)<abs($1-chars.count/2)} ?? chars.count/2)+1
            c.text(String(chars[..<cut]),x,892,34,paper.a(p),cnm,maxWidth:w)
            c.text(String(chars[cut...]),x,940,34,paper.a(p),cnm,maxWidth:w)
        }
    }
    let start=98.0,width=1724.0, bar=film.edit.barDuration
    for j in film.edit.scenes.indices {
        let a=Double(film.edit.scenes[j].bar)/Double(film.edit.endBar)
        let end=j+1<film.edit.scenes.count ? film.edit.scenes[j+1].bar : film.edit.endBar
        let b=Double(end)/Double(film.edit.endBar), x=start+width*a, w=width*(b-a)-5
        c.rect(x,1001,w,2,grid.a(0.36))
        let fill=clamp((Double(frame)/Double(film.edit.fps)-Double(film.edit.scenes[j].bar)*bar)/(Double(end-film.edit.scenes[j].bar)*bar))
        c.rect(x,1001,w*fill,2,j==i ? orange : muted.a(0.9))
    }
    c.text(two(i+1)+" / "+two(film.edit.scenes.count),98,1018,18,quiet,mono,kern:0.8)
    c.text(sc.title,228,1014,20,muted,cn)
    let secs=frame/film.edit.fps
    c.text(String(format:"%02d:%02d",secs/60,secs%60),1822,1017,20,quiet,mono,.right)
}
func sectionTitle(_ c:Canvas,_ label:String,_ title:String,_ accent:Ink=orange) {
    c.text(label,99,142,23,accent,cnm,kern:1.4)
    c.text(title,95,185,66,paper,cnb,kern:-2,maxWidth:1660)
}
func opening(_ c:Canvas,_ f:Film,_ t:Double){
    c.text("正式测评增补",99,164,28,orange,cnm,kern:3)
    let p=ease(t,-0.15,0.9)
    c.text("三份",89+(1-p)*14,216,117,paper,cnb,kern:-5)
    c.text("隔振答卷",88,349+(1-p)*18,129,paper,cnb,kern:-6)
    c.text("沿用原批次的 20 个场景",103,540,35,muted,cnm,maxWidth:719)
    c.line(103,644,763,644,grid.a(0.5),1)
    c.text("独立参赛条目",105,675,23,quiet,cnm)
    c.text("14",103,709,67,muted,demi)
    c.arrow(221,758,298,758,orange,3.5)
    c.text("17",334,706,71,paper,bold)
    c.text("11.17  /  11.18",763,744,22,quiet,mono,.right)
    let x=834.0, w=987.0
    c.text("三位新选手的逐场积分",x,156,29,paper,cnm)
    c.text("20 场  /  同一纵轴 0–866.3 s",x+w,163,20,muted,cn,.right)
    for (j,n) in [16,13,17].enumerated(){
        let e=f.data.entrant(n), co=colorFor(n), y=226+Double(j)*190
        let reveal=ease(t,0.07+Double(j)*0.15,1.2)
        c.box(x,y,w,166,surface.a(0.82),grid.a(0.24),4)
        c.rect(x,y,5,166,co)
        c.text("#"+two(n),x+26,y+23,30,co,monob)
        c.text(e.name,x+27,y+70,36,paper,demi,maxWidth:344)
        let xx=x+408, yy=y+32, ww=535.0, hh=103.0
        c.line(xx,yy,xx+ww,yy,grid.a(0.25),1,[3,7]);c.line(xx,yy+hh,xx+ww,yy+hh,grid.a(0.46),1)
        let pts=e.scores.enumerated().map{ (xx+Double($0.offset)*ww/19,yy+hh-hh*$0.element/866.2936695331011) }
        c.cropped(xx-5,yy-7,(ww+12)*reveal,hh+18){
            c.path(pts+[(xx+ww,yy+hh),(xx,yy+hh)],co,0,close:true,fill:co.a(0.09))
            c.path(pts,co,3.5)
            for pt in pts {c.circle(pt.0,pt.1,3.3,co)}
        }
    }
}
func ruleDiagram(_ c:Canvas,_ t:Double){
    sectionTitle(c,"比赛规则","同一组场景，怎样排位？")
    let centers=[273.0,722.0,1172.0,1622.0], y=450.0
    let labels=["受扰系统","带噪速度观测","提交的控制器","三路实际施力"]
    for (i,x) in centers.enumerated(){
        let col = i==2 ? orange : i==1 ? blue : muted
        c.box(x-159,335,318,206,surface.a(0.9),col.a(0.38),5)
        c.text(labels[i],x,476,30,paper,cnm,.center)
        switch i {
        case 0:
            for j in (0...2).reversed() {
                let yy=381+Double(j)*13
                c.path([(x-77,yy+15),(x-14,yy-17),(x+79,yy+7),(x+16,yy+40)],muted.a(0.85-Double(j)*0.2),2.4,close:true,fill:surface)
            }
        case 1:
            [(-16.0,1.7),(0.0,2.6),(16.0,3.5)].forEach { z in
                ribbon(c,x-90,402+z.0,180,7,z.1,t*0.22,blue.a(0.82))
            }
        case 2:
            for j in 0..<4 {
                let a=x-54+Double(j)*36
                c.line(a,368,a,357,orange.a(0.8),2);c.line(a,437,a,448,orange.a(0.8),2)
            }
            c.box(x-81,370,162,67,orange.a(0.07),orange.a(0.75),3)
            c.path([(x-54,412),(x-27,412),(x-27,390),(x+3,390),(x+3,413),(x+36,413),(x+36,396),(x+55,396)],orange,3)
        default:
            for j in 0..<3 {
                let a=x+Double(j-1)*43
                c.arrow(a,436,a,371+Double(j%2)*14,muted,3.5)
            }
        }
        if i<3 {
            let route:[XY]=[(x+163,y),(centers[i+1]-165,y)]
            c.arrow(route[0].0,y,route[1].0,y,grid,2)
            c.dotAlong(route,phase(t+Double(i)*0.3,1.8),orange,3.7)
        }
    }
    let back:[XY]=[(centers[3],543),(centers[3],598),(centers[0],598),(centers[0],550)]
    c.path(back,grid.a(0.65),2);c.arrow(centers[0],579,centers[0],548,grid,2)
    c.dotAlong(back,phase(t,3.75),mint,4)
    c.box(738,574,427,48,ground)
    c.text("施力改变下一拍的系统响应",951,578,23,muted,cnm,.center)
    let cells:[(String,String)]=[("20","共同场景"),("1,000 s","每轮时长"),("10 kHz","控制更新频率"),("±0.5 N","每路施力上限")]
    for (i,v) in cells.enumerated(){
        let x=115+Double(i)*445
        if i>0 {c.line(x-25,681,x-25,813,grid.a(0.35),1)}
        c.text(v.0,x,675,58,paper,demi);c.text(v.1,x+3,765,26,muted,cnm)
    }
}
func boardScene(_ c:Canvas,_ f:Film,_ t:Double){
    sectionTitle(c,"正式排名  /  2026.11.18","17 席总榜")
    c.text("\(f.data.totalRounds) 轮全部完成",1819,150,34,paper,cnm,.right)
    c.text("\(f.data.totalFailures) 轮规则失败",1819,208,26,mint,cnm,.right)
    let m=99.0,w=836.0, rowH=54.3
    for k in 0..<2 {
        let x=m+Double(k)*888
        c.text("排名",x+10,295,20,quiet,cnm)
        c.text("编号",x+91,295,20,quiet,cnm)
        c.text("独立参赛条目",x+196,295,20,quiet,cnm)
        c.text("正式均分 / s",x+w-16,295,20,quiet,cnm,.right)
        c.line(x,333,x+w,333,grid.a(0.56),1.2)
    }
    for e in f.data.standings {
        let j=e.rank-1, col=j<9 ? 0:1, row=j<9 ? j:j-9
        let x=m+Double(col)*888,y=342+Double(row)*rowH
        let highlight=[13,16,17].contains(e.number), tone=highlight ? colorFor(e.number):paper
        let p=ease(t,Double(row)*0.06,0.55)
        if highlight { c.box(x,y,w,49,tone.a(0.09));c.rect(x,y,4,49,tone.a(p)) }
        c.text(two(e.rank),x+12,y+1,30,tone.a(p),highlight ? monob:mono)
        c.text("#"+two(e.number),x+91,y+5,24,(highlight ? tone : quiet).a(p),mono)
        let label=e.name.replacingOccurrences(of:"（另一个独立参赛）",with:"")
        c.text(label,x+196,y+2,30,paper.a(p),highlight ? demi:sans,maxWidth:441)
        c.text(fixed(e.mean),x+w-16,y+2,30,tone.a(p),highlight ? monob:mono,.right)
        c.line(x,y+51,x+w,y+51,grid.a(0.19),1)
    }
    c.text("数据源   Evaluation-1108 正式扩展记录   /   a64741a  ·  1e359f2",100,838,21,quiet,cnm)
    if let credit=f.edit.voiceCredit {c.text(credit,1265,838,21,quiet,cnm,.center)}
    c.text("排名采用完整精度均分",1821,838,21,muted,cnm,.right)
}
