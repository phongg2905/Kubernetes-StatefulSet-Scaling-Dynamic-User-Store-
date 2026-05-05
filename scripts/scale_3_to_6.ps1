$namespace = "dynamic-user-store"
$statefulSetName = "mongo"
$logFile = "logs/scale-3-to-6.log"

New-Item -ItemType Directory -Path logs -Force | Out-Null
New-Item -ItemType File -Path $logFile -Force | Out-Null

function Write-Log {
    param([string]$message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log "Starting StatefulSet scaling demo."
Write-Log "Current pods before scaling:"
kubectl get pods -n $namespace -l app=mongo -o wide | Tee-Object -FilePath $logFile -Append

Write-Log "Current PVCs before scaling:"
kubectl get pvc -n $namespace | Tee-Object -FilePath $logFile -Append

Write-Log "Scaling StatefulSet '$statefulSetName' from 3 to 6 replicas..."
kubectl scale statefulset $statefulSetName -n $namespace --replicas=6 | Tee-Object -FilePath $logFile -Append

Write-Log "Watching pod startup status..."

for ($i = 1; $i -le 60; $i++) {
    Write-Log "Check attempt $i"

    kubectl get pods -n $namespace -l app=mongo -o wide | Tee-Object -FilePath $logFile -Append

    $readyPods = kubectl get pods -n $namespace -l app=mongo --no-headers | Select-String "1/1\s+Running"
    $readyCount = $readyPods.Count

    Write-Log "Ready pods: $readyCount / 6"

    if ($readyCount -eq 6) {
        Write-Log "All 6 MongoDB pods are Running."
        break
    }

    Start-Sleep -Seconds 5
}

Write-Log "PVCs after scaling:"
kubectl get pvc -n $namespace | Tee-Object -FilePath $logFile -Append

Write-Log "Scaling log completed."
Write-Log "Log saved to $logFile"