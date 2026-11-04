# Делает облегчённые копии фото для сайта: до 2000px по длинной стороне, JPEG 85%, с учётом поворота из EXIF.
# ARW (RAW Sony) читается через кодек Windows (WIC), если он установлен (Raw Image Extension).
param(
  [string]$Src = "C:\Users\ivanb\OneDrive\Desktop\фото сайт",
  [int]$Max = 2000
)
Add-Type -AssemblyName PresentationCore, WindowsBase
$dst = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\work'
New-Item -ItemType Directory -Force $dst | Out-Null

$i = 0
foreach ($f in Get-ChildItem $Src -File | Where-Object { $_.Extension -match '^\.(jpe?g|arw)$' } | Sort-Object Name) {
  $i++
  $out = Join-Path $dst ('{0:D2}.jpg' -f $i)
  try {
    $stream = [IO.File]::OpenRead($f.FullName)
    $dec = [Windows.Media.Imaging.BitmapDecoder]::Create($stream, 'PreservePixelFormat', 'OnLoad')
    $frame = $dec.Frames[0]

    # поворот из EXIF (у JPEG с камеры/телефона кадр часто хранится «лёжа»)
    $angle = 0
    try {
      $o = $frame.Metadata.GetQuery('/app1/ifd/{ushort=274}')
      switch ($o) { 3 { $angle = 180 } 6 { $angle = 90 } 8 { $angle = 270 } }
    } catch {}

    $scale = [Math]::Min(1.0, $Max / [Math]::Max($frame.PixelWidth, $frame.PixelHeight))
    $tg = New-Object Windows.Media.TransformGroup
    $tg.Children.Add((New-Object Windows.Media.ScaleTransform($scale, $scale)))
    if ($angle) { $tg.Children.Add((New-Object Windows.Media.RotateTransform($angle))) }
    $bmp = New-Object Windows.Media.Imaging.TransformedBitmap($frame, $tg)

    $enc = New-Object Windows.Media.Imaging.JpegBitmapEncoder
    $enc.QualityLevel = 85
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $fs = [IO.File]::Create($out); $enc.Save($fs); $fs.Close(); $stream.Close()
    "{0} -> {1}  {2}x{3}  {4:N0} KB" -f $f.Name, (Split-Path $out -Leaf), $bmp.PixelWidth, $bmp.PixelHeight, ((Get-Item $out).Length / 1KB)
  } catch {
    if ($stream) { $stream.Close() }
    "{0}: не получилось прочитать ({1})" -f $f.Name, $_.Exception.Message
    $i--
  }
}
