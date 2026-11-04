# Собирает phone-preview.html из index.html для публикации закрытой страницей (Artifact) — чтобы смотреть сайт с телефона.
# Страница Artifact сама оборачивается в <html>/<head>/<body>, поэтому эти теги и базовые meta из копии убираем.
$root = Split-Path -Parent $PSScriptRoot
$src = [IO.File]::ReadAllText((Join-Path $root 'index.html'), [Text.Encoding]::UTF8)

$drop = '^\s*(<!doctype html>|<html[^>]*>|</html>|<head>|</head>|<body>|</body>|<meta charset[^>]*>|<meta name="viewport"[^>]*>)\s*$'
$lines = $src -split "`r?`n" | Where-Object { $_ -notmatch $drop }
$out = ($lines -join "`n") -replace '<title>Portfolio</title>', "<title>Portfolio Preview</title>`n<style>:root { color-scheme: dark; }</style>"

[IO.File]::WriteAllText((Join-Path $root 'phone-preview.html'), $out, (New-Object Text.UTF8Encoding($false)))
Write-Host "phone-preview.html updated"
