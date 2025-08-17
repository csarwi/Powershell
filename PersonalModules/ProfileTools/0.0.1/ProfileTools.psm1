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

function New-CodeItem {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    # Create the file (no error if it already exists)
    New-Item -ItemType File -Path $Path

    # Open current folder as workspace and the file in the same window
    & code -r . $Path
}# Define the alias in module scope
Set-Alias -Name nci -Value New-CodeItem

 function Get-GlobalGitStatus {
	[CmdletBinding()]
	param(
		[string]$Path = "C:\"
	)

	# --- Fast helpers ---
	function Test-GitAvailable {
		$null -ne (Get-Command git -ErrorAction SilentlyContinue)
	}

	function Get-EffectiveSearchRoots {
		param([string]$InputPath)

		# Normalize for C:\ detection without touching other C:\ children
		$norm = $InputPath.TrimEnd('\')
		if ($norm -ieq 'C:') {
			$norm = 'C:\' 
		}

		if ($norm -ieq 'C:\') {
			# Hard allow-list: ONLY these two. We do not enumerate any other C:\ children.
			$roots = @()
			foreach ($p in @('C:\src', 'C:\Users')) {
				if (Test-Path -LiteralPath $p) {
					$roots += $p 
				}
			}
			return $roots
		}

		if (-not (Test-Path -LiteralPath $InputPath)) {
			throw "Path not found: $InputPath"
		}
		return @($InputPath)
	}

	function Get-GitRepoPaths {
		<#
      Iterative traversal using .NET enumerators (streaming, low overhead).
      Prunes immediately when a .git folder is present in the current directory.
    #>
		param([string[]]$Roots)

		$results = New-Object System.Collections.Generic.List[string]
		$stack = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]

		foreach ($r in $Roots) {
			try {
				$d = New-Object System.IO.DirectoryInfo($r)
				if ($d.Exists) {
					$stack.Push($d) 
				}
			}
			catch { 
			}
		}

		while ($stack.Count -gt 0) {
			$cur = $stack.Pop()

			try {
				# Fast repo check: does current folder contain a ".git" dir?
				$gitPath = Join-Path $cur.FullName '.git'
				if (Test-Path -LiteralPath $gitPath) {
					$results.Add($cur.FullName) | Out-Null
					continue  # prune subtree
				}

				# Enumerate child dirs (streamed). Skip reparse points to avoid cycles.
				foreach ($child in $cur.EnumerateDirectories('*', [System.IO.SearchOption]::TopDirectoryOnly)) {
					try {
						if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
							continue 
						}
						$stack.Push($child)
					}
					catch {
						continue 
					}
				}
			}
			catch {
				continue
			}
		}

		return $results
	}

	function Get-GitStatus {
		param([string]$RepoPath)
		Push-Location $RepoPath
		try {
			git status 2>&1
		}
		finally {
			Pop-Location
		}
	}

	function Test-GitStatusIsClean {
		param([string]$Text)
		if (-not $Text) {
			return $false 
		}
		($Text -match 'nothing to commit') -and ($Text -match 'working\s+(tree|directory)\s+clean')
	}

	function Test-GitStatusIsFatalOrNotRepo {
		param([string]$Text)
		if (-not $Text) {
			return $false 
		}
		($Text -match 'fatal:') -or ($Text -match 'not a git repository')
	}

	# --- Main ---
	if (-not (Test-GitAvailable)) {
		Write-Error "git not found in PATH."
		exit 1
	}

	try {
		$roots = Get-EffectiveSearchRoots -InputPath $Path
	}
 catch {
		Write-Error $_.Exception.Message
		exit 1
	}

	if (-not $roots -or $roots.Count -eq 0) {
		Write-Host "No valid roots to scan."
		exit 0
	}

	Write-Host "Executing git status Recursivly over $Path ..."
	$repos = Get-GitRepoPaths -Roots $roots

	foreach ($repo in $repos) {
		$status = $null
		try {
			$status = Get-GitStatus -RepoPath $repo 
		}
		catch {
			$status = $_.Exception.Message 
		}

		if (Test-GitStatusIsFatalOrNotRepo $status) {
			continue 
		}
		if (Test-GitStatusIsClean $status) {
			continue 
		}

		$sep = ('#' * 10)
		Write-Host "$sep`n$repo$sep"
		Write-Host $status
	}
} 

Set-Alias -Name gggs -Value Get-GlobalGitStatus

# Explicitly export members so they appear in the importing session
Export-ModuleMember -Function Set-EnvVar,Remove-EnvVar,Add-SystemPath,Remove-SystemPath,New-CodeItem,Get-GlobalGitStatus -Alias nci,gggs