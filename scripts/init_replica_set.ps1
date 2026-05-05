$namespace = "dynamic-user-store"

$js = "rs.initiate({_id:'rs0',members:[{_id:0,host:'mongo-0.mongo.dynamic-user-store.svc.cluster.local:27017'},{_id:1,host:'mongo-1.mongo.dynamic-user-store.svc.cluster.local:27017'},{_id:2,host:'mongo-2.mongo.dynamic-user-store.svc.cluster.local:27017'}]})"

Write-Host "Initializing MongoDB replica set rs0..."
kubectl exec -n $namespace mongo-0 -- mongosh --quiet --eval $js

Write-Host "Waiting for replica set election..."
Start-Sleep -Seconds 10

Write-Host "Replica set status:"
kubectl exec -n $namespace mongo-0 -- mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health}))"