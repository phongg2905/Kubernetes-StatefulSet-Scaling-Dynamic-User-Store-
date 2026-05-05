$namespace = "dynamic-user-store"

$newMembers = @(
    "mongo-3.mongo.dynamic-user-store.svc.cluster.local:27017",
    "mongo-4.mongo.dynamic-user-store.svc.cluster.local:27017",
    "mongo-5.mongo.dynamic-user-store.svc.cluster.local:27017"
)

foreach ($member in $newMembers) {
    Write-Host "Adding $member to replica set..."
    kubectl exec -n $namespace mongo-0 -- mongosh --quiet --eval "rs.add('$member')"
    Start-Sleep -Seconds 5
}

Write-Host "Replica set status after adding new members:"
kubectl exec -n $namespace mongo-0 -- mongosh --quiet --eval "rs.status()"