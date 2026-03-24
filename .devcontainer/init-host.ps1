# Host-side initialization (Windows PowerShell).
# Ensures Claude config exists and seeds marketplace plugins.
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Ensure Claude config exists
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }
$claudeJson = Join-Path $env:USERPROFILE ".claude.json"
if (-not (Test-Path $claudeJson)) { New-Item -ItemType File -Path $claudeJson | Out-Null }

# Seed marketplace plugins
$SeedDir = Join-Path $ScriptDir "plugin-seed"
$MarketplaceRepo = "https://github.com/Arkitektum/claude-code-marketplace.git"
$CloneDir = Join-Path $SeedDir "clone"

# Check for git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is required but not installed"
    exit 1
}

# Clone or update marketplace
if (Test-Path (Join-Path $CloneDir ".git")) {
    git -C $CloneDir pull --ff-only 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Warning "git pull failed, using existing clone" }
} else {
    if (-not (Test-Path $SeedDir)) { New-Item -ItemType Directory -Path $SeedDir | Out-Null }
    git clone --depth 1 $MarketplaceRepo $CloneDir
}

$MarketplaceJson = Join-Path (Join-Path $CloneDir ".claude-plugin") "marketplace.json"
$Marketplace = Get-Content $MarketplaceJson -Raw | ConvertFrom-Json
$MarketplaceName = $Marketplace.name

# Copy marketplace content
$MpDst = Join-Path (Join-Path (Join-Path $SeedDir "seed") "marketplaces") $MarketplaceName
if (Test-Path $MpDst) { Remove-Item -Recurse -Force $MpDst }
New-Item -ItemType Directory -Path (Split-Path $MpDst) -Force | Out-Null
Copy-Item -Recurse $CloneDir $MpDst

# Populate plugin cache from relative-path plugins
$CacheBase = Join-Path (Join-Path $SeedDir "seed") "cache"
if (-not (Test-Path $CacheBase)) { New-Item -ItemType Directory -Path $CacheBase | Out-Null }

foreach ($plugin in $Marketplace.plugins) {
    if ($plugin.source -is [string] -and $plugin.source.StartsWith("./")) {
        $name = $plugin.name
        $version = if ($plugin.version) { $plugin.version } else { "0.0.0" }
        $pluginSrc = Join-Path $CloneDir $plugin.source
        if (Test-Path $pluginSrc) {
            $cacheDst = Join-Path (Join-Path (Join-Path $CacheBase $MarketplaceName) $name) $version
            if (Test-Path $cacheDst) { Remove-Item -Recurse -Force $cacheDst }
            New-Item -ItemType Directory -Path $cacheDst -Force | Out-Null
            Copy-Item -Recurse (Join-Path $pluginSrc "*") $cacheDst
        }
    }
}
