#Setting up the shell with oh-my-posh

$omp = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($omp) {
    $ompConfig = Join-Path $env:POSH_THEMES_PATH 'jblab_2021.omp.json'
    & $omp.Path init pwsh --config $ompConfig | Invoke-Expression
}

#Load CustomModules

$customModules = "$HOME\Documents\WindowsPowerShell\PersonalModules"
if (-not ($env:PSModulePath -split ';' -contains $customModules)) {
    $env:PSModulePath = "$customModules;$env:PSModulePath"
}


Import-Module ProfileTools
