# Пересобирает видео сайта через ffmpeg из исходников: обычный MP4 (не «потоковый» от MediaRecorder), moov в начале
# (+faststart), ключевой кадр каждую секунду — телефоны (особенно iPhone) играют, зацикливают и перематывают без глюков.
# Плюс лёгкие копии для «призраков» на Home (assets/home/): маленькие, уже обесцвеченные, с контрастом и размытием —
# CSS-фильтры на играющем видео телефону дорого обходятся.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File .claude/encode-videos.ps1
$ErrorActionPreference = 'Stop'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root 'assets\work'
$home_ = Join-Path $root 'assets\home'
New-Item -ItemType Directory -Force $home_ | Out-Null

$D = "$env:USERPROFILE\OneDrive\Desktop"
$T = "$env:USERPROFILE\Downloads\Telegram Desktop"
# name, source, from, duration, video filter (размер/обрезка)
$clips = @(
  @{ n = 'vhs';          src = "$D\Монтаж\kirilov\vhs_4mp4.mp4";        ss = 10; t = 6;  vf = 'scale=1280:-2' },
  @{ n = 'korzh';        src = "$D\Фото\фото сайт\video 3.mp4";       ss = 10; t = 6;  vf = 'scale=1280:-2' },
  @{ n = 'okrug-street'; src = "$T\street reels 1 .mp4";         ss = 1;  t = 7;  vf = 'scale=720:-2' },
  # amsterdam: в исходнике чёрная рамка-плёнка со скруглёнными углами — обрезаем 5.5% (как было через CSS)
  @{ n = 'amstr';        src = "$T\amstr_288mp4.mp4";            ss = 34; t = 14; vf = 'crop=trunc(iw/1.055/2)*2:trunc(ih/1.055/2)*2,scale=1280:-2' },
  # 07.11: тренировка, бокс на улице — 36–52 с из «finaly 1.mp4» (3830×2160, 24 к/с)
  @{ n = 'boxing';       src = "$T\finaly 1.mp4";                ss = 36; t = 16; vf = 'scale=1280:-2' },
  # 07.11: проект «cars» (дрифт на автодроме, BMW, пилот в шлеме) — 4–15 с из «final.mp4» (3840×2160, 50 к/с)
  @{ n = 'cars';         src = "$T\final.mp4";                   ss = 4;  t = 11; vf = 'scale=1280:-2' },
  # 07.11: второе видео в «sport» — футбольный фристайл, 30–37 с из «IMG_4071.MP4» (2880×1620), «сделай как-то прикольно»:
  # день — обычная скорость (0–1.5 с куска) → на склейке в ночь вспышка 2 кадра → горящий мяч в замедлении 0.6×
  # (1.5–4.4 с) → финал с ударом в камеру снова в обычной скорости, с короткой вспышкой. fc — свой фильтр вместо vf
  @{ n = 'sport-2';      src = "$T\IMG_4071.MP4";                ss = 30; t = 7;
     # в исходнике на склейке день→ночь уже есть своя светлая вспышка (31.53–31.67 с) — она идёт в обычной скорости,
     # замедление начинается сразу после неё (1.70 с куска), своя вспышка — только перед финалом
     fc = "[0:v]split=3[x][y][z];[x]trim=0:1.7,setpts=PTS-STARTPTS[a];[y]trim=1.7:4.4,setpts=(PTS-STARTPTS)/0.6[b];[z]trim=4.4:7,setpts=PTS-STARTPTS,eq=brightness=0.3:contrast=0.8:enable='lt(t\,0.04)'[c];[a][b][c]concat=n=3:v=1,scale=1280:-2[o]" }
)
$x264 = @('-c:v','libx264','-preset','slow','-profile:v','high','-pix_fmt','yuv420p','-r','30','-g','30','-keyint_min','30','-sc_threshold','0','-an','-movflags','+faststart')

foreach ($c in $clips) {
  $out = Join-Path $work "$($c.n).mp4"
  if ($c.fc) {
    & ffmpeg -v error -y -ss $c.ss -t $c.t -i $c.src -filter_complex $c.fc -map '[o]' @x264 -crf 24 -maxrate 3M -bufsize 6M $out
  } else {
    & ffmpeg -v error -y -ss $c.ss -t $c.t -i $c.src -vf $c.vf @x264 -crf 24 -maxrate 3M -bufsize 6M $out
  }
  if ($LASTEXITCODE) { throw "ffmpeg failed: $($c.n)" }
  # копия для Home: обесцвечена на 80%, контраст, лёгкое размытие, маленькая и лёгкая
  $g = Join-Path $home_ "$($c.n).mp4"
  $small = if ($c.n -eq 'okrug-street') { 'scale=360:-2' } else { 'scale=640:-2' }
  # «плёночный» тон в цветах сайта (06.11, «тёмные кадры — обыграй цветокором, размой края, видна контрастность»):
  # без цвета → тени подняты, светлое прижато (мягче контраст, тёмные кадры читаются) → тени холодные, свет тёплый
  # оливковый → края кадра уходят в темноту (виньетка) → лёгкое размытие. Было: hue=s=0.2,eq=contrast=1.35:brightness=-0.03,gblur=1.2
  # 06.11 «поиграемся с цветами» — пользователь выбрал из 6 вариантов E «teal + orange» (киношный: холодные
  # сине-бирюзовые тени, тёплый свет, немного своего цвета). Было: оливковый (hue=s=0 + colorbalance … rh=.10:gh=.09:bh=-.10)
  # E (teal + orange, до 07.11): "$small,hue=s=0.35,curves=all='0/0 0.18/0.26 0.5/0.52 1/0.82',colorbalance=rs=-0.18:gs=0.02:bs=0.20:rh=0.18:gh=0.06:bh=-0.16,vignette=angle=PI/3.2,gblur=sigma=1.4"
  # H bleach bypass (07.11, «H давай глянем»): почти без цвета, жёстче контраст, лёгкий холод в тенях
  # + сильное размытие (sigma 9; было 1.4) — «чисто как силуэты, не отчётливые» (07.11)
  $look = "$small,hue=s=0.15,curves=all='0/0 0.25/0.18 0.5/0.55 0.8/0.86 1/0.92',colorbalance=bs=0.04,vignette=angle=PI/3.2,gblur=sigma=9"
  if ($c.n -eq 'okrug-street') {
    # на Home из okrug вырезан кусок 1.47–5.0 с (Stone Island крупно и парень с собакой на улице) — просьба пользователя 06.11
    $fc = "[0:v]trim=0:1.4667,setpts=PTS-STARTPTS[a];[0:v]trim=start=5.0,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[c];[c]$look[o]"
    & ffmpeg -v error -y -i $out -filter_complex $fc -map '[o]' @x264 -crf 30 -maxrate 700k -bufsize 1400k $g
  } else {
    & ffmpeg -v error -y -i $out -vf $look @x264 -crf 30 -maxrate 700k -bufsize 1400k $g
  }
  if ($LASTEXITCODE) { throw "ffmpeg failed: home $($c.n)" }
  "{0,-14} work {1,5:N2} MB   home {2,5:N2} MB" -f $c.n, ((Get-Item $out).Length/1MB), ((Get-Item $g).Length/1MB)
}
