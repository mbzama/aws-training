function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    Write-Host "[$Level] $Message"
}

Write-Log "Testing" 'Success'
