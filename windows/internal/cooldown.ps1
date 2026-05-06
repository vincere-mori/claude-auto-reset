param(
    [Parameter(Mandatory)][ValidateSet('check', 'clear', 'set')] [string]$Verb,
    [string]$CombinedLogPath = ''
)

$dir = Join-Path $env:LOCALAPPDATA 'claude-auto-reset'
$fEpoch = Join-Path $dir 'next_ping_epoch.txt'
$fSteps = Join-Path $dir 'backoff_steps.txt'

function Get-DoubleEnv([string]$name, [double]$default) {
    $raw = [Environment]::GetEnvironmentVariable($name, 'Process')
    if (-not $raw) { return $default }
    $parsed = $default
    if ([double]::TryParse(($raw -replace ',', '.'), [ref]$parsed)) { return $parsed }
    return $default
}

$baseH = Get-DoubleEnv 'CLAUDE_COOLDOWN_BASE_HOURS' 6
$maxH = Get-DoubleEnv 'CLAUDE_COOLDOWN_MAX_HOURS' 168

function Ensure-Store {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

function Write-EpochFile([int64]$untilUnix) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($fEpoch, "$untilUnix", $enc)
}

function Write-StepsFile([int]$step) {
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($fSteps, "$step", $enc)
}

function Test-LimitLike([string]$txt) {
    if (-not $txt) { return $false }
    $low = $txt.ToLowerInvariant()
    $patterns = @(
        'rate limit', '429', 'quota', 'usage limit', 'limit reached', 'too many requests',
        'billing', 'payment required', 'exhaust', 'overloaded', 'capacity', 'hit your limit',
        'resets'
    )
    foreach ($p in $patterns) {
        if ($low.Contains($p)) { return $true }
    }
    return $false
}

function Get-ParsedTimespan([string]$txt) {
    if (-not $txt) { return $null }
    foreach ($re in @(
        '"retry-after"\s*:\s*(\d+)',
        '[Rr]etry-After\s*:\s*(\d+)',
        'retry[_-]?after["\u0027`]?\s*[:=]\s*(\d+)',
        '(?:retry|wait)\s*(?:after|in)?\s*[:=]\s*(\d+)\s*s(?:ec|$)',
        'after\s+(\d+)\s*seconds?',
        '(\d+)\s*seconds?\s*(?:to|until|before)\s*(?:retry|try)'
    )) {
        if ($txt -cmatch $re) {
            try {
                [int64]$sec = [Convert]::ToInt64($Matches[1])
                if ($sec -gt 0 -and $sec -lt 2592000) { return [TimeSpan]::FromSeconds($sec) }
            } catch { }
        }
    }
    if ($txt -cmatch '(?m)(^|\s)(\d+)\s*(h|hr|hrs|hours?)($|\s|\.|,)' ) {
        $h = [double]$Matches[2]
        if ($h -gt 0 -and $h -le $maxH) { return [TimeSpan]::FromHours($h) }
    }
    if ($txt -cmatch '(?m)(\d+)\s*(m|min|mins|minutes?)($|\s|\.|,)' ) {
        $m = [double]$Matches[1]
        if ($m -gt 0 -and $m -le ($maxH * 60)) { return [TimeSpan]::FromMinutes($m) }
    }
    return $null
}

function Resolve-Tz([string]$id) {
    $id = $id.Trim()
    try { return [TimeZoneInfo]::FindSystemTimeZoneById($id) } catch { }
    if ($id -eq 'Europe/Moscow') {
        try { return [TimeZoneInfo]::FindSystemTimeZoneById('Russian Standard Time') } catch { }
    }
    return $null
}

function Get-ResetInstantFromLog([string]$txt) {
    if (-not $txt) { return $null }

    # "You've hit your limit · resets 6:40pm (Europe/Moscow)"
    $m = [regex]::Match(
        $txt,
        '(?is)resets\s+(?:at\s+)?([^\(\r\n]+?)\s+\(\s*([A-Za-z0-9_/+\.\-]+)\s*\)'
    )
    if (-not $m.Success) { return $null }

    $timeRaw = ($m.Groups[1].Value -replace '\s+', ' ').Trim()
    $tzId = $m.Groups[2].Value.Trim()
    $tzi = Resolve-Tz $tzId
    if (-not $tzi) { return $null }

    $en = [Globalization.CultureInfo]::GetCultureInfo('en-US')
    [datetime]$clock = [datetime]::MinValue
    $fmts = @(
        'h:mm tt', 'hh:mm tt', 'h:mmtt', 'h:mm',
        'HH:mm', 'H:mm', 'HH:mm:ss', 'H:mm:ss'
    )
    $ok = $false
    foreach ($f in $fmts) {
        if ([datetime]::TryParseExact($timeRaw, $f, $en, [Globalization.DateTimeStyles]::None, [ref]$clock)) {
            $ok = $true
            break
        }
    }
    if (-not $ok) {
        if (-not [datetime]::TryParse($timeRaw, $en, [Globalization.DateTimeStyles]::None, [ref]$clock)) {
            return $null
        }
    }

    $nowInTz = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tzi)
    $unspec = [datetime]::new(
        $nowInTz.Year, $nowInTz.Month, $nowInTz.Day,
        $clock.Hour, $clock.Minute, 0, [DateTimeKind]::Unspecified
    )
    $off = $tzi.GetUtcOffset($unspec)
    $reset = [DateTimeOffset]::new($unspec, $off)
    $nowOff = [DateTimeOffset]::UtcNow
    if ($reset -le $nowOff) {
        $unspec = $unspec.AddDays(1)
        $off = $tzi.GetUtcOffset($unspec)
        $reset = [DateTimeOffset]::new($unspec, $off)
    }

    $pad = [TimeSpan]::FromSeconds(90)
    $reset = $reset.Add($pad)
    return $reset
}

switch ($Verb) {
    'check' {
        if (-not (Test-Path -LiteralPath $fEpoch)) { exit 0 }
        $raw = (Get-Content -LiteralPath $fEpoch -Raw).Trim()
        if (-not $raw) { exit 0 }
        try {
            [int64]$until = [Convert]::ToInt64($raw)
        } catch { exit 0 }
        [int64]$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($now -lt $until) {
            $when = ([DateTimeOffset]::FromUnixTimeSeconds($until)).LocalDateTime
            Write-Host ("skip: cooldown until {0:yyyy-MM-dd HH:mm:ss} local" -f $when)
            exit 1
        }
        exit 0
    }
    'clear' {
        Remove-Item -LiteralPath $fEpoch -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $fSteps -Force -ErrorAction SilentlyContinue
        exit 0
    }
    'set' {
        if (-not (Test-Path -LiteralPath $CombinedLogPath)) { exit 2 }
        $log = [System.IO.File]::ReadAllText($CombinedLogPath)
        if (-not $log -or -not (Test-LimitLike $log)) { exit 2 }

        Ensure-Store

        $resetAt = Get-ResetInstantFromLog $log
        if ($resetAt) {
            [int64]$until = $resetAt.ToUnixTimeSeconds()
            Write-EpochFile $until
            Remove-Item -LiteralPath $fSteps -Force -ErrorAction SilentlyContinue
            $when = $resetAt.LocalDateTime
            Write-Host ("cooldown until ~{0:yyyy-MM-dd HH:mm:ss} local (from resets line)" -f $when)
            exit 0
        }

        $span = Get-ParsedTimespan $log
        $bumpStep = $false
        if (-not $span) {
            $step = 0
            if (Test-Path -LiteralPath $fSteps) {
                [void][int]::TryParse((Get-Content -LiteralPath $fSteps -Raw).Trim(), [ref]$step)
            }
            $step++
            Write-StepsFile $step
            $bumpStep = $true
            $h = $baseH * [math]::Pow(2, [math]::Max(0, $step - 1))
            if ($h -gt $maxH) { $h = $maxH }
            $span = [TimeSpan]::FromHours($h)
        }

        $cap = [TimeSpan]::FromHours($maxH)
        if ($span -gt $cap) { $span = $cap }
        $minSpan = [TimeSpan]::FromMinutes(2)
        if ($span -lt $minSpan) { $span = $minSpan }

        [int64]$until2 = [DateTimeOffset]::UtcNow.Add($span).ToUnixTimeSeconds()
        Write-EpochFile $until2
        $when2 = ([DateTimeOffset]::FromUnixTimeSeconds($until2)).LocalDateTime
        $tag = if ($bumpStep) { 'exponential backoff' } else { 'from api text' }
        Write-Host ("cooldown ~{0:0.#} h ({1}), until {2:yyyy-MM-dd HH:mm:ss} local" -f $span.TotalHours, $tag, $when2)
        exit 0
    }
}
