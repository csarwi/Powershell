#Setting up the shell with oh-my-posh

$omp = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($omp)
{
	$ompConfig = Join-Path $env:POSH_THEMES_PATH 'jblab_2021.omp.json'
	& $omp.Path init pwsh --config $ompConfig | Invoke-Expression
}

#Load CustomModules

$customModules = "$HOME\Documents\WindowsPowerShell\PersonalModules"
if (-not ($env:PSModulePath -split ';' -contains $customModules))
{
	$env:PSModulePath = "$customModules;$env:PSModulePath"
}

function Initialize-VSEnvironment
{
	$vcvars = Get-ChildItem "C:\Program Files*\Microsoft Visual Studio\*\*\VC\Auxiliary\Build\vcvars64.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
	
	if (-not $vcvars)
 {
		return
	}
	
	try
 {
		$envVars = cmd /c "`"$($vcvars.FullName)`" >nul 2>&1 && set"
		if ($LASTEXITCODE -ne 0)
		{
			Write-Warning "Failed to execute vcvars64.bat (exit code: $LASTEXITCODE)"
			return
		}
		
		$envVars | ForEach-Object {
			if ($_ -match '^([^=]+)=(.*)')
			{
				Set-Item "env:\$($matches[1])" $matches[2] -Force
			}
		}
	} catch
	{
		Write-Error "Error loading Visual Studio environment: $($_.Exception.Message)"
	}
}

Initialize-VSEnvironment

function Initialize-WorkspaceDrive
{
	if ((Test-Path "C:\src") -and (-not (Test-Path "W:\"))) {
		subst W: C:\src 2>$null
	}
}

Initialize-WorkspaceDrive

Import-Module ProfileTools

