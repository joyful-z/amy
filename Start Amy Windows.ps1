$ErrorActionPreference = 'Stop'

$projectDir = $PSScriptRoot
$backendDir = Join-Path $projectDir 'backend'
$desktopDir = Join-Path $projectDir 'desktop'
$envFile = Join-Path $backendDir '.env'
$python = Join-Path $backendDir '.venv\Scripts\python.exe'
$vite = Join-Path $desktopDir 'node_modules\vite\bin\vite.js'
$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
$bundledNode = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
$node = if ($nodeCommand) { $nodeCommand.Source } elseif (Test-Path -LiteralPath $bundledNode) { $bundledNode } else { $null }
$logDir = Join-Path $backendDir '.amy\logs'

if (-not (Test-Path -LiteralPath $envFile)) {
    Copy-Item -LiteralPath (Join-Path $backendDir '.env.example') -Destination $envFile
}
if (-not (Test-Path -LiteralPath $python)) { throw "Python environment missing: $python" }
if (-not $node) { throw 'Node.js is missing. Install Node.js 22+ and add it to PATH.' }
if (-not (Test-Path -LiteralPath $vite)) { throw "Frontend dependencies missing: $vite" }

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Test-LocalUrl([string]$url) {
    try {
        $null = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 2
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-LocalUrl 'http://127.0.0.1:8000/health')) {
    Start-Process -FilePath $python -ArgumentList '-m', 'app.server' `
        -WorkingDirectory $backendDir -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'host.out.log') `
        -RedirectStandardError (Join-Path $logDir 'host.err.log') | Out-Null
}

if (-not (Test-LocalUrl 'http://127.0.0.1:5173/')) {
    Start-Process -FilePath $node -ArgumentList ('"' + $vite + '"'), '--host', '127.0.0.1' `
        -WorkingDirectory $desktopDir -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'web.out.log') `
        -RedirectStandardError (Join-Path $logDir 'web.err.log') | Out-Null
}

for ($attempt = 0; $attempt -lt 10; $attempt++) {
    if (Test-LocalUrl 'http://127.0.0.1:8000/health') { break }
    Start-Sleep -Seconds 1
}
try {
    Start-Process 'http://127.0.0.1:5173/' | Out-Null
} catch {
    Write-Host '浏览器未能自动打开，请手动访问 http://127.0.0.1:5173/'
}

if (-not (Test-LocalUrl 'http://127.0.0.1:8000/health')) {
    Write-Host "Amy Host 启动失败，请检查 $logDir\host.err.log。"
} else {
    Write-Host 'Amy 已在本机启动：http://127.0.0.1:5173/'
}
