#!/bin/bash
set -e

echo "=== SPA WALL KIOSK FULL INSTALL ==="

### SYSTEM
sudo apt update
sudo apt install -y chromium-browser git nodejs npm mpd mpc xprintidle curl

sudo raspi-config nonint do_boot_behaviour B4

### DIRECTORIES
mkdir -p /home/pi/{kiosk,music-server}
mkdir -p /home/pi/music/{ryans_fam,wakena,isaiah,elijah,pappa,guest}
mkdir -p /home/pi/.config/lxsession/LXDE-pi

### MPD
sudo sed -i 's|^music_directory.*|music_directory "/home/pi/music/current"|' /etc/mpd.conf
sudo systemctl restart mpd

### PROFILE SWITCH
cat << 'EOF' > /home/pi/switch-profile.sh
#!/bin/bash
BASE="/home/pi/music"
rm -rf "$BASE/current"
ln -s "$BASE/$1" "$BASE/current"
mpc clear
mpc update
mpc play
EOF
chmod +x /home/pi/switch-profile.sh

### HOME (RIPPLE)
cat << 'EOF' > /home/pi/kiosk/index.html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Who Are You</title>
<style>
html,body{margin:0;height:100%;background:#050d14;color:white;font-family:Arial;overflow:hidden}
#profiles{display:flex;flex-wrap:wrap;gap:40px;justify-content:center;align-items:center;height:100%}
.profile{width:180px;height:180px;border-radius:50%;background:#1db954;display:flex;align-items:center;justify-content:center;font-size:20px}
.profile:active{transform:scale(.95)}
canvas{position:absolute;inset:0;z-index:-1}
</style>
</head>
<body>
<canvas id="r"></canvas>
<div id="profiles">
<div class="profile" onclick="go('ryans_fam')">Ryan’s Fam</div>
<div class="profile" onclick="go('wakena')">Wakena</div>
<div class="profile" onclick="go('isaiah')">Isaiah</div>
<div class="profile" onclick="go('elijah')">Elijah</div>
<div class="profile" onclick="go('pappa')">Pappa</div>
<div class="profile" onclick="go('guest')">Guest</div>
</div>
<script>
function go(p){
fetch("http://localhost:3000/profile",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({profile:p})})
.then(()=>location=`file:///home/pi/kiosk/${p}.html`);
}
const c=document.getElementById("r"),x=c.getContext("2d");let a=[];
function s(){c.width=innerWidth;c.height=innerHeight}onresize=s;s();
addEventListener("pointerdown",e=>a.push({x:e.clientX,y:e.clientY,r:0,o:.6}));
(function d(){x.clearRect(0,0,c.width,c.height);
a.forEach(p=>{x.beginPath();x.arc(p.x,p.y,p.r,0,Math.PI*2);
x.strokeStyle=`rgba(100,200,255,${p.o})`;x.lineWidth=2;
x.shadowBlur=20;x.shadowColor="rgba(100,200,255,.8)";
x.stroke();p.r+=3;p.o-=.008});
a=a.filter(p=>p.o>0);requestAnimationFrame(d)})();
</script>
</body>
</html>
EOF

### PROFILE PAGES (WITH SEARCH + VISUALIZER)
for p in ryans_fam wakena isaiah elijah pappa guest; do
cat << EOF > /home/pi/kiosk/$p.html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>$p</title>
<style>
body{margin:0;background:#050d14;color:white;font-family:Arial}
h1{text-align:center;padding:20px}
input{width:90%;margin:10px auto;display:block;padding:14px;font-size:18px;border-radius:10px}
.song{padding:18px;border-bottom:1px solid #222;font-size:20px}
.song:active{background:#1db954;color:black}
button{margin:20px auto;display:block;padding:12px 30px}
canvas{position:fixed;bottom:0;left:0;width:100%;height:150px;opacity:.25}
</style>
</head>
<body>
<h1>$p</h1>
<input id="search" placeholder="Search free music…">
<div id="songs"></div>
<button onclick="logout()">Log Out</button>
<canvas id="v"></canvas>
<script>
function load(){
fetch("http://localhost:3000/playlist").then(r=>r.json()).then(s=>{
const box=document.getElementById("songs");box.innerHTML="";
s.forEach((x,i)=>{
const d=document.createElement("div");
d.className="song";d.textContent=x;
d.onclick=()=>fetch("http://localhost:3000/play",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({index:i+1})});
box.appendChild(d);
});
});
}
document.getElementById("search").onchange=e=>{
fetch("http://localhost:3000/ia-search?q="+e.target.value)
.then(r=>r.json()).then(r=>{
const box=document.getElementById("songs");box.innerHTML="";
r.forEach(i=>{
const d=document.createElement("div");
d.className="song";d.textContent="Add: "+i.title;
d.onclick=()=>fetch("http://localhost:3000/ia-download",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({identifier:i.identifier})}).then(load);
box.appendChild(d);
});
});
};
function logout(){
fetch("http://localhost:3000/logout",{method:"POST"}).then(()=>location="file:///home/pi/kiosk/index.html");
}
load();
</script>
</body>
</html>
EOF
done

### SERVER (PROFILES + QUOTAS + INTERNET ARCHIVE + GUEST RESET)
cat << 'EOF' > /home/pi/music-server/server.js
const express=require("express");
const fetch=require("node-fetch");
const {exec}=require("child_process");
const fs=require("fs");
const path=require("path");
const app=express();
app.use(express.json());

const BASE="/home/pi/music";
const LIMIT=15*1024*1024*1024;
let profile="isaiah";

function size(dir){
 let t=0;if(!fs.existsSync(dir))return 0;
 fs.readdirSync(dir).forEach(f=>{
  const p=path.join(dir,f);
  if(fs.statSync(p).isFile())t+=fs.statSync(p).size;
 });
 return t;
}

app.post("/profile",(req,res)=>{
 profile=req.body.profile;
 exec(`/home/pi/switch-profile.sh ${profile}`);
 res.sendStatus(200);
});

app.get("/playlist",(req,res)=>{
 exec("mpc playlist",(e,o)=>res.json(o.split("\\n").filter(Boolean)));
});

app.post("/play",(req,res)=>{
 exec(`mpc play ${req.body.index}`,()=>res.sendStatus(200));
});

app.get("/ia-search",async(req,res)=>{
 const q=encodeURIComponent(req.query.q);
 const u=\`https://archive.org/advancedsearch.php?q=\${q}+AND+mediatype:audio&fl[]=identifier&fl[]=title&rows=8&page=1&output=json\`;
 const r=await fetch(u).then(r=>r.json());
 res.json(r.response.docs);
});

app.post("/ia-download",async(req,res)=>{
 const dir=path.join(BASE,profile);
 if(size(dir)>=LIMIT)return res.status(403).end();
 const id=req.body.identifier;
 const m=await fetch(\`https://archive.org/metadata/\${id}\`).then(r=>r.json());
 const f=m.files.find(x=>x.format&&x.format.includes("MP3"));
 if(!f)return res.sendStatus(404);
 const url=\`https://archive.org/download/\${id}/\${f.name}\`;
 const out=path.join(dir,f.name.replace(/[^a-z0-9.]/gi,"_"));
 exec(\`curl -L "\${url}" -o "\${out}" && mpc update\`,()=>res.sendStatus(200));
});

app.post("/logout",(req,res)=>{
 if(profile==="guest")exec("rm -rf /home/pi/music/guest/*");
 res.sendStatus(200);
});

app.listen(3000);
EOF

npm install --prefix /home/pi/music-server express node-fetch

### KIOSK START
cat << 'EOF' > /home/pi/kiosk/start.sh
#!/bin/bash
xset s off
xset -dpms
xset s noblank
chromium-browser --kiosk --incognito file:///home/pi/kiosk/index.html
EOF
chmod +x /home/pi/kiosk/start.sh

### AUTOSTART
cat << 'EOF' > /home/pi/.config/lxsession/LXDE-pi/autostart
@/home/pi/kiosk/start.sh
@node /home/pi/music-server/server.js
EOF

echo "=== DONE — REBOOTING ==="
sleep 3
sudo reboot
