$DockerStarted = $false
Do {

    $DockerService = Get-Service -Name Docker
    if ($DockerService.Status -eq 'Running'){
        Write-Output 'Docker Daemon is running'
        $DockerStarted = $true
    } else {
        Start-Sleep -Seconds 60
    }
} Until ($DockerStarted -eq $true)
