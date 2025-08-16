$customModules = "$HOME\Documents\WindowsPowerShell\PersonalModules"
if (-not ($env:PSModulePath -split ';' -contains $customModules)) {
    $env:PSModulePath = "$customModules;$env:PSModulePath"
}

Import-Module ProfileTools
