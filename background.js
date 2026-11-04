// Фон сайта. Подключение: <link rel="stylesheet" href="background.css"> и <script src="background.js"></script>.
// Сам создаёт <div class="bg"> в начале body.
(function () {
  const S = {
    width: 1, widthVar: .3,          // ширина полосы (vw) и разброс
    max: 2,                          // полос одновременно
    pause: [2.5, 2.5], life: [2, 8], // секунды
    zone: [5, 95],                   // где появляются, % ширины
    period: 9, depth: .8, chaos: .7, // мигание
    dust: 5,
  };

  const rand = (a, b) => a + Math.random() * (b - a);
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const bg = document.createElement('div');
  bg.className = 'bg';
  bg.innerHTML = '<div class="bg-leak"></div><div class="bg-grain"></div><canvas class="bg-dust"></canvas><div class="bg-vig"></div>';
  document.body.prepend(bg);
  const leak = bg.querySelector('.bg-leak');

  // зерно 35мм
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const cx = c.getContext('2d');
  const img = cx.createImageData(256, 256);
  for (let i = 0; i < img.data.length; i += 4) {
    const v = Math.random() * 255;
    img.data[i]     = v + (Math.random() - .5) * 10;
    img.data[i + 1] = v + (Math.random() - .5) * 10;
    img.data[i + 2] = v + (Math.random() - .5) * 10;
    img.data[i + 3] = 255;
  }
  cx.putImageData(img, 0, 0);
  bg.querySelector('.bg-grain').style.backgroundImage = `url(${c.toDataURL()})`;

  // полосы: каждая ждёт паузу, загорается в новом месте, мигает и гаснет
  const slots = [];
  for (let i = 0; i < S.max; i++) {
    const el = document.createElement('div');
    el.className = 'bg-strip';
    el.innerHTML = '<i class="halo"></i><i class="core"></i>';
    leak.appendChild(el);
    slots.push({ el, x: 0, life: 0, born: 0, next: rand(0, 3000) * (i + 1), phase: 0, jitter: 0 });
  }
  function spawn(s, t) {
    let x, tries = 0;
    do { x = rand(...S.zone); tries++; }
    while (tries < 12 && slots.some(o => o !== s && o.life && Math.abs(o.x - x) < 10));
    s.x = x;
    s.el.style.setProperty('--sx', x);
    s.el.style.setProperty('--sw', S.width * (1 + rand(-1, 1) * S.widthVar));
    s.born = t;
    s.life = rand(...S.life) * 1000;
    s.phase = Math.random();
  }

  // неровное мигание, как у старой лампы
  const pattern = [[0, .35], [.10, .9], [.14, .6], [.18, 1], [.40, .5], [.60, .8], [.62, .4], [1, .35]];
  function patternAt(p) {
    for (let i = 1; i < pattern.length; i++) {
      const [t1, v1] = pattern[i], [t0, v0] = pattern[i - 1];
      if (p <= t1) return v0 + (v1 - v0) * (p - t0) / (t1 - t0);
    }
    return pattern[0][1];
  }
  const smooth = x => x * x * (3 - 2 * x);

  const dust = bg.querySelector('.bg-dust'), dctx = dust.getContext('2d');
  const resize = () => { dust.width = dust.clientWidth; dust.height = dust.clientHeight; };
  resize();
  addEventListener('resize', resize);
  let lastDust = 0;

  function loop(t) {
    slots.forEach(s => {
      if (!s.life) {
        if (t >= s.next) spawn(s, t);
        return;
      }
      const age = (t - s.born) / s.life;
      if (age >= 1) {
        s.life = 0;
        s.next = t + rand(...S.pause) * 1000;
        s.el.style.opacity = 0;
        return;
      }
      const env = age < .15 ? smooth(age / .15) : age > .75 ? smooth((1 - age) / .25) : 1;
      const p = ((t - s.born) / (S.period * 1000) + s.phase) % 1;
      if (Math.random() < .08) s.jitter = (Math.random() - .5) * S.chaos;
      const k = Math.min(1, Math.max(0, (patternAt(p) - .35) / .65 + s.jitter));
      s.el.style.opacity = env;
      s.el.style.filter = `brightness(${1 - S.depth + S.depth * k * 1.15})`;
    });

    if (t - lastDust > 80) {
      lastDust = t;
      dctx.clearRect(0, 0, dust.width, dust.height);
      for (let i = 0; i < S.dust; i++) {
        if (Math.random() < .5) continue;
        dctx.fillStyle = `rgba(230,235,225,${rand(.15, .5)})`;
        dctx.beginPath(); dctx.arc(rand(0, dust.width), rand(0, dust.height), rand(.5, 1.8), 0, 6.28); dctx.fill();
      }
    }
    requestAnimationFrame(loop);
  }
  if (!reduced) requestAnimationFrame(loop);
})();
