@{
    RootModule        = 'ProfileTools.psm1'
    ModuleVersion     = '0.0.1'
    Author            = 'Reto Wietlisbach'
    CompanyName       = 'Creativ Software AG'
    Description       = 'Handy functions for my daily workflow'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Set-EnvVar','Remove-EnvVar','Add-SystemPath','Remove-SystemPath', 'New-CodeItem', "Get-GlobalGitStatus")
    AliasesToExport   = @('nci', 'gggs')
    CompatiblePSEditions = @('Desktop') 
    PrivateData = @{
        PSData = @{
            Tags       = @('Environment','PATH','Utilities')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/csarwi/Powershell'
        }
    }
}
