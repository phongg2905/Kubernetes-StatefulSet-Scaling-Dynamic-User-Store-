$namespace = "dynamic-user-store"

Write-Host "Forwarding local port 27017 to mongo-0..."
Write-Host "Keep this terminal open while inserting or checking data."

kubectl port-forward -n $namespace pod/mongo-0 27017:27017