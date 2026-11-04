# Простой статический сервер для предпросмотра.
# Умеет отдавать файлы кусками (Range) — нужно, чтобы видео можно было перематывать,
# и принимать файл методом PUT, но только в папку assets/ (так браузер сохраняет нарезанное видео).
param([int]$Port = 5175)
$root = Split-Path -Parent $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$Port/"
$types = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css'; '.js'='application/javascript'; '.png'='image/png'; '.jpg'='image/jpeg'; '.svg'='image/svg+xml'; '.webp'='image/webp'; '.mp4'='video/mp4'; '.webm'='video/webm' }
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request; $res = $ctx.Response; $fs = $null
  try {
    $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
    if ($path -eq '') { $path = 'index.html' }
    $file = Join-Path $root $path

    if ($req.HttpMethod -eq 'PUT') {
      if ($path -notmatch '^assets/[\w\-/]+\.(mp4|webm|jpg)$') { $res.StatusCode = 403 }
      else {
        New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
        $fs = [IO.File]::Create($file); $req.InputStream.CopyTo($fs); $fs.Close()
        $res.StatusCode = 201
        Write-Host "saved $path"
      }
    }
    elseif (Test-Path $file -PathType Leaf) {
      $ext = [IO.Path]::GetExtension($file).ToLower()
      $res.ContentType = if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' }
      $res.Headers.Add('Cache-Control', 'no-store')
      $res.Headers.Add('Accept-Ranges', 'bytes')
      $fs = [IO.File]::OpenRead($file)
      $len = $fs.Length; $start = 0; $end = $len - 1
      $range = $req.Headers['Range']
      if ($range -match '^bytes=(\d*)-(\d*)$') {
        if ($matches[1]) { $start = [int64]$matches[1] }
        if ($matches[2]) { $end = [Math]::Min([int64]$matches[2], $len - 1) }
        elseif (-not $matches[1]) { $start = [Math]::Max(0, $len - [int64]$matches[2]) }
        # открытый диапазон отдаём порциями до 8 МБ — браузер сам попросит дальше
        if (-not $matches[2]) { $end = [Math]::Min($len - 1, $start + 8MB - 1) }
        $res.StatusCode = 206
        $res.Headers.Add('Content-Range', "bytes $start-$end/$len")
      }
      $count = $end - $start + 1
      $res.ContentLength64 = $count
      $fs.Seek($start, 'Begin') | Out-Null
      $buf = New-Object byte[] 65536
      while ($count -gt 0) {
        $n = $fs.Read($buf, 0, [Math]::Min($buf.Length, $count))
        if ($n -le 0) { break }
        $res.OutputStream.Write($buf, 0, $n); $count -= $n
      }
      $fs.Close()
    } else {
      $res.StatusCode = 404
    }
  } catch {
    # браузер мог оборвать запрос (например, при перемотке видео) — это нормально
  } finally {
    # файл закрываем всегда — иначе при обрыве он остаётся занятым и его нельзя сохранить
    if ($fs) { $fs.Dispose() }
    try { $res.Close() } catch {}
  }
}
