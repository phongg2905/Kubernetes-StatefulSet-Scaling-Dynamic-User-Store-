$namespace = "dynamic-user-store"
$logFile = "logs/sync-status.log"

New-Item -ItemType Directory -Path logs -Force | Out-Null
New-Item -ItemType File -Path $logFile -Force | Out-Null

Write-Host "Checking MongoDB replica set synchronization status..."

kubectl exec -n $namespace mongo-0 -- mongosh --quiet --eval "printjson(rs.status().members.map(m => ({ name: m.name, stateStr: m.stateStr, health: m.health, optimeDate: m.optimeDate })))" | Tee-Object -FilePath $logFile -Append

Write-Host "Sync status saved to $logFile"