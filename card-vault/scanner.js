// =====================================================================
// 카드 보관소 스캐너 — 포켓몬 카드 앱의 스캐너를 입고용으로 떼어낸 모듈 (window.Scan)
//  · 카메라: 신분증 스캔처럼 틀 안에서 네 변이 잡히고 흔들림이 멈추면 자동 촬영 (사진 파일도 가능)
//  · 판독: 이름(OCR) + 카드 번호(OCR) → TCGdex에서 찾고, 그림 색 격자로 후보 순위 결정
//  · 등급: 앞·뒷면 센터링 + 뒷면 모서리·테두리 까짐 → S/A/B/C
//  · 지문: 그림 색 격자(같은 카드인지) + 센터링 수치(같은 실물인지 보조) → 입고 대조에 사용
// =====================================================================
(() => {
const CARD_W = 630, CARD_H = 880, API = 'https://api.tcgdex.net/v2/en';
const SPECIES = ["Bulbasaur","Ivysaur","Venusaur","Charmander","Charmeleon","Charizard","Squirtle","Wartortle","Blastoise","Caterpie","Metapod","Butterfree","Weedle","Kakuna","Beedrill","Pidgey","Pidgeotto","Pidgeot","Rattata","Raticate","Spearow","Fearow","Ekans","Arbok","Pikachu","Raichu","Sandshrew","Sandslash","Nidoran♀","Nidorina","Nidoqueen","Nidoran♂","Nidorino","Nidoking","Clefairy","Clefable","Vulpix","Ninetales","Jigglypuff","Wigglytuff","Zubat","Golbat","Oddish","Gloom","Vileplume","Paras","Parasect","Venonat","Venomoth","Diglett","Dugtrio","Meowth","Persian","Psyduck","Golduck","Mankey","Primeape","Growlithe","Arcanine","Poliwag","Poliwhirl","Poliwrath","Abra","Kadabra","Alakazam","Machop","Machoke","Machamp","Bellsprout","Weepinbell","Victreebel","Tentacool","Tentacruel","Geodude","Graveler","Golem","Ponyta","Rapidash","Slowpoke","Slowbro","Magnemite","Magneton","Farfetch’d","Doduo","Dodrio","Seel","Dewgong","Grimer","Muk","Shellder","Cloyster","Gastly","Haunter","Gengar","Onix","Drowzee","Hypno","Krabby","Kingler","Voltorb","Electrode","Exeggcute","Exeggutor","Cubone","Marowak","Hitmonlee","Hitmonchan","Lickitung","Koffing","Weezing","Rhyhorn","Rhydon","Chansey","Tangela","Kangaskhan","Horsea","Seadra","Goldeen","Seaking","Staryu","Starmie","Mr. Mime","Scyther","Jynx","Electabuzz","Magmar","Pinsir","Tauros","Magikarp","Gyarados","Lapras","Ditto","Eevee","Vaporeon","Jolteon","Flareon","Porygon","Omanyte","Omastar","Kabuto","Kabutops","Aerodactyl","Snorlax","Articuno","Zapdos","Moltres","Dratini","Dragonair","Dragonite","Mewtwo","Mew","Chikorita","Bayleef","Meganium","Cyndaquil","Quilava","Typhlosion","Totodile","Croconaw","Feraligatr","Sentret","Furret","Hoothoot","Noctowl","Ledyba","Ledian","Spinarak","Ariados","Crobat","Chinchou","Lanturn","Pichu","Cleffa","Igglybuff","Togepi","Togetic","Natu","Xatu","Mareep","Flaaffy","Ampharos","Bellossom","Marill","Azumarill","Sudowoodo","Politoed","Hoppip","Skiploom","Jumpluff","Aipom","Sunkern","Sunflora","Yanma","Wooper","Quagsire","Espeon","Umbreon","Murkrow","Slowking","Misdreavus","Unown","Wobbuffet","Girafarig","Pineco","Forretress","Dunsparce","Gligar","Steelix","Snubbull","Granbull","Qwilfish","Scizor","Shuckle","Heracross","Sneasel","Teddiursa","Ursaring","Slugma","Magcargo","Swinub","Piloswine","Corsola","Remoraid","Octillery","Delibird","Mantine","Skarmory","Houndour","Houndoom","Kingdra","Phanpy","Donphan","Porygon2","Stantler","Smeargle","Tyrogue","Hitmontop","Smoochum","Elekid","Magby","Miltank","Blissey","Raikou","Entei","Suicune","Larvitar","Pupitar","Tyranitar","Lugia","Ho-Oh","Celebi","Treecko","Grovyle","Sceptile","Torchic","Combusken","Blaziken","Mudkip","Marshtomp","Swampert","Poochyena","Mightyena","Zigzagoon","Linoone","Wurmple","Silcoon","Beautifly","Cascoon","Dustox","Lotad","Lombre","Ludicolo","Seedot","Nuzleaf","Shiftry","Taillow","Swellow","Wingull","Pelipper","Ralts","Kirlia","Gardevoir","Surskit","Masquerain","Shroomish","Breloom","Slakoth","Vigoroth","Slaking","Nincada","Ninjask","Shedinja","Whismur","Loudred","Exploud","Makuhita","Hariyama","Azurill","Nosepass","Skitty","Delcatty","Sableye","Mawile","Aron","Lairon","Aggron","Meditite","Medicham","Electrike","Manectric","Plusle","Minun","Volbeat","Illumise","Roselia","Gulpin","Swalot","Carvanha","Sharpedo","Wailmer","Wailord","Numel","Camerupt","Torkoal","Spoink","Grumpig","Spinda","Trapinch","Vibrava","Flygon","Cacnea","Cacturne","Swablu","Altaria","Zangoose","Seviper","Lunatone","Solrock","Barboach","Whiscash","Corphish","Crawdaunt","Baltoy","Claydol","Lileep","Cradily","Anorith","Armaldo","Feebas","Milotic","Castform","Kecleon","Shuppet","Banette","Duskull","Dusclops","Tropius","Chimecho","Absol","Wynaut","Snorunt","Glalie","Spheal","Sealeo","Walrein","Clamperl","Huntail","Gorebyss","Relicanth","Luvdisc","Bagon","Shelgon","Salamence","Beldum","Metang","Metagross","Regirock","Regice","Registeel","Latias","Latios","Kyogre","Groudon","Rayquaza","Jirachi","Deoxys","Turtwig","Grotle","Torterra","Chimchar","Monferno","Infernape","Piplup","Prinplup","Empoleon","Starly","Staravia","Staraptor","Bidoof","Bibarel","Kricketot","Kricketune","Shinx","Luxio","Luxray","Budew","Roserade","Cranidos","Rampardos","Shieldon","Bastiodon","Burmy","Wormadam","Mothim","Combee","Vespiquen","Pachirisu","Buizel","Floatzel","Cherubi","Cherrim","Shellos","Gastrodon","Ambipom","Drifloon","Drifblim","Buneary","Lopunny","Mismagius","Honchkrow","Glameow","Purugly","Chingling","Stunky","Skuntank","Bronzor","Bronzong","Bonsly","Mime Jr.","Happiny","Chatot","Spiritomb","Gible","Gabite","Garchomp","Munchlax","Riolu","Lucario","Hippopotas","Hippowdon","Skorupi","Drapion","Croagunk","Toxicroak","Carnivine","Finneon","Lumineon","Mantyke","Snover","Abomasnow","Weavile","Magnezone","Lickilicky","Rhyperior","Tangrowth","Electivire","Magmortar","Togekiss","Yanmega","Leafeon","Glaceon","Gliscor","Mamoswine","Porygon-Z","Gallade","Probopass","Dusknoir","Froslass","Rotom","Uxie","Mesprit","Azelf","Dialga","Palkia","Heatran","Regigigas","Giratina","Cresselia","Phione","Manaphy","Darkrai","Shaymin","Arceus","Victini","Snivy","Servine","Serperior","Tepig","Pignite","Emboar","Oshawott","Dewott","Samurott","Patrat","Watchog","Lillipup","Herdier","Stoutland","Purrloin","Liepard","Pansage","Simisage","Pansear","Simisear","Panpour","Simipour","Munna","Musharna","Pidove","Tranquill","Unfezant","Blitzle","Zebstrika","Roggenrola","Boldore","Gigalith","Woobat","Swoobat","Drilbur","Excadrill","Audino","Timburr","Gurdurr","Conkeldurr","Tympole","Palpitoad","Seismitoad","Throh","Sawk","Sewaddle","Swadloon","Leavanny","Venipede","Whirlipede","Scolipede","Cottonee","Whimsicott","Petilil","Lilligant","Basculin","Sandile","Krokorok","Krookodile","Darumaka","Darmanitan","Maractus","Dwebble","Crustle","Scraggy","Scrafty","Sigilyph","Yamask","Cofagrigus","Tirtouga","Carracosta","Archen","Archeops","Trubbish","Garbodor","Zorua","Zoroark","Minccino","Cinccino","Gothita","Gothorita","Gothitelle","Solosis","Duosion","Reuniclus","Ducklett","Swanna","Vanillite","Vanillish","Vanilluxe","Deerling","Sawsbuck","Emolga","Karrablast","Escavalier","Foongus","Amoonguss","Frillish","Jellicent","Alomomola","Joltik","Galvantula","Ferroseed","Ferrothorn","Klink","Klang","Klinklang","Tynamo","Eelektrik","Eelektross","Elgyem","Beheeyem","Litwick","Lampent","Chandelure","Axew","Fraxure","Haxorus","Cubchoo","Beartic","Cryogonal","Shelmet","Accelgor","Stunfisk","Mienfoo","Mienshao","Druddigon","Golett","Golurk","Pawniard","Bisharp","Bouffalant","Rufflet","Braviary","Vullaby","Mandibuzz","Heatmor","Durant","Deino","Zweilous","Hydreigon","Larvesta","Volcarona","Cobalion","Terrakion","Virizion","Tornadus","Thundurus","Reshiram","Zekrom","Landorus","Kyurem","Keldeo","Meloetta","Genesect","Chespin","Quilladin","Chesnaught","Fennekin","Braixen","Delphox","Froakie","Frogadier","Greninja","Bunnelby","Diggersby","Fletchling","Fletchinder","Talonflame","Scatterbug","Spewpa","Vivillon","Litleo","Pyroar","Flabébé","Floette","Florges","Skiddo","Gogoat","Pancham","Pangoro","Furfrou","Espurr","Meowstic","Honedge","Doublade","Aegislash","Spritzee","Aromatisse","Swirlix","Slurpuff","Inkay","Malamar","Binacle","Barbaracle","Skrelp","Dragalge","Clauncher","Clawitzer","Helioptile","Heliolisk","Tyrunt","Tyrantrum","Amaura","Aurorus","Sylveon","Hawlucha","Dedenne","Carbink","Goomy","Sliggoo","Goodra","Klefki","Phantump","Trevenant","Pumpkaboo","Gourgeist","Bergmite","Avalugg","Noibat","Noivern","Xerneas","Yveltal","Zygarde","Diancie","Hoopa","Volcanion","Rowlet","Dartrix","Decidueye","Litten","Torracat","Incineroar","Popplio","Brionne","Primarina","Pikipek","Trumbeak","Toucannon","Yungoos","Gumshoos","Grubbin","Charjabug","Vikavolt","Crabrawler","Crabominable","Oricorio","Cutiefly","Ribombee","Rockruff","Lycanroc","Wishiwashi","Mareanie","Toxapex","Mudbray","Mudsdale","Dewpider","Araquanid","Fomantis","Lurantis","Morelull","Shiinotic","Salandit","Salazzle","Stufful","Bewear","Bounsweet","Steenee","Tsareena","Comfey","Oranguru","Passimian","Wimpod","Golisopod","Sandygast","Palossand","Pyukumuku","Type: Null","Silvally","Minior","Komala","Turtonator","Togedemaru","Mimikyu","Bruxish","Drampa","Dhelmise","Jangmo-o","Hakamo-o","Kommo-o","Tapu Koko","Tapu Lele","Tapu Bulu","Tapu Fini","Cosmog","Cosmoem","Solgaleo","Lunala","Nihilego","Buzzwole","Pheromosa","Xurkitree","Celesteela","Kartana","Guzzlord","Necrozma","Magearna","Marshadow","Poipole","Naganadel","Stakataka","Blacephalon","Zeraora","Meltan","Melmetal","Grookey","Thwackey","Rillaboom","Scorbunny","Raboot","Cinderace","Sobble","Drizzile","Inteleon","Skwovet","Greedent","Rookidee","Corvisquire","Corviknight","Blipbug","Dottler","Orbeetle","Nickit","Thievul","Gossifleur","Eldegoss","Wooloo","Dubwool","Chewtle","Drednaw","Yamper","Boltund","Rolycoly","Carkol","Coalossal","Applin","Flapple","Appletun","Silicobra","Sandaconda","Cramorant","Arrokuda","Barraskewda","Toxel","Toxtricity","Sizzlipede","Centiskorch","Clobbopus","Grapploct","Sinistea","Polteageist","Hatenna","Hattrem","Hatterene","Impidimp","Morgrem","Grimmsnarl","Obstagoon","Perrserker","Cursola","Sirfetch’d","Mr. Rime","Runerigus","Milcery","Alcremie","Falinks","Pincurchin","Snom","Frosmoth","Stonjourner","Eiscue","Indeedee","Morpeko","Cufant","Copperajah","Dracozolt","Arctozolt","Dracovish","Arctovish","Duraludon","Dreepy","Drakloak","Dragapult","Zacian","Zamazenta","Eternatus","Kubfu","Urshifu","Zarude","Regieleki","Regidrago","Glastrier","Spectrier","Calyrex","Wyrdeer","Kleavor","Ursaluna","Basculegion","Sneasler","Overqwil","Enamorus","Sprigatito","Floragato","Meowscarada","Fuecoco","Crocalor","Skeledirge","Quaxly","Quaxwell","Quaquaval","Lechonk","Oinkologne","Tarountula","Spidops","Nymble","Lokix","Pawmi","Pawmo","Pawmot","Tandemaus","Maushold","Fidough","Dachsbun","Smoliv","Dolliv","Arboliva","Squawkabilly","Nacli","Naclstack","Garganacl","Charcadet","Armarouge","Ceruledge","Tadbulb","Bellibolt","Wattrel","Kilowattrel","Maschiff","Mabosstiff","Shroodle","Grafaiai","Bramblin","Brambleghast","Toedscool","Toedscruel","Klawf","Capsakid","Scovillain","Rellor","Rabsca","Flittle","Espathra","Tinkatink","Tinkatuff","Tinkaton","Wiglett","Wugtrio","Bombirdier","Finizen","Palafin","Varoom","Revavroom","Cyclizar","Orthworm","Glimmet","Glimmora","Greavard","Houndstone","Flamigo","Cetoddle","Cetitan","Veluza","Dondozo","Tatsugiri","Annihilape","Clodsire","Farigiraf","Dudunsparce","Kingambit","Great Tusk","Scream Tail","Brute Bonnet","Flutter Mane","Slither Wing","Sandy Shocks","Iron Treads","Iron Bundle","Iron Hands","Iron Jugulis","Iron Moth","Iron Thorns","Frigibax","Arctibax","Baxcalibur","Gimmighoul","Gholdengo","Wo-Chien","Chien-Pao","Ting-Lu","Chi-Yu","Roaring Moon","Iron Valiant","Koraidon","Miraidon","Walking Wake","Iron Leaves","Dipplin","Poltchageist","Sinistcha","Okidogi","Munkidori","Fezandipiti","Ogerpon","Archaludon","Hydrapple","Gouging Fire","Raging Bolt","Iron Boulder","Iron Crown","Terapagos","Pecharunt"];
const norm = s => (s || '').toLowerCase().replace(/[’`]/g, "'").replace(/[^a-z0-9éè♀♂' -]/g, ' ').replace(/\s+/g, ' ').trim();
const byEn = new Map(SPECIES.map(n => [norm(n), n]));
function speciesOf(text) {
  const w = norm(text).split(' ');
  for (let len = 3; len >= 1; len--) for (let i = 0; i + len <= w.length; i++) { const hit = byEn.get(w.slice(i, i + len).join(' ')); if (hit) return hit; }
  return null;
}
const isPocket = id => /^(A\d|B\d|P-A)/i.test(id || '');
const cache = new Map();
async function getJSON(path) {
  if (cache.has(path)) return cache.get(path);
  const p = (async () => {
    for (let k = 0; ; k++) {
      const ctl = new AbortController(), tm = setTimeout(() => ctl.abort(), 12000);
      try { const r = await fetch(API + path, { signal: ctl.signal }); if (r.status === 404) return null; if (!r.ok) throw new Error('서버 응답 ' + r.status); return await r.json(); }
      catch (e) { if (k >= 2) throw e.name === 'AbortError' ? new Error('응답이 너무 느려요') : e; await new Promise(r => setTimeout(r, 700 * (k + 1))); }
      finally { clearTimeout(tm); }
    }
  })();
  cache.set(path, p); p.catch(() => cache.delete(path));
  return p;
}
const imgOf = c => c?.image ? c.image + '/low.webp' : '';

// ---------- 스타일 (한 번만) ----------
function css() {
  if (document.getElementById('scanCss')) return;
  const s = document.createElement('style'); s.id = 'scanCss';
  s.textContent = `.scanbox{position:relative;width:100%;max-width:440px;margin:0 auto;aspect-ratio:3/4;background:#000;border-radius:18px;overflow:hidden;touch-action:none}
.scanbox video,.scanbox .shot{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}.scanbox .shot{object-fit:contain}
.guide{position:absolute;left:50%;top:47%;height:78%;aspect-ratio:63/88;transform:translate(-50%,-50%);border-radius:4.6%/3.3%;box-shadow:0 0 0 9999px rgba(0,0,0,.58);transition:box-shadow .3s}
.guide.lock{box-shadow:0 0 0 9999px rgba(0,0,0,.75),0 0 24px 4px #37e39a inset}
.guide b{position:absolute;width:16%;height:11.5%;border:4px solid rgba(255,255,255,.9);transition:border-color .2s}
.guide b:nth-child(1){left:-3px;top:-3px;border-right:0;border-bottom:0;border-top-left-radius:14px}
.guide b:nth-child(2){right:-3px;top:-3px;border-left:0;border-bottom:0;border-top-right-radius:14px}
.guide b:nth-child(3){left:-3px;bottom:-3px;border-right:0;border-top:0;border-bottom-left-radius:14px}
.guide b:nth-child(4){right:-3px;bottom:-3px;border-left:0;border-top:0;border-bottom-right-radius:14px}
.guide.t b:nth-child(1),.guide.t b:nth-child(2){border-top-color:#37e39a}.guide.bm b:nth-child(3),.guide.bm b:nth-child(4){border-bottom-color:#37e39a}
.guide.l b:nth-child(1),.guide.l b:nth-child(3){border-left-color:#37e39a}.guide.r b:nth-child(2),.guide.r b:nth-child(4){border-right-color:#37e39a}
.hold{position:absolute;left:10%;right:10%;bottom:-16px;height:5px;border-radius:9px;background:rgba(255,255,255,.2);overflow:hidden}.hold i{display:block;height:100%;width:0;background:#37e39a;transition:width .12s}
.scanMsg{position:absolute;left:0;right:0;bottom:14px;text-align:center;color:#fff;font-weight:700;text-shadow:0 1px 4px #000;font-size:.95rem;padding:0 12px}
.flash{position:absolute;inset:0;background:#fff;opacity:0;pointer-events:none}.flash.go{animation:scflash .45s ease-out}@keyframes scflash{0%{opacity:.95}100%{opacity:0}}
.laser{position:absolute;left:6%;right:6%;height:3px;top:10%;background:linear-gradient(90deg,transparent,#38f6ff,transparent);box-shadow:0 0 14px 3px #38f6ff;animation:sclaser 1.1s ease-in-out infinite alternate}@keyframes sclaser{to{top:88%}}
.scanBtns{display:flex;gap:8px;justify-content:center;margin-top:10px;flex-wrap:wrap}
.shutter{width:60px;height:60px;border-radius:50%;border:5px solid var(--ink,#111);background:var(--accent,#2f6fd0);padding:0}`;
  document.head.append(s);
}

// ---------- 카메라 ----------
let cam = null, loop = 0, capturing = false, cur = null;
function stop() { cancelAnimationFrame(loop); loop = 0; if (cam) { cam.getTracks().forEach(t => t.stop()); cam = null; } cur = null; }
document.addEventListener('visibilitychange', () => { if (document.hidden) stop(); });
// host 안에 스캔 화면을 그린다. 찍히면 onShot(카드 캔버스) — 캔버스는 630×880, .hi에 고해상도본
async function open(host, { hint = '카드를 어두운 바닥에 놓고 틀에 맞춰주세요. 자동으로 찍혀요.', onShot }) {
  stop(); css();
  host.innerHTML = `<div class="scanbox" data-sbox><video playsinline muted autoplay></video>
      <div class="guide" data-guide><b></b><b></b><b></b><b></b><div class="hold"><i data-hold></i></div></div>
      <div class="scanMsg" data-msg>카메라 준비 중…</div><div class="flash" data-flash></div></div>
    <p class="muted" style="text-align:center;margin:8px 0 0;font-size:.82rem">${hint}</p>
    <div class="scanBtns"><button type="button" class="ghost" data-up>🖼️ 사진에서</button><button type="button" class="shutter" data-shut aria-label="촬영"></button></div>
    <input type="file" accept="image/*" capture="environment" hidden data-file>`;
  const q = s => host.querySelector(`[data-${s}]`);
  const me = cur = { host, q, onShot, done: false };
  q('up').onclick = () => q('file').click();
  q('file').onchange = e => { const f = e.target.files[0]; if (f) fromFile(me, f); };
  q('shut').onclick = () => cam ? capture(me, 0) : q('file').click();
  loadOcr().catch(() => {});
  try { cam = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment', width: { ideal: 2560 }, height: { ideal: 1920 } }, audio: false }); }
  catch { q('msg').textContent = '카메라를 쓸 수 없어요 · 🖼️ 사진에서 불러와 주세요'; return; }
  if (cur !== me || !host.isConnected) return stop();
  const vid = q('sbox').querySelector('video'); vid.srcObject = cam; await vid.play().catch(() => {});
  q('msg').textContent = '카드를 틀에 맞춰주세요';
  watch(me, vid);
}
function guideInVideo(me, vid) {
  const box = me.q('sbox').getBoundingClientRect(), g = me.q('guide').getBoundingClientRect();
  const s = Math.max(box.width / vid.videoWidth, box.height / vid.videoHeight);
  const ox = (box.width - vid.videoWidth * s) / 2, oy = (box.height - vid.videoHeight * s) / 2;
  return { x: (g.left - box.left - ox) / s, y: (g.top - box.top - oy) / s, w: g.width / s, h: g.height / s };
}
const EDGE_TH = 20;
function findEdges(d, w, h, gd) {
  const cg = (a, b) => (Math.abs(d[a] - d[b]) + Math.abs(d[a + 1] - d[b + 1]) + Math.abs(d[a + 2] - d[b + 2])) / 3;
  const P = (x, y) => (y * w + x) * 4;
  const cy = y => Math.min(h - 2, Math.max(1, y)), cx = x => Math.min(w - 2, Math.max(1, x));
  const rowScore = y => { let s = 0, n = 0; for (let x = cx(gd.x + gd.w * .2 | 0); x < cx(gd.x + gd.w * .8 | 0); x++, n++) s += cg(P(x, y - 1), P(x, y + 1)); return n ? s / n : 0; };
  const colScore = x => { let s = 0, n = 0; for (let y = cy(gd.y + gd.h * .2 | 0); y < cy(gd.y + gd.h * .8 | 0); y++, n++) s += cg(P(x - 1, y), P(x + 1, y)); return n ? s / n : 0; };
  const scan = (from, to, fn, clamp) => {
    const st = from < to ? 1 : -1, vals = [];
    for (let v = from; v !== to; v += st) { const c = clamp(v); vals.push([c, fn(c)]); }
    const max = Math.max(...vals.map(v => v[1]));
    const pick = vals.find(([, sc]) => sc >= Math.max(EDGE_TH, max * .6)) || vals.reduce((a, b) => b[1] > a[1] ? b : a);
    return { pos: pick[0], score: pick[1] };
  };
  const oy = Math.round(gd.h * .14), iy = Math.round(gd.h * .2), ox = Math.round(gd.w * .14), ix = Math.round(gd.w * .2);
  const T = Math.round(gd.y), B = Math.round(gd.y + gd.h), L = Math.round(gd.x), R = Math.round(gd.x + gd.w);
  return { top: scan(T - oy, T + iy, rowScore, cy), bottom: scan(B + oy, B - iy, rowScore, cy), left: scan(L - ox, L + ix, colScore, cx), right: scan(R + ox, R - ix, colScore, cx) };
}
function clampReg(reg, src) {
  const sw = src.videoWidth || src.width, sh = src.videoHeight || src.height;
  const x = Math.max(0, reg.x), y = Math.max(0, reg.y);
  return { x, y, w: Math.min(sw, reg.x + reg.w) - x, h: Math.min(sh, reg.y + reg.h) - y };
}
let fcv = null;
function findCard(src, reg, gv, angles, W = 180) {
  reg = clampReg(reg, src);
  const k = W / reg.w, H = Math.round(reg.h * k), c = { x: reg.x + reg.w / 2, y: reg.y + reg.h / 2 };
  const cv = fcv ??= document.createElement('canvas'); cv.width = W; cv.height = H;
  const x = cv.getContext('2d', { willReadFrequently: true });
  const gd = { x: (gv.x - reg.x) * k, y: (gv.y - reg.y) * k, w: gv.w * k, h: gv.h * k };
  let best = null;
  for (const a of angles) {
    x.setTransform(1, 0, 0, 1, 0, 0); x.fillStyle = '#000'; x.fillRect(0, 0, W, H);
    x.setTransform(k, 0, 0, k, 0, 0); x.translate(-reg.x, -reg.y); x.translate(c.x, c.y); x.rotate(-a * Math.PI / 180); x.translate(-c.x, -c.y);
    x.drawImage(src, 0, 0);
    const d = x.getImageData(0, 0, W, H).data, e = findEdges(d, W, H, gd);
    const sides = [e.top, e.bottom, e.left, e.right], ok = sides.map(v => v.score > EDGE_TH);
    const w = e.right.pos - e.left.pos, h = e.bottom.pos - e.top.pos, ar = h / w;
    const shape = w > gd.w * .5 && ar > 1.22 && ar < 1.58;
    const score = sides.reduce((t, v) => t + Math.min(v.score, 90), 0) * (shape ? 1 : .5);
    if (!best || score > best.score) best = { a, e, ok, shape, score, d };
  }
  best.rect = { x: reg.x + best.e.left.pos / k, y: reg.y + best.e.top.pos / k, w: (best.e.right.pos - best.e.left.pos) / k, h: (best.e.bottom.pos - best.e.top.pos) / k };
  best.c = c;
  return best;
}
const refine = a => [a - 2, a - 1, a, a + 1, a + 2];
function warp(src, f, W, H) {
  const o = document.createElement('canvas'); o.width = W; o.height = H;
  const x = o.getContext('2d'); x.imageSmoothingQuality = 'high';
  x.scale(W / f.rect.w, H / f.rect.h); x.translate(-f.rect.x, -f.rect.y);
  x.translate(f.c.x, f.c.y); x.rotate(-f.a * Math.PI / 180); x.translate(-f.c.x, -f.c.y);
  x.drawImage(src, 0, 0);
  return o;
}
function cardShots(src, f) {
  const card = warp(src, f, CARD_W, CARD_H);
  const hw = Math.max(900, Math.round(f.rect.w));
  card.hi = warp(src, f, hw, Math.round(hw * CARD_H / CARD_W));
  return card;
}
function watch(me, vid) {
  let prev = null, steady = 0, last = 0, lastA = 0;
  const guide = me.q('guide'), bar = me.q('hold'), msg = me.q('msg');
  const step = t => {
    if (cur !== me) return;
    loop = requestAnimationFrame(step);
    if (t - last < 120 || !vid.videoWidth) return; last = t;
    const gv = guideInVideo(me, vid), m = .22;
    const reg = { x: gv.x - gv.w * m, y: gv.y - gv.h * m, w: gv.w * (1 + 2 * m), h: gv.h * (1 + 2 * m) };
    const f = findCard(vid, reg, gv, [...new Set([-8, -4, 0, 4, 8, lastA])], 160);
    lastA = f.a;
    const [t0, b0, l0, r0] = f.ok;
    for (const [cl, v] of [['t', t0], ['bm', b0], ['l', l0], ['r', r0]]) guide.classList.toggle(cl, v);
    let diff = 99;
    if (prev && prev.length === f.d.length) { diff = 0; for (let i = 0; i < f.d.length; i += 12) diff += Math.abs(f.d[i] - prev[i]); diff /= f.d.length / 12; }
    prev = f.d;
    const sides = f.ok.filter(Boolean).length, found = sides === 4 && f.shape;
    if (found && diff < 8) steady++; else steady = Math.max(0, steady - 2);
    bar.style.width = Math.min(100, steady / 6 * 100) + '%';
    msg.textContent = !found ? (sides >= 2 ? '카드 네 변이 틀 안에 다 보이게 해주세요' : '카드를 틀에 맞춰주세요') : diff >= 8 ? '흔들리지 않게 잡아주세요' : '좋아요, 그대로…';
    if (steady >= 6) capture(me, f.a);
  };
  loop = requestAnimationFrame(step);
}
async function capture(me, angle = 0) {
  const vid = me.q('sbox')?.querySelector('video');
  if (!vid || !vid.videoWidth || capturing) return;
  capturing = true;
  cancelAnimationFrame(loop); loop = 0;
  me.q('flash').classList.add('go'); me.q('guide').classList.add('lock');
  try { navigator.vibrate?.(40); } catch {}
  const gv = guideInVideo(me, vid), m = .22;
  const fr = document.createElement('canvas'); fr.width = vid.videoWidth; fr.height = vid.videoHeight; fr.getContext('2d').drawImage(vid, 0, 0);
  let src = fr, g = gv;
  try {
    if (window.ImageCapture && cam) {
      const photo = await createImageBitmap(await new ImageCapture(cam.getVideoTracks()[0]).takePhoto());
      const sx = photo.width / vid.videoWidth, sy = photo.height / vid.videoHeight;
      if (Math.abs(sx - sy) / sx < .05 && sx > 1.1) { src = photo; g = { x: gv.x * sx, y: gv.y * sy, w: gv.w * sx, h: gv.h * sy }; }
    }
  } catch {}
  if (cam) { cam.getTracks().forEach(t => t.stop()); cam = null; }
  const reg = { x: g.x - g.w * m, y: g.y - g.h * m, w: g.w * (1 + 2 * m), h: g.h * (1 + 2 * m) };
  let f = findCard(src, reg, g, refine(angle), 360);
  if (!f.shape && src !== fr) { src = fr; g = gv; f = findCard(fr, { x: gv.x - gv.w * m, y: gv.y - gv.h * m, w: gv.w * (1 + 2 * m), h: gv.h * (1 + 2 * m) }, gv, refine(angle), 360); }
  if (!f.shape) f = { a: 0, rect: g, c: { x: g.x + g.w / 2, y: g.y + g.h / 2 } };
  capturing = false;
  deliver(me, cardShots(src, f));
}
async function fromFile(me, file) {
  if (cam) { cam.getTracks().forEach(t => t.stop()); cam = null; }
  cancelAnimationFrame(loop); loop = 0;
  const img = await createImageBitmap(file);
  const reg = { x: 0, y: 0, w: img.width, h: img.height };
  let best = null;
  for (const s of [.85, .7, .55]) {
    let gh = img.height * s, gw = gh * CARD_W / CARD_H;
    if (gw > img.width * s) { gw = img.width * s; gh = gw * CARD_H / CARD_W; }
    const gv = { x: (img.width - gw) / 2, y: (img.height - gh) / 2, w: gw, h: gh };
    const f = findCard(img, reg, gv, [-9, -6, -3, 0, 3, 6, 9], 240);
    if (f.shape && f.ok.every(Boolean) && (!best || f.score > best.score)) best = { ...f, gv };
  }
  let f = best ? findCard(img, reg, best.gv, refine(best.a), 480) : null;
  if (!f || !f.shape) f = { a: 0, rect: reg, c: { x: img.width / 2, y: img.height / 2 } };
  deliver(me, cardShots(img, f));
}
function deliver(me, card) {
  if (me.done) return; me.done = true;
  const box = me.q('sbox');
  if (box) {
    box.querySelector('video')?.remove(); me.q('guide')?.classList.add('hidden');
    const shot = document.createElement('canvas'); shot.width = CARD_W; shot.height = CARD_H; shot.getContext('2d').drawImage(card, 0, 0); shot.className = 'shot';
    box.prepend(shot); me.q('msg').textContent = '찍었어요';
    box.style.maxWidth = '200px';   // 찍은 뒤엔 작게 → 판독 결과가 바로 보이게
  }
  me.host.querySelector('.scanBtns')?.remove(); me.host.querySelector('p.muted')?.remove();
  me.onShot?.(card, {
    busy: t => { if (!box) return; me.q('msg').textContent = t; if (!box.querySelector('.laser')) box.insertAdjacentHTML('beforeend', '<div class="laser"></div>'); },
    idle: t => { if (!box) return; me.q('msg').textContent = t || ''; box.querySelector('.laser')?.remove(); }
  });
}

// ---------- 판독 (OCR) ----------
let ocrP = null;
function loadOcr() {
  return ocrP ??= new Promise((ok, no) => {
    if (window.Tesseract) return ok();
    const s = document.createElement('script');
    s.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';
    s.onload = ok; s.onerror = () => { ocrP = null; no(new Error('OCR 엔진을 불러오지 못했어요')); };
    document.head.append(s);
  }).then(() => Tesseract.createWorker('eng', 1, {
    workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/worker.min.js',
    corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@5.1.1',
    langPath: 'https://cdn.jsdelivr.net/npm/@tesseract.js-data/eng/4.0.0_best_int'
  })).catch(e => { ocrP = null; throw e; });
}
function strip(card, y0, y1, x0 = 0, x1 = 1, target = 1400) {
  const W = card.width, H = card.height, sw = (x1 - x0) * W, sh = (y1 - y0) * H, sc = target / sw;
  const c = document.createElement('canvas'); c.width = target; c.height = Math.round(sh * sc);
  const ctx = c.getContext('2d', { willReadFrequently: true });
  ctx.imageSmoothingQuality = 'high'; ctx.filter = 'grayscale(1) contrast(1.8)';
  ctx.drawImage(card, x0 * W, y0 * H, sw, sh, 0, 0, c.width, c.height);
  return c;
}
function parseNumber(text, officials) {
  const t = (text || '').replace(/[|\\]/g, '/').replace(/\s+/g, ' ');
  const m = t.match(/(?:^|[^0-9A-Z])([A-Z]{2})?(\d{1,3})\s*\/\s*([A-Z]{2})?(\d{2,3})(?!\d)/);
  if (m) return { num: m[1] ? m[1] + m[2] : String(+m[2]), total: +m[4] };
  if (officials) for (const run of t.match(/\d{4,7}/g) || []) {
    for (const skip of [1, 0]) for (let i = 1; i <= 3 && i < run.length - 1; i++) {
      if (skip && !/[17]/.test(run[i])) continue;
      const a = run.slice(0, i), b = run.slice(i + skip);
      if (b.length >= 2 && b.length <= 3 && officials.has(+b) && +a >= 1 && +a <= +b + 120) return { num: String(+a), total: +b, guess: true };
    }
  }
  return null;
}
async function ocrText(w, canvas, params) { await w.setParameters(params); return (await w.recognize(canvas)).data.text; }
const P_TEXT = { tessedit_pageseg_mode: '11', tessedit_char_whitelist: '' };
const P_NUM = { tessedit_pageseg_mode: '11', tessedit_char_whitelist: '0123456789/TGSVH' };
async function readCard(card) {
  const w = await loadOcr(), hi = card.hi || card;
  const officials = new Set(((await getJSON('/sets').catch(() => [])) || []).map(x => x.cardCount?.official).filter(Boolean));
  const top = await ocrText(w, strip(hi, .015, .13, .03, .97, 1600), P_TEXT);
  let no = null, numText = '';
  for (const [x0, x1] of [[0, .5], [.5, 1]]) {
    const tx = await ocrText(w, strip(hi, .88, .99, x0, x1, 1500), P_NUM);
    numText += ' ' + tx;
    if ((no = parseNumber(tx, officials))) break;
  }
  let sp = speciesOf(top);
  if (!sp || !no) {
    const all = await ocrText(w, strip(hi, 0, 1, 0, 1, 1400), P_TEXT);
    sp = sp || speciesOf(all); no = no || parseNumber(all, officials);
  }
  return { sp, no, name: top.replace(/\s+/g, ' ').trim(), text: (top + ' ' + numText).replace(/\s+/g, ' ').trim() };
}

// ---------- 그림 지문 ----------
// 카드 그림 영역을 16×12 색 격자로 줄이고 채널별로 밝기·대비를 맞춘다 (조명 차이에 덜 민감)
function artSig(src, W, H) {
  const c = document.createElement('canvas'); c.width = 16; c.height = 12;
  const x = c.getContext('2d', { willReadFrequently: true });
  x.drawImage(src, W * .08, H * .1, W * .84, H * .42, 0, 0, 16, 12);
  const d = x.getImageData(0, 0, 16, 12).data, n = 16 * 12, out = new Float32Array(n * 3);
  for (let ch = 0; ch < 3; ch++) {
    let m = 0, v = 0;
    for (let i = 0; i < n; i++) m += d[i * 4 + ch];
    m /= n;
    for (let i = 0; i < n; i++) v += (d[i * 4 + ch] - m) ** 2;
    const sd = Math.sqrt(v / n) || 1;
    for (let i = 0; i < n; i++) out[i * 3 + ch] = (d[i * 4 + ch] - m) / sd;
  }
  return out;
}
const sigDist = (a, b) => { let s = 0; for (let i = 0; i < a.length; i++) s += Math.abs(a[i] - b[i]); return s / a.length; };
// 지문용 그림 격자: 카드 윗부분 넓게 24×18 (가장자리 검출이 조금 어긋나도 비교 때 밀어서 맞춤)
const FG_W = 24, FG_H = 18;
function fingerGrid(src, W, H) {
  const c = document.createElement('canvas'); c.width = FG_W; c.height = FG_H;
  const x = c.getContext('2d', { willReadFrequently: true });
  x.drawImage(src, W * .04, H * .05, W * .92, H * .55, 0, 0, FG_W, FG_H);
  const d = x.getImageData(0, 0, FG_W, FG_H).data, n = FG_W * FG_H, out = new Float32Array(n * 3);
  for (let ch = 0; ch < 3; ch++) {
    let m = 0, v = 0;
    for (let i = 0; i < n; i++) m += d[i * 4 + ch];
    m /= n;
    for (let i = 0; i < n; i++) v += (d[i * 4 + ch] - m) ** 2;
    const sd = Math.sqrt(v / n) || 1;
    for (let i = 0; i < n; i++) out[i * 3 + ch] = (d[i * 4 + ch] - m) / sd;
  }
  return out;
}
// a의 가운데 창(가장자리 S칸 제외)을 b 위에서 ±S칸 밀어 보며 가장 작은 거리 (창마다 밝기·대비 다시 맞춤)
function slideDist(a, b, S = 3) {
  const w = FG_W - 2 * S, h = FG_H - 2 * S;
  const win = (g, ox, oy) => {
    const out = new Float32Array(w * h * 3);
    for (let ch = 0; ch < 3; ch++) {
      let m = 0, v = 0;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) m += g[((y + oy) * FG_W + x + ox) * 3 + ch];
      m /= w * h;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) v += (g[((y + oy) * FG_W + x + ox) * 3 + ch] - m) ** 2;
      const sd = Math.sqrt(v / (w * h)) || 1;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) out[(y * w + x) * 3 + ch] = (g[((y + oy) * FG_W + x + ox) * 3 + ch] - m) / sd;
    }
    return out;
  };
  const A = win(a, S, S);
  let best = Infinity;
  for (let dy = -S; dy <= S; dy++) for (let dx = -S; dx <= S; dx++) best = Math.min(best, sigDist(A, win(b, S + dx, S + dy)));
  return best;
}
// 저장용: 소수 격자 → 8비트 정수 → base64 (약 770자)
const packSig = sig => { const b = new Int8Array(sig.length); sig.forEach((v, i) => b[i] = Math.max(-127, Math.min(127, Math.round(v * 32)))); return btoa(String.fromCharCode(...new Uint8Array(b.buffer))); };
const unpackSig = s => { const u = Uint8Array.from(atob(s), ch => ch.charCodeAt(0)); return Float32Array.from(new Int8Array(u.buffer), v => v / 32); };
function loadImg(url) {
  return new Promise((ok, no) => { if (!url) return no(new Error('no image')); const i = new Image(); i.crossOrigin = 'anonymous'; i.onload = () => ok(i); i.onerror = no; i.src = url; setTimeout(no, 8000); });
}
async function sigOfUrl(url) { const im = await loadImg(url); return artSig(im, im.naturalWidth, im.naturalHeight); }
async function rankByArt(shot, cands) {
  const me = artSig(shot, shot.width, shot.height);
  const res = await Promise.all(cands.slice(0, 60).map(async c => { try { return { c, d: sigDist(me, await sigOfUrl(imgOf(c))) }; } catch { return { c, d: Infinity }; } }));
  return res.sort((a, b) => a.d - b.d);
}

// ---------- 카드 찾기 ----------
function nameScore(name, text) {
  const toks = norm(name).replace(/'/g, '').split(' ').filter(t => t.length > 1 && !['ex', 'gx', 'v'].includes(t));
  const T = norm(text).replace(/'/g, '');
  return toks.length ? toks.filter(t => T.includes(t)).length / toks.length : 0;
}
async function byText(info) {
  const { sp, no } = info, text = info.name || info.text || '';
  if (no) {
    const sets = no.total ? ((await getJSON('/sets')) || []).filter(x => !isPocket(x.id) && x.cardCount?.official === no.total).slice(-20) : [];
    const ids = [...new Set(sets.flatMap(x => [`${x.id}-${no.num}`, `${x.id}-${no.num.padStart(3, '0')}`]))];
    const list = (await Promise.all(ids.map(id => getJSON('/cards/' + encodeURIComponent(id)).catch(() => null)))).filter(Boolean);
    list.sort((a, b) => nameScore(b.name, text) - nameScore(a.name, text));
    if (list.length) {
      const top = nameScore(list[0].name, text), second = list[1] ? nameScore(list[1].name, text) : -1;
      const sure = top >= .99 && top > second || (list.length === 1 && (top >= .5 || (sp && speciesOf(list[0].name) === sp)));
      return { list, sure };
    }
  }
  if (sp) {
    const token = norm(sp).split(' ').sort((a, b) => b.length - a.length)[0].replace(/'/g, '');
    const re = new RegExp(`(^|[^a-z])${norm(sp).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z]|$)`);
    const briefs = ((await getJSON('/cards?name=' + encodeURIComponent(token))) || []).filter(c => !isPocket(c.id) && re.test(norm(c.name)));
    return { list: briefs.map(b => ({ ...b, s: nameScore(b.name, text) })).sort((a, b) => b.s - a.s).slice(0, 60), sure: false };
  }
  return { list: [], sure: false };
}
// 찍은 카드 → { list: 후보(TCGdex 카드/요약), sure: 자동 확정 여부, info: 읽은 정보 }
async function identify(card) {
  let info;
  try { info = await readCard(card); } catch (e) { info = { sp: null, no: null, text: '', err: e.message }; }
  let r = { list: [], sure: false };
  try { if (info.sp || info.no) r = await byText(info); } catch (e) { info.err = e.message; }
  if (!r.sure && r.list.length > 1) {
    const ranked = await rankByArt(card, r.list), [a, b] = ranked;
    if (a && isFinite(a.d)) {
      r.list = [...ranked.map(x => x.c), ...r.list.filter(c => !ranked.some(x => x.c === c))];
      if (a.d < .75 && (!b || !isFinite(b.d) || a.d < b.d * .65)) r.sure = true;
    }
  }
  return { ...r, info };
}
const detail = id => getJSON('/cards/' + encodeURIComponent(id));
// 시세(원): TCGplayer USD ×1400, 없으면 Cardmarket EUR ×1600
function krwOf(c) {
  const tp = c?.pricing?.tcgplayer || {}, usd = ['normal', 'holofoil', 'reverse-holofoil'].map(k => tp[k]?.marketPrice).find(v => v != null);
  const eur = c?.pricing?.cardmarket?.trend;
  return usd != null ? Math.round(usd * 1400) : eur != null ? Math.round(eur * 1600) : null;
}

// ---------- 컨디션 등급 ----------
function pixelsOf(cv) {
  const d = cv.getContext('2d', { willReadFrequently: true }).getImageData(0, 0, CARD_W, CARD_H).data;
  return (x, y) => { const i = (y * CARD_W + x) * 4; return [d[i], d[i + 1], d[i + 2]]; };
}
const cdist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const luma = c => c[0] * .299 + c[1] * .587 + c[2] * .114;
const median = a => { const b = [...a].sort((x, y) => x - y); return b.length ? b[b.length >> 1] : null; };
function borderOnLine(get, pts, th) {
  let outer = 0, best = 0;
  const lim = Math.min(pts.length - 8, Math.round(pts.length * .15));
  for (let i = 1; i < lim; i++) { const a = get(...pts[i - 1]), b = get(...pts[i]), g = cdist(a, b); if (g > best && luma(a) < 80) { best = g; outer = i; } }
  if (best < 45) outer = 0;
  const s = [0, 0, 0];
  for (let i = outer + 2; i < outer + 6; i++) { const c = get(...pts[i]); s[0] += c[0]; s[1] += c[1]; s[2] += c[2]; }
  const bc = s.map(v => v / 4);
  for (let i = outer + 6, run = 0; i < pts.length; i++) { if (cdist(get(...pts[i]), bc) > th) { if (++run >= 3) return { outer, width: i - 2 - outer }; } else run = 0; }
  return null;
}
function centering(cv, th) {
  const get = pixelsOf(cv), W = CARD_W, H = CARD_H, res = {};
  const line = (side, t) => {
    const n = Math.round((side === 'L' || side === 'R' ? W : H) * .2), pts = [];
    for (let i = 0; i < n; i++) {
      if (side === 'L') pts.push([i, Math.round(H * t)]); if (side === 'R') pts.push([W - 1 - i, Math.round(H * t)]);
      if (side === 'T') pts.push([Math.round(W * t), i]); if (side === 'B') pts.push([Math.round(W * t), H - 1 - i]);
    }
    return borderOnLine(get, pts, th);
  };
  for (const side of ['L', 'R', 'T', 'B']) {
    const hits = [];
    for (let k = 0; k < 31; k++) { const r = line(side, .2 + .6 * k / 30); if (r) hits.push(r); }
    res[side] = hits.length >= 10 ? { width: median(hits.map(h => h.width)), outer: median(hits.map(h => h.outer)) } : null;
  }
  // 카드를 630×880으로 펴면 테두리 합(좌+우, 상+하)은 대략 일정(약 6%). 크게 벗어나면 가장자리 검출이 틀어진 것 → 측정 불가
  const sum = (a, b) => res[a].width + res[b].width;
  const ok = ['L', 'R', 'T', 'B'].every(k => res[k] && res[k].width > 2) && sum('L', 'R') >= 28 && sum('L', 'R') <= 48 && sum('T', 'B') >= 28 && sum('T', 'B') <= 48;
  const pct = (a, b) => Math.round(a / (a + b) * 100);
  return ok ? { ...res, lr: pct(res.L.width, res.R.width), tb: pct(res.T.width, res.B.width) } : { ...res, lr: null, tb: null };
}
function wearOf(cv, cen) {
  const get = pixelsOf(cv), W = CARD_W, H = CARD_H;
  const x0 = cen.L?.outer || 0, x1 = W - 1 - (cen.R?.outer || 0), y0 = cen.T?.outer || 0, y1 = H - 1 - (cen.B?.outer || 0);
  const white = c => Math.min(...c) > 170 && Math.max(...c) - Math.min(...c) < 50;
  const frac = (ax, ay, bx, by) => { let n = 0, w = 0; for (let y = ay; y < by; y++) for (let x = ax; x < bx; x++) { n++; if (white(get(x, y))) w++; } return n ? w / n : 0; };
  const c = Math.round(W * .07), e = Math.round(W * .02);
  const corners = [frac(x0, y0, x0 + c, y0 + c), frac(x1 - c, y0, x1, y0 + c), frac(x0, y1 - c, x0 + c, y1), frac(x1 - c, y1 - c, x1, y1)];
  const edges = [frac(x0 + c, y0, x1 - c, y0 + e), frac(x0 + c, y1 - e, x1 - c, y1), frac(x0, y0 + c, x0 + e, y1 - c), frac(x1 - e, y0 + c, x1, y1 - c)];
  return { corner: Math.max(...corners), edge: Math.max(...edges) };
}
const off = v => v == null ? null : Math.max(v, 100 - v);
const ratio = v => v == null ? '측정 실패' : `${Math.max(v, 100 - v)}:${Math.min(v, 100 - v)}`;
// 앞면(필수)·뒷면(선택)으로 등급. 뒷면이 없으면 까짐은 못 재니 센터링만으로 (최대 A로 보수적으로)
function grade(front, back) {
  const fc = centering(front, 45), bc = back ? centering(back, 36) : null, wear = back ? wearOf(back, bc) : null;
  const f = Math.max(off(fc.lr) ?? 0, off(fc.tb) ?? 0), b = bc ? Math.max(off(bc.lr) ?? 0, off(bc.tb) ?? 0) : 0;
  const cen = fc.lr == null ? 'A' : f <= 60 && b <= 65 ? 'S' : f <= 70 && b <= 75 ? 'A' : 'B';   // 못 재면 S는 주지 않음
  const wr = !wear ? 'A' : wear.corner < .005 && wear.edge < .003 ? 'S' : wear.corner < .03 && wear.edge < .015 ? 'A' : wear.corner < .10 && wear.edge < .05 ? 'B' : 'C';
  const order = ['S', 'A', 'B', 'C'];
  return { grade: order[Math.max(order.indexOf(cen), order.indexOf(wr))], cen, wr, front: [fc.lr, fc.tb], back: bc ? [bc.lr, bc.tb] : null, wear,
    text: `${fc.lr == null ? '센터링 측정 실패(다시 찍으면 정확해요) · ' : ''}앞 센터링 ${ratio(fc.lr)} · ${ratio(fc.tb)}${bc ? ` · 뒤 ${ratio(bc.lr)} · ${ratio(bc.tb)}` : ''}${wear ? ` · 모서리 까짐 ${(wear.corner * 100).toFixed(1)}%` : ' · 뒷면 없음(까짐 미측정)'}` };
}

// ---------- 지문 · 대조 ----------
// 입고 신청할 때 유저 폰으로, 입고 검수 때 운영자 장비로 각각 찍어서 비교한다
function finger(front, g) {
  return { v: 2, art: packSig(fingerGrid(front, front.width, front.height)), f: g?.front || null, b: g?.back || null,
    wear: g?.wear ? [+g.wear.corner.toFixed(4), +g.wear.edge.toFixed(4)] : null, auto: g?.grade || null, at: new Date().toISOString() };
}
// 판정: 그림이 다르면 다른 카드. 그림이 같으면 센터링 차이로 같은 실물인지 참고 (같은 카드라도 실물마다 인쇄 위치가 조금씩 다름)
function compare(a, b) {
  if (!a?.art || !b?.art || a.v !== b.v) return null;
  const art = a.v === 2 ? slideDist(unpackSig(a.art), unpackSig(b.art)) : sigDist(unpackSig(a.art), unpackSig(b.art));
  const cd = (x, y) => x && y && x[0] != null && y[0] != null && x[1] != null && y[1] != null ? Math.max(Math.abs(x[0] - y[0]), Math.abs(x[1] - y[1])) : null;
  const cen = cd(a.f, b.f);
  const sameCard = art < .75;
  const copy = !sameCard ? 'no' : cen == null ? 'unknown' : cen <= 4 ? 'likely' : cen <= 8 ? 'unsure' : 'unlikely';
  const verdict = !sameCard ? 'mismatch' : copy === 'unlikely' ? 'check' : 'match';
  const msg = !sameCard ? '그림이 달라요 — 신청한 카드와 다른 카드로 보여요'
    : copy === 'likely' ? '같은 카드 · 센터링 지문도 일치 (같은 실물로 보여요)'
    : copy === 'unsure' ? '같은 카드 · 센터링이 조금 달라요 (측정 오차일 수 있어요)'
    : copy === 'unlikely' ? '같은 카드지만 센터링이 많이 달라요 — 바꿔치기(같은 카드 다른 실물)인지 확인하세요'
    : '같은 카드 (센터링 지문 없음)';
  return { art: +art.toFixed(3), cen, sameCard, copy, verdict, msg };
}
// 유저가 스캔 없이 신청한 카드는 공식 이미지와 그림만 비교
async function compareWithImage(fp, url) {
  try { const im = await loadImg(url); return compare(fp, { v: 2, art: packSig(fingerGrid(im, im.naturalWidth, im.naturalHeight)) }); } catch { return null; }
}

window.Scan = { open, stop, identify, detail, krwOf, grade, finger, compare, compareWithImage, imgOf, ratio, loadOcr, _t: { cen: cv => centering(cv, 45), parseNumber, speciesOf, artSig, sigDist, packSig, unpackSig } };
})();
