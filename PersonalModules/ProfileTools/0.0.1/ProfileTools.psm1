function Set-EnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value,
        [switch]$System
    )

    $target = if ($System) { 'Machine' } else { 'User' }
    [System.Environment]::SetEnvironmentVariable($Name, $Value, $target)

    Set-Item -Path "Env:$Name" -Value $Value

    Write-Host "Environment variable '$Name' set for $target scope."
}

function Remove-EnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$System
    )

    $target = if ($System) { 'Machine' } else { 'User' }
    [System.Environment]::SetEnvironmentVariable($Name, $null, $target)

    # Clean up current session too
    if (Test-Path "Env:$Name") {
        Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
    }

    Write-Host "Environment variable '$Name' removed from $target scope."
}

function Add-SystemPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$System
    )

    $target = if ($System) { 'Machine' } else { 'User' }

    # Persisted PATH for chosen scope
    $cur = [System.Environment]::GetEnvironmentVariable('PATH', $target)
    $parts = if ($cur) { $cur -split ';' } else { @() }
    if ($parts -icontains $Path) {
        Write-Host "'$Path' already exists in $target PATH."
    } else {
        $new = if ($cur) { "$cur;$Path" } else { $Path }
        [System.Environment]::SetEnvironmentVariable('PATH', $new, $target)
        Write-Host "Added '$Path' to $target PATH."
    }

    # Update current session PATH as well
    $sess = (Get-Item Env:PATH).Value
    $sessParts = if ($sess) { $sess -split ';' } else { @() }
    if (-not ($sessParts -icontains $Path)) {
        Set-Item Env:PATH -Value ($sess + ($(if ($sess) {';'} else {''})) + $Path)
    }
}

function Remove-SystemPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$System
    )

    $target = if ($System) { 'Machine' } else { 'User' }

    # Persisted PATH for chosen scope
    $cur = [System.Environment]::GetEnvironmentVariable('PATH', $target)
    if ($cur) {
        $newParts = ($cur -split ';') | Where-Object { $_ -and ($_ -ine $Path) }
        [System.Environment]::SetEnvironmentVariable('PATH', ($newParts -join ';'), $target)
    }

    # Current session PATH
    $sess = (Get-Item Env:PATH).Value
    if ($sess) {
        $sessNew = ($sess -split ';') | Where-Object { $_ -and ($_ -ine $Path) } -join ';'
        Set-Item Env:PATH -Value $sessNew
    }

    Write-Host "Removed '$Path' from $target PATH."
}

Export-ModuleMember -Function Set-EnvVar, Remove-EnvVar, Add-SystemPath, Remove-SystemPath
