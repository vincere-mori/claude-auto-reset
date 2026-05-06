param(
    [Parameter(Mandatory)][ValidateSet('OnceAt', 'RestoreRecurring')][string]$Mode,
    [string]$BatPath = '',
    [int64]$UntilUnix = 0
)

$ErrorActionPreference = 'Stop'
Import-Module ScheduledTasks -ErrorAction Stop

$tn = 'claude-auto-reset'
$store = Join-Path $env:LOCALAPPDATA 'claude-auto-reset'
$flag = Join-Path $store 'scheduler_once_active.flag'

if ($Mode -eq 'RestoreRecurring') {
    if (-not $BatPath -or -not (Test-Path -LiteralPath $BatPath)) {
        Remove-Item -LiteralPath $flag -Force -ErrorAction SilentlyContinue
        exit 0
    }
    if (-not (Test-Path -LiteralPath $flag)) {
        exit 0
    }
    try {
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$BatPath`" schedule-install" -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -ne 0) {
            Write-Warning ('schedule-install exit {0}' -f $p.ExitCode)
            exit 0
        }
        Write-Host 'task: restored 4h50m schedule (schedule-install)'
    } catch {
        Write-Warning ("RestoreRecurring: $_")
        exit 0
    }
    Remove-Item -LiteralPath $flag -Force -ErrorAction SilentlyContinue
    exit 0
}

if ($Mode -eq 'OnceAt') {
    if (-not $BatPath -or -not (Test-Path -LiteralPath $BatPath)) {
        exit 0
    }
    if ($UntilUnix -le 0) {
        exit 0
    }
    $when = ([DateTimeOffset]::FromUnixTimeSeconds($UntilUnix)).LocalDateTime
    $min = (Get-Date).AddSeconds(45)
    if ($when -lt $min) {
        $when = $min
    }
    $arg = "/c call `"$BatPath`""
    try {
        $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument $arg
        $trigger = New-ScheduledTaskTrigger -Once -At $when
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
        $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $tn -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
        New-Item -ItemType Directory -Force -Path $store | Out-Null
        New-Item -ItemType File -Path $flag -Force | Out-Null
        Write-Host ("task: single run at {0:yyyy-MM-dd HH:mm:ss} local (aligned to cooldown)" -f $when)
    } catch {
        Write-Warning ("OnceAt: $_ (cooldown file still applies)")
    }
    exit 0
}
