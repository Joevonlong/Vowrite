/* Vowrite Voice Atlas — original 80 Open Design drawings, adapted for real input level. Canvas coordinates: 360 × 200. */
(()=>{'use strict';
const tau=Math.PI*2,colors=['#b3c8ff','#a1e5e5','#f3a9c6','#e7dc94','#f5f8ff'];
function draw(canvas,id,time,mode='listening',theme='dark',stateAge=0,level=.65,intensity=1,customColor=''){
 const light=theme==='light',palette=light?['#284fa3','#17636a','#963756','#71600d','#233449']:colors,surface=light?'#fafbfd':'#20252d';
 const tone=v=>light?({'#14171d':'#fafbfd','#edf3ff':'#233449','#f7ffff':'#284fa3','#e4f5ff':'#17636a','#e7f9ff':'#233449','#a1e5e5':'#17636a','#b3c8ff':'#284fa3','#56657a':'#61738c','#26323f':'#9ba8ba','#34414f':'#788ba3','#3c475a':'#788ba3','#222d39':'#c8d3e1','#304451':'#768ca1','#222b38':'#d1dbe7','#485267':'#61738c','#1c2531':'#e2e9f2','#5b718b':'#526b8e','#303c50':'#c8d3e1','#d5e2f4':'#557698','#c5d5e7':'#7899bb'}[v]||v):v;
 const c=canvas.getContext('2d');if(!c)return;const w=canvas.width,h=canvas.height;c.clearRect(0,0,w,h);c.save();c.translate(w/2,h/2);const scale=Math.min(w/(canvas.dataset.shape==='compact'?210:300),h/(canvas.dataset.shape==='compact'?160:130));c.scale(scale,scale);
 const input=Math.max(0,Math.min(1,Number(level)||0))*Math.max(0,Math.min(2,Number(intensity)||0));
 let t=time,a=(mode==='listening'?.16+.84*input:mode==='processing'?.55:mode==='done'?.2:.25);if(mode==='processing')t*=1.6;const col=customColor||palette[(id-1)%5],white=light?'#233449':'#edf3ff',muted=light?'#61738c':'#56657a';
 const line=(pts,color=col,width=1.5,close=false)=>{c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));if(close)c.closePath();c.strokeStyle=color;c.lineWidth=width;c.lineCap='round';c.lineJoin='round';c.stroke()};
 const circle=(x,y,r,color=col,fill=true,width=1)=>{c.beginPath();c.arc(x,y,Math.max(.1,r),0,tau);c.fillStyle=color;c.strokeStyle=color;c.lineWidth=width;fill?c.fill():c.stroke()};
 const ellipse=(x,y,rx,ry,rot=0,color=col,width=1)=>{c.beginPath();c.ellipse(x,y,Math.max(.1,rx),Math.max(.1,ry),rot,0,tau);c.strokeStyle=color;c.lineWidth=width;c.stroke()};
 const rect=(x,y,w,h,r=0,color=col)=>{c.beginPath();if(c.roundRect)c.roundRect(x,y,w,h,r);else c.rect(x,y,w,h);c.fillStyle=color;c.fill()};
 const glow=(n,color=col)=>{c.shadowColor=color;c.shadowBlur=n};
 const pathWave=(offset,amp,freq=1,color=col,width=1.5)=>{let p=[];for(let x=-116;x<=116;x+=2){const taper=Math.pow(Math.cos(x/240*Math.PI),2);p.push([x,Math.sin(x/29*freq+t*2+offset)*amp*taper])}line(p,color,width)};
 switch(id){
 case 1: // 游丝 — asymmetric filament bundle
  for(let j=0;j<6;j++){c.globalAlpha=.2+j*.13;glow(j===4?8:0);pathWave(j*.68,(14+j*5)*a,1+j*.055,j===4?white:col,j===4?1.7:.8)}break;
 case 2: // 弦月 — three open bow strings
  for(let j=0;j<3;j++){c.save();c.rotate(-.22+j*.1);c.beginPath();c.moveTo(-87,20);c.quadraticCurveTo(0,-75+(Math.sin(t*2+j)*13*a)+j*17,87,20);c.strokeStyle=j===1?white:col;c.globalAlpha=1-j*.22;c.lineWidth=1.8;c.stroke();c.restore()}circle(-86,20,2,col);circle(86,20,2,col);break;
 case 3: // 心电 — travelling localized heartbeat
  {let pts=[];let head=((t*55)%260)-130;for(let x=-130;x<=130;x+=2){let d=x-head;const y=Math.exp(-d*d/600)*Math.sin(d*.19)*38*a;pts.push([x,y])}glow(8);line(pts,col,2);circle(head,0,3,white);glow(0);line([[-130,38],[130,38]],tone('#26323f'),.7)}break;
 case 4: // 丝结 — Lissajous silk knot
  for(let j=0;j<3;j++){let pts=[];for(let i=0;i<=180;i++){let q=i/180*tau;pts.push([Math.sin(q*2+t*.3+j*.22)*82,Math.sin(q*3-t*.45+j*.3)*(24+6*a)])}c.globalAlpha=.85-j*.24;line(pts,j===0?col:white,1.2)}break;
 case 5: // 山脊 — moving contour topography
  for(let j=0;j<7;j++){let pts=[];for(let x=-104;x<=104;x+=3){let peak=Math.exp(-x*x/2700);pts.push([x,28+j*4-peak*(47+Math.sin(t*1.4+x/22+j*.4)*12*a)-j*6])}c.globalAlpha=.25+j*.11;line(pts,j===6?white:col,1)}break;
 case 6: // 星尘 — deterministic orbital dust cloud
  for(let i=0;i<105;i++){let angle=i*2.39996+t*(.08+(i%4)*.03),radius=Math.sqrt(i/105)*(65+Math.sin(t*1.5+i*.21)*18*a);let x=Math.cos(angle)*radius*1.45,y=Math.sin(angle)*radius*.63;c.globalAlpha=.2+(Math.sin(t+i)*.5+.5)*.8;glow(i%17===0?9:0);circle(x,y,i%17===0?2:1,col)}break;
 case 7: // 萤群 — separate drifting light organisms
  for(let i=0;i<17;i++){let x=Math.sin(i*8.1+t*(.19+i%3*.07))*93,y=Math.cos(i*3.2+t*.4)*35*a;let alpha=.15+.85*Math.pow((Math.sin(t*1.7+i)+1)/2,2);c.globalAlpha=alpha;glow(12);circle(x,y,i%3===0?3:1.8,i%3===0?white:col)}break;
 case 8: // 沙漏 — particles through a waist
  for(let i=0;i<95;i++){let y=((i*1.81+t*21)%100)-50;let x=Math.sin(i*12.73)*Math.abs(y)*.88; c.globalAlpha=.2+Math.abs(y)/65;circle(x,y,1.5,col)}line([[-47,-54],[47,-54]],muted,1);line([[-47,54],[47,54]],muted,1);glow(12);circle(0,0,3,white);break;
 case 9: // 磁场 — dipole field
  for(let j=0;j<7;j++){let pts=[];for(let k=0;k<=50;k++){let q=k/50*Math.PI;pts.push([-66*Math.cos(q),Math.sin(q)*(12+j*7)*(j%2?1:-1)])}c.globalAlpha=.17;line(pts,col,.8);c.globalAlpha=.95;let q=(t*.8+j*.61)%Math.PI;circle(-66*Math.cos(q),Math.sin(q)*(12+j*7)*(j%2?1:-1),2,col)}circle(-66,0,5,white);circle(66,0,5,col);break;
 case 10: // 雨幕 — staggered falling slivers
  for(let i=0;i<25;i++){let x=(i-12)*8,y=((t*(24+i%5*5)+i*13)%88)-44;let len=6+(Math.sin(i*1.3+t)*.5+.5)*19*a;c.globalAlpha=.2+(1-Math.abs(y)/60)*.7;line([[x,y-len/2],[x,y+len/2]],i%7===0?white:col,i%4===0?2.3:1)}break;
 case 11: // 日蚀 — crescent disk, offset occlusion
  {glow(18);circle(0,0,38,col);glow(0);circle(8+Math.sin(t*.7)*5*a,-5+Math.cos(t*.7)*2,37,tone('#14171d'));ellipse(0,0,52,52,0,tone('#34414f'),.7);circle(Math.cos(t*.45)*52,Math.sin(t*.45)*52,2,white)}break;
 case 12: // 双星 — opposing bodies on an orbit
  ellipse(0,0,80,30,-.2,tone('#3c475a'),.8);for(let i=0;i<2;i++){let q=t*.8+i*Math.PI,x=Math.cos(q)*80,y=Math.sin(q)*30;c.save();c.rotate(-.2);glow(18,i?col:white);circle(x,y,i?7:10,i?col:white);glow(0);c.restore()}line([[-5,0],[5,0]],muted,1);line([[0,-5],[0,5]],muted,1);break;
 case 13: // 声瞳 — radial iris
  for(let i=0;i<72;i++){let q=i/72*tau,r=19+Math.sin(t*2+i*.2)*3*a,outer=36+(Math.sin(i*.48+t*3)*.5+.5)*13*a;c.globalAlpha=.3+(i%5)/7;line([[Math.cos(q)*r,Math.sin(q)*r],[Math.cos(q)*outer,Math.sin(q)*outer]],i%7===0?white:col,1.5)}circle(0,0,10,tone('#222d39'),false);break;
 case 14: // 涡环 — open spiral pulse
  for(let j=0;j<3;j++){let pts=[];for(let k=0;k<=150;k++){let q=k/150*tau*1.3+t*.6+j*tau/3,r=12+k*.22;pts.push([Math.cos(q)*r,Math.sin(q)*r])}c.globalAlpha=.85-j*.22;line(pts,col,1.4)}break;
 case 15: // 星仪 — precessing orbital instrument
  for(let j=0;j<3;j++){const rot=j*Math.PI/3+t*.1;ellipse(0,0,58,18+Math.sin(t+j)*5*a,rot,j===1?white:col,1);c.save();c.rotate(rot);glow(6);circle(Math.cos(t+j*2)*58,Math.sin(t+j*2)*18,2.5,col);c.restore()}circle(0,0,4,white);break;
 case 16: // 极光 — layered translucent ribbons
  for(let j=0;j<12;j++){let pts=[];for(let x=-108;x<=108;x+=3){let y=Math.sin(x/45+t*.8+j*.11)*23*a+Math.sin(x/80-t*.7)*12+j*2-12;pts.push([x,y])}c.globalAlpha=.15+Math.sin(j/12*Math.PI)*.5;line(pts,j<6?tone('#a1e5e5'):tone('#b3c8ff'),3)}break;
 case 17: // 熔珠 — light reflecting on soft colliding beads
  for(let i=0;i<3;i++){let x=(i-1)*(29+Math.sin(t*1.3)*10*a),r=18+(Math.sin(t*1.6+i)*3*a);let g=c.createRadialGradient(x-5,-7,1,x,0,r);g.addColorStop(0,tone('#f7ffff'));g.addColorStop(.32,col);g.addColorStop(1,tone('#304451'));glow(6);circle(x,0,r,g);glow(0)}break;
 case 18: // 光翼 — hinged bilateral light blades
  for(let side of [-1,1])for(let i=0;i<14;i++){let q=.1+i*.055+Math.sin(t*1.8)*.17*a,len=105-i*3;c.globalAlpha=.12+i*.045;line([[side*5,7],[side*Math.cos(q)*len,-Math.sin(q)*len+7]],i>10?white:col,2)}circle(0,7,3,white);break;
 case 19: // 潮汐 — low rolling surface planes
  for(let j=0;j<15;j++){let pts=[];for(let x=-104;x<=104;x+=4)pts.push([x,Math.sin(x/48-t*1.2+j*.18)*14*a+j*2.5-18]);c.globalAlpha=.12+j*.045;line(pts,col,1)}break;
 case 20: // 彗尾 — velocity trail behind a nucleus
  {let x=Math.sin(t*.65)*66,y=Math.sin(t*1.3)*20*a;for(let i=42;i>=0;i--){let tt=t-i*.024,xx=Math.sin(tt*.65)*66,yy=Math.sin(tt*1.3)*20*a;c.globalAlpha=(1-i/44)*.75;circle(xx-i*.75,yy,1+(1-i/44)*4,col)}c.globalAlpha=1;glow(14);circle(x,y,4,white)}break;
 case 21: // 音叉 — opposed resonance forks
  {let v=Math.sin(t*10)*3*a;c.strokeStyle=col;c.lineWidth=3;c.lineCap='round';c.beginPath();c.moveTo(-22-v,-42);c.lineTo(-22,8);c.quadraticCurveTo(-22,30,0,30);c.quadraticCurveTo(22,30,22,8);c.lineTo(22+v,-42);c.stroke();line([[0,30],[0,55]],white,3);for(let i=0;i<3;i++){c.globalAlpha=.5-i*.13;line([[-34-i*8,-25],[-34-i*8,9]],col,1);line([[34+i*8,-25],[34+i*8,9]],col,1)}}break;
 case 22: // 百叶 — individually rotating vanes
  for(let i=0;i<13;i++){let q=t*1.8-i*.23,width=3+Math.abs(Math.cos(q))*8;c.save();c.translate((i-6)*14,0);c.rotate(Math.sin(q)*.13*a);let g=c.createLinearGradient(-width/2,0,width/2,0);g.addColorStop(0,tone('#526877'));g.addColorStop(.55,col);g.addColorStop(1,tone('#e4f5ff'));rect(-width/2,-25,width,50,1,g);c.restore()}break;
 case 23: // 晶簇 — faceted unequal crystal peaks
  for(let i=0;i<7;i++){let x=(i-3)*21,hh=18+(Math.sin(i*2.1+t*1.5)*.5+.5)*35*a;c.beginPath();c.moveTo(x-10,22);c.lineTo(x-10,-hh+12);c.lineTo(x,-hh);c.lineTo(x+10,-hh+12);c.lineTo(x+10,22);c.closePath();c.fillStyle=i%2?tone('#69788e'):tone('#9babca');c.fill();c.beginPath();c.moveTo(x,-hh);c.lineTo(x+10,-hh+12);c.lineTo(x+10,22);c.lineTo(x,22);c.closePath();c.fillStyle=i%2?col:tone('#d9e6fd');c.fill();}break;
 case 24: // 折扇 — hinged ribs fan out
  for(let i=0;i<17;i++){let q=(i-8)*(.1+Math.sin(t*1.25)*.025*a);c.save();c.translate(0,40);c.rotate(q);c.globalAlpha=.35+(i%3)*.25;line([[0,0],[0,-90]],i===8?white:col,2);c.restore()}circle(0,40,4,white);break;
 case 25: // 跃阶 — stepped relay blocks
  for(let i=0;i<9;i++){let phase=(t*1.8-i*.45),lift=Math.max(0,Math.sin(phase))*28*a;rect((i-4)*21-7,14-lift,14,14,2,i%3===1?white:col);c.globalAlpha=.18;rect((i-4)*21-7,36,14,2,1,col);c.globalAlpha=1}break;
 case 26: // 双岛 — disconnected control islands and signal bridge
  rect(-108,-23,44,46,15,tone('#29313e'));rect(64,-23,44,46,15,tone('#e3ebf7'));circle(-86,0,4,col);circle(86,0,4,tone('#192230'));for(let i=0;i<11;i++){const x=(i-5)*9,hh=4+(Math.sin(t*3-i*.6)*.5+.5)*17*a;rect(x-1.5,-hh/2,3,hh,1.5,col)}break;
 case 27: // 切角舱 — angular inset cockpit
  {let shape=[[-112,-24],[94,-24],[112,-6],[112,24],[-94,24],[-112,6]];c.beginPath();shape.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.closePath();c.fillStyle=tone('#1c2531');c.fill();line(shape,tone('#5b718b'),1,true);for(let i=0;i<20;i++){let x=(i-9.5)*7;c.globalAlpha=.2+.8*Math.pow((Math.sin(t*2-i*.3)+1)/2,2);rect(x-2,-8,4,16,0,col)}c.globalAlpha=1;line([[-102,-16],[-88,-16]],white,2);line([[88,16],[102,16]],white,2)}break;
 case 28: // 唱针 — rotating grooves and stylus arm
  circle(-12,0,43,tone('#222b38'));for(let r=14;r<42;r+=5)circle(-12,0,r,tone('#485267'),false,.6);c.save();c.translate(-12,0);c.rotate(t*.6);line([[8,0],[39,0]],tone('#9aa7bb'),1);c.restore();circle(-12,0,10,col);circle(-12,0,2,tone('#14171d'));let y=5+Math.sin(t*5)*1.3*a;line([[72,-43],[60,-43],[31,y],[23,y]],white,3);circle(72,-43,4,muted);break;
 case 29: // 悬浮键 — lifted key above a free spectrum
  {let y=-18-Math.sin(t*2)*3*a;rect(-28,y-20,56,42,10,tone('#303c50'));rect(-28,y-24,56,40,10,tone('#d5e2f4'));line([[-8,y-6],[-4,y+3],[0,y-10],[4,y+5],[8,y-4]],tone('#26354b'),1.7);for(let i=0;i<13;i++){let hh=3+(Math.sin(t*3-i*.7)*.5+.5)*15*a;c.globalAlpha=.5;rect((i-6)*8-1,32-hh/2,2,hh,1,col)}c.globalAlpha=1}break;
 case 30: // 呼吸石 — irregular soft silhouette, no geometric enclosure
  {let rr=1+Math.sin(t*1.5)*.035*a;c.save();c.scale(rr,rr);c.beginPath();c.moveTo(-51,4);c.bezierCurveTo(-51,-35,-8,-45,26,-30);c.bezierCurveTo(59,-17,63,17,36,32);c.bezierCurveTo(8,49,-49,40,-51,4);let g=c.createLinearGradient(-25,-35,25,38);g.addColorStop(0,tone('#c5d5e7'));g.addColorStop(.5,tone('#71879f'));g.addColorStop(1,tone('#344352'));c.fillStyle=g;c.fill();glow(8);pathWave(0,5*a,1,tone('#e7f9ff'),1);glow(0);c.restore()}break;
 case 31: // 回声
  for(let j=0;j<6;j++){let r=10+((t*20+j*12)%76);c.globalAlpha=1-r/90;c.beginPath();c.arc(-45,0,r,-.9,.9);c.strokeStyle=col;c.lineWidth=2;c.stroke()}circle(-45,0,4,white);break;
 case 32: // 琴弦
  for(let j=0;j<6;j++){let p=[];for(let x=-100;x<=100;x+=3)p.push([x,(j-2.5)*11+Math.sin((x+100)/200*Math.PI*(j%3+1))*Math.sin(t*(2+j*.35))*9*a]);line(p,j===3?white:col,1)}break;
 case 33: // 频桥
  for(let j=0;j<5;j++){c.beginPath();c.moveTo(-100,20);c.bezierCurveTo(-45,-30-Math.sin(t*2+j)*18*a,45,-30+Math.sin(t*2+j)*18*a,100,20);c.globalAlpha=.25+j*.15;c.strokeStyle=col;c.lineWidth=1.2;c.stroke()}circle(-100,20,3,white);circle(100,20,3,white);break;
 case 34: // 墨线
  for(let i=0;i<65;i++){let x=(i-32)*3.5,y=Math.sin(x/48+t*1.2)*16*a,yy=Math.sin((x+3.5)/48+t*1.2)*16*a;line([[x,y],[x+3.5,yy]],col,1+Math.pow(Math.cos(x/240*Math.PI),2)*7)}break;
 case 35: // 流苏
  line([[-85,-32],[85,-32]],muted,1);for(let j=0;j<25;j++){let x=(j-12)*7;c.beginPath();c.moveTo(x,-32);c.quadraticCurveTo(x+Math.sin(t+j*.13)*8*a,0,x+Math.sin(t*1.7+j*.23)*14*a,25+Math.sin(j*.6)*10);c.strokeStyle=j%4?col:white;c.globalAlpha=.4+j%4*.15;c.lineWidth=1;c.stroke()}break;
 case 36: // 绸环
  for(let j=0;j<12;j++){let p=[];for(let k=0;k<=100;k++){let q=k/100*tau;p.push([Math.cos(q)*(61+Math.sin(q*2+t)*j*.5),Math.sin(q)*24+Math.cos(q*2+t)*j*.9])}c.globalAlpha=.2+j*.045;line(p,j%4?col:white,.9)}break;
 case 37: // 针脚
  for(let j=0;j<24;j++){let x=(j-12)*8,y=Math.sin(j*.5+t*2)*12*a;c.globalAlpha=.35+(Math.sin(t*2-j*.3)+1)*.3;line([[x,y-5],[x+5,y+5]],j%2?col:white,1.6);if(j%2===0)line([[x+5,y+5],[x+8,Math.sin((j+1)*.5+t*2)*12*a-5]],muted,.6)}break;
 case 38: // 水纹
  for(let j=0;j<7;j++){let r=((t*12+j*11)%80)+6;c.globalAlpha=1-r/95;ellipse(-18+Math.sin(j)*8,3,r,r*.36,.06,col,1)}break;
 case 39: // 双螺旋
  for(let j=0;j<30;j++){let x=(j-14.5)*6.5,y=Math.sin(j*.28+t*2)*23*a;line([[x,y],[x,-y]],muted,.7);circle(x,y,1.8,col);circle(x,-y,1.8,white)}break;
 case 40: // 风痕
  for(let j=0;j<12;j++){let x=((t*(25+j)+j*19)%240)-120,y=(j-6)*6,len=15+j%4*7;c.globalAlpha=Math.sin((x+120)/240*Math.PI);c.beginPath();c.moveTo(x-len,y);c.quadraticCurveTo(x-len/2,y-5*a,x,y);c.strokeStyle=j%3?col:white;c.lineWidth=1.2;c.stroke()}break;
 case 41: // 光砂
  for(let j=0;j<110;j++){let x=(j/110-.5)*210,raise=Math.pow(Math.max(0,Math.sin(t*2+x/35)),3)*29*a;let y=15-Math.abs(Math.sin(j*7.31))*raise;c.globalAlpha=.3+(j%7)/10;circle(x,y,(j%9===0?1.8:.9),j%9?col:white)}break;
 case 42: // 蜂群
  for(let j=0;j<19;j++){let ring=j===0?0:j<7?1:2,n=ring===1?6:12,q=(j-(ring===1?1:7))/n*tau+t*.15,r=ring*23,x=Math.cos(q)*r,y=Math.sin(q)*r*.8;let p=[];for(let k=0;k<=6;k++){let z=k/6*tau;p.push([x+Math.cos(z)*8,y+Math.sin(z)*8])}line(p,col,.8);circle(x+Math.cos(t*2+j)*3*a,y+Math.sin(t*2+j)*3*a,1.6,white)}break;
 case 43: // 珠链
  for(let j=0;j<17;j++){let x=(j-8)*12,y=Math.sin(j*.38+t)*16*a,r=2+(Math.sin(j*.4-t*2)*.5+.5)*3;circle(x,y,r,j%3?col:white)}break;
 case 44: // 雪晶
  for(let j=0;j<6;j++){c.save();c.rotate(j*tau/6);line([[0,0],[0,-47]],muted,1);for(let k=1;k<5;k++){let y=-k*9;line([[0,y],[-7,y-6]],col,1);line([[0,y],[7,y-6]],col,1);c.globalAlpha=.3+(Math.sin(t*2-k*.7)+1)*.35;circle(0,y,2,white)}c.restore()}break;
 case 45: // 引力井
  for(let j=0;j<90;j++){let progress=(t*.18+j/90)%1,r=(1-progress)*68,q=j*2.399+progress*7;c.globalAlpha=.2+progress*.8;circle(Math.cos(q)*r*1.4,Math.sin(q)*r*.7,1.3,col)}circle(0,0,4,white);break;
 case 46: // 跳豆
  line([[-103,28],[103,28]],muted,.8);for(let j=0;j<11;j++){let y=21-Math.abs(Math.sin(t*(1.6+j%3*.16)-j*.35))*(18+j%4*10)*a;circle((j-5)*18,y,3.5,j%3?col:white)}break;
 case 47: // 星图
  {const nodes=[[-92,17],[-70,-20],[-32,-33],[-12,10],[23,-16],[54,28],[89,-5]];line(nodes,muted,1);nodes.forEach(([x,y],j)=>{circle(x,y,3,col);let next=nodes[(j+1)%nodes.length];if(j<6){let v=(t*.4+j*.18)%1;circle(x+(next[0]-x)*v,y+(next[1]-y)*v,1.8,white)}})}break;
 case 48: // 气泡
  for(let j=0;j<17;j++){let p=(t*.2+j*.123)%1,x=Math.sin(j*3.7)*74+Math.sin(t+j)*5,y=40-p*90,r=(1-p)*(4+j%4*2)+1;c.globalAlpha=1-p;circle(x,y,r,col,false,1)}break;
 case 49: // 微火
  for(let j=0;j<42;j++){let p=(t*.4+j*.071)%1,x=Math.sin(j*12.3)*p*39,y=33-p*83;c.globalAlpha=1-p;line([[x,y+6*(1-p)],[x,y]],j%4?col:white,1.5)}break;
 case 50: // 像素潮
  for(let x=0;x<20;x++)for(let y=0;y<7;y++){let level=2+(Math.sin(x*.4-t*2)*.5+.5)*5*a;if(y<level){c.globalAlpha=.28+y*.1;rect((x-10)*9,29-y*9,5,5,0,y>4?white:col)}}break;
 case 51: // 罗盘
  for(let j=0;j<32;j++){let q=j/32*tau,r=j%4===0?36:40;line([[Math.cos(q)*r,Math.sin(q)*r],[Math.cos(q)*45,Math.sin(q)*45]],muted,1)}c.save();c.rotate(Math.sin(t)*.8*a);line([[0,-35],[0,35]],col,2);line([[0,-35],[-5,-24],[5,-24],[0,-35]],white,1,true);circle(0,0,4,white);c.restore();break;
 case 52: // 光晕
  for(let j=0;j<36;j++){let q=j/36*tau;c.globalAlpha=.2+Math.pow((Math.sin(q-t*1.4)+1)/2,4)*.8;c.beginPath();c.arc(0,0,39,q,q+.105);c.lineWidth=4;c.strokeStyle=col;c.stroke()}break;
 case 53: // 行星环
  ellipse(0,0,69,19,-.25,muted,1);circle(0,0,25,col);ellipse(0,0,69,19,-.25,white,1);c.save();c.rotate(-.25);circle(Math.cos(t)*69,Math.sin(t)*19,4,white);c.restore();break;
 case 54: // 花冠
  for(let j=0;j<9;j++){c.save();c.rotate(j*tau/9);let r=22+Math.sin(t*1.5+j*.6)*5*a;ellipse(0,-r,9,r,0,j%3?col:white,1);c.restore()}circle(0,0,4,col);break;
 case 55: // 陀螺
  c.save();c.rotate(Math.sin(t)*.14*a);for(let j=0;j<8;j++){let y=(j-3)*8,rx=45-Math.abs(j-3)*9;ellipse(0,y,rx,rx*.3,t*.12,j===3?white:col,1)}line([[0,-44],[0,42]],muted,1);c.restore();break;
 case 56: // 声门
  circle(0,0,43,muted,false);for(let j=0;j<8;j++){c.save();c.rotate(j*tau/8);let opening=8+(Math.sin(t*1.8)*.5+.5)*12*a;line([[opening,-5],[30,-22],[39,-7],[opening,10]],j%2?col:white,1.2);c.restore()}break;
 case 57: // 轨迹球
  circle(0,0,44,col,false);for(let j=0;j<6;j++)ellipse(0,0,Math.abs(Math.sin(t*.5+j*Math.PI/6))*43+.2,44,0,col,.8);for(let j=-1;j<=1;j++)ellipse(0,j*21,Math.sqrt(44*44-j*j*21*21),7,0,muted,.7);circle(Math.cos(t)*35,Math.sin(t)*25,2.4,white);break;
 case 58: // 月相
  for(let j=0;j<5;j++){let x=(j-2)*39;circle(x,0,15,col);c.save();c.beginPath();c.arc(x,0,15,0,tau);c.clip();circle(x+Math.sin(t*.6+j*.6)*24,0,15,surface);c.restore()}break;
 case 59: // 共振环
  {let d=14+Math.sin(t*1.5)*8*a;ellipse(-d,0,32,32,.1,col,1.4);ellipse(d,0,32,32,-.1,white,1.4);circle(0,Math.sqrt(Math.max(0,1024-d*d)),2.5,col);circle(0,-Math.sqrt(Math.max(0,1024-d*d)),2.5,col)}break;
 case 60: // 时轮
  for(let j=0;j<48;j++){let q=j/48*tau,r=39-((j+Math.floor(t*6))%8<2?12:3);line([[Math.cos(q)*r,Math.sin(q)*r],[Math.cos(q)*43,Math.sin(q)*43]],j%4?col:white,j%4?1:2)}break;
 case 61: // 液镜
  {c.save();c.scale(1,.46);let p=[];for(let j=0;j<=120;j++){let q=j/120*tau,r=63+Math.sin(q*3+t)*4*a;p.push([Math.cos(q)*r,Math.sin(q)*r])}line(p,col,1.5);for(let j=0;j<12;j++){c.globalAlpha=.15+j*.045;pathWave(j*.25,23*a,1,j%3?col:white,1.4)}c.restore()}break;
 case 62: // 光瀑
  for(let j=0;j<22;j++){let x=(j-10.5)*5,p=[];for(let k=0;k<=20;k++){let y=k*4-40;p.push([x+Math.sin(y/30+t+j*.1)*7*a,y])}c.globalAlpha=.15+(Math.sin(t*2-j*.3)*.5+.5)*.8;line(p,j%5?col:white,1.7)}break;
 case 63: // 波瓣
  for(let j=0;j<5;j++){let p=[];for(let k=0;k<=120;k++){let q=k/120*tau,r=24+j*4+Math.sin(q*5+t*1.5+j*.4)*9*a;p.push([Math.cos(q)*r,Math.sin(q)*r])}c.globalAlpha=.3+j*.13;line(p,col,1)}break;
 case 64: // 焰心
  for(let j=0;j<3;j++){let s=1-j*.24;c.save();c.scale(s,s);c.beginPath();c.moveTo(0,40);c.bezierCurveTo(-50,20,-9,-20,Math.sin(t*2)*15*a,-53);c.bezierCurveTo(12,-14,43,15,0,40);c.globalAlpha=.35+j*.22;c.fillStyle=j===2?white:col;c.fill();c.restore()}break;
 case 65: // 流云
  for(let j=0;j<7;j++){let x=Math.sin(t*.6+j*.4)*28,y=Math.sin(j*1.3)*12;c.globalAlpha=.1+j*.07;ellipse(x,y,73-j*5,14+j,Math.sin(t+j)*.05,col,4)}break;
 case 66: // 折光
  line([[-22,-38],[40,29],[-43,29],[-22,-38]],muted,1);line([[-110,-15],[-16,1]],white,2);for(let j=0;j<5;j++){let y=9+(j-2)*10+Math.sin(t*2+j)*3*a;line([[8,6],[111,y]],palette[j],1.5)}break;
 case 67: // 光帆
  for(let j=0;j<15;j++){let d=j/14;c.beginPath();c.moveTo(-57,35);c.quadraticCurveTo(-10+Math.sin(t*1.3)*16*a,-54*d,50,30-68*d);c.strokeStyle=j%4?col:white;c.lineWidth=1;c.globalAlpha=.3+d*.6;c.stroke()}line([[-57,35],[50,30]],muted,1);break;
 case 68: // 液滴
  {let stretch=Math.sin(t*1.8)*6*a;c.beginPath();c.moveTo(0,-47-stretch);c.bezierCurveTo(-8,-12,-34,3,-25,24);c.bezierCurveTo(-16,48,26,44,29,17);c.bezierCurveTo(29,-1,6,-21,0,-47-stretch);let g=c.createLinearGradient(-24,-20,30,35);g.addColorStop(0,white);g.addColorStop(.35,col);g.addColorStop(1,muted);c.fillStyle=g;c.fill();ellipse(-6,13,9,15,-.4,white,1)}break;
 case 69: // 晨弧
  for(let j=0;j<12;j++){c.beginPath();c.ellipse(0,23,91-j*2,44-j*2,0,Math.PI,tau);c.strokeStyle=j%4?col:white;c.globalAlpha=.1+(.5+.5*Math.sin(t*1.5-j*.2))*.6;c.lineWidth=1.8;c.stroke()}break;
 case 70: // 光结
  for(let j=0;j<10;j++){let p=[];for(let k=0;k<=150;k++){let q=k/150*tau;p.push([Math.sin(q)*74,Math.sin(q*2+t*.4)*(20+j*.65)+j-5])}c.globalAlpha=.15+j*.06;line(p,j%4?col:white,1.1)}break;
 case 71: // 齿语
  for(let j=0;j<18;j++){if(j%6===5)continue;let q=j/18*tau+Math.floor(t*5)*.08;c.save();c.rotate(q);rect(-3,-45,6,j%3?12:18,1,j%3?col:white);c.restore()}circle(0,0,22,muted,false);break;
 case 72: // 拨片
  line([[-92,0],[92,0]],muted,1);for(let j=0;j<13;j++){c.save();c.translate((j-6)*14,0);c.rotate(Math.sin(t*2-j*.4)*.5*a);rect(-3,-20,6,40,2,j%3?col:white);c.restore()}break;
 case 73: // 风车
  c.save();c.rotate(t*.9+Math.sin(t)*.2*a);for(let j=0;j<4;j++){c.rotate(Math.PI/2);c.beginPath();c.moveTo(3,0);c.lineTo(48,-11);c.lineTo(31,18);c.lineTo(3,0);c.fillStyle=j%2?col:white;c.globalAlpha=.7;c.fill()}c.restore();circle(0,0,5,muted);break;
 case 74: // 棱镜
  {let front=[],back=[];for(let j=0;j<6;j++){let q=j/6*tau+t*.3;front.push([Math.cos(q)*38-13,Math.sin(q)*34+9]);back.push([Math.cos(q)*38+13,Math.sin(q)*34-9])}line(back,muted,1,true);front.forEach((p,j)=>line([p,back[j]],col,1));line(front,white,1.2,true)}break;
 case 75: // 折纸
  for(let j=0;j<10;j++){let x=(j-5)*19,y=Math.sin(t*1.6-j*.3)*9*a;c.beginPath();c.moveTo(x,20);c.lineTo(x+10,-22+y);c.lineTo(x+20,20);c.closePath();c.fillStyle=j%2?col:muted;c.fill();line([[x+10,-22+y],[x+20,20]],white,.8)}break;
 case 76: // 声尺
  for(let j=-15;j<=15;j++){let active=Math.abs(j)<5+(Math.sin(t*2)*.5+.5)*10*a;c.globalAlpha=active?1:.22;let len=j%5===0?16:8;line([[j*7,-7],[j*7,-7-len]],active?col:muted,1.5);line([[j*7,7],[j*7,7+len]],active?white:muted,1.5)}break;
 case 77: // 浮标
  line([[0,-48],[0,48]],muted,1.3);for(let j=0;j<5;j++){let y=(j-2)*18+Math.sin(t*2+j*.7)*7*a;rect(-15-j%2*8,y-2,30+j%2*16,4,2,j===2?white:col)}break;
 case 78: // 悬桥
  {let p=[];for(let j=0;j<21;j++){let x=(j-10)*9,y=10+Math.cos(x/90*Math.PI/2)*12+Math.sin(t*2-j*.4)*5*a;p.push([x,y-24]);line([[x,y-24],[x,y]],muted,.8);rect(x-3,y,6,4,1,col)}line(p,white,1.2)}break;
 case 79: // 脉冲芯
  for(let j=0;j<5;j++){let r=10+j*8;c.globalAlpha=.18+Math.pow((Math.sin(t*3-j*.8)+1)/2,2)*.82;let p=[[-r+6,-r],[r-6,-r],[r,-r+6],[r,r-6],[r-6,r],[-r+6,r],[-r,r-6],[-r,-r+6]];line(p,j===0?white:col,j===0?2:1,true)}break;
 case 80: // 折叠舱
  {let opening=20+Math.sin(t*1.5)*8*a;line([[-8,-27],[-opening-30,-17],[-opening-30,17],[-8,27]],col,1.5);line([[8,-27],[opening+30,-17],[opening+30,17],[8,27]],col,1.5);for(let j=0;j<7;j++){let y=(j-3)*6;line([[-6,y],[6,y]],j===3?white:col,2)}}break;

 }
 c.restore();
}
window.VoiceAtlasArt={draw};
})();
