@echo off
rem NSK Guesser launcher: a tiny web server on built-in Windows PowerShell.
rem Put this file next to index.html and double-click it. Close the window to stop.
title NSK Guesser
set "NSK_ROOT=%~dp0"
set "NSK_BAT=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = Get-Content -LiteralPath $env:NSK_BAT -Raw; Invoke-Expression ($s -split ('#' + 'PS_START'))[1]"
pause
exit /b

#PS_START
$root = [IO.Path]::GetFullPath($env:NSK_ROOT)

# Main page: index.html, or the first .html file in the folder if it was renamed
$page = 'index.html'
if (-not [IO.File]::Exists((Join-Path $root $page))) {
  $first = Get-ChildItem -LiteralPath $root -Filter *.html | Select-Object -First 1
  if (-not $first) { Write-Host 'No .html file found next to start.bat' -ForegroundColor Red; return }
  $page = $first.Name
}

# Find a free port. The Yandex key is bound to "localhost", any port works.
$listener = $null
foreach ($p in 8765..8785) {
  $l = New-Object System.Net.HttpListener
  $l.Prefixes.Add("http://localhost:$p/")
  try { $l.Start(); $listener = $l; $port = $p; break } catch { $l.Close() }
}
if (-not $listener) { Write-Host 'Ports 8765-8785 are busy' -ForegroundColor Red; return }

$url = "http://localhost:$port/"
Write-Host ''
Write-Host "  NSK Guesser is running: $url" -ForegroundColor Green
Write-Host '  Keep this window open while playing. Close it to stop the server.'
Write-Host ''
Start-Process $url

$types = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'; '.json' = 'application/json; charset=utf-8'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'
  '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.webp' = 'image/webp'
}

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq '') { $rel = $page }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    # Serve only files inside the game folder
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -and [IO.File]::Exists($full)) {
      $bytes = [IO.File]::ReadAllBytes($full)
      $ext = [IO.Path]::GetExtension($full).ToLower()
      if ($types.ContainsKey($ext)) { $res.ContentType = $types[$ext] } else { $res.ContentType = 'application/octet-stream' }
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
    }
  } catch {
    $res.StatusCode = 500
  } finally {
    $res.Close()
  }
}
