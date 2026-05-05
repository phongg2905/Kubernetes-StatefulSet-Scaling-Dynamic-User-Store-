# Dynamic User Store

## 1. Tổng quan project

Dynamic User Store là project triển khai một hệ thống lưu trữ hồ sơ người dùng trên Kubernetes bằng StatefulSet.

Hệ thống sử dụng MongoDB Replica Set để lưu trữ 10,000 user profiles giả. Mục tiêu chính là demo cách scale một database có trạng thái từ 3 pods lên 6 pods, quan sát cách Kubernetes tạo pod mới, tạo Persistent Volume Claims mới, và kiểm tra trạng thái đồng bộ dữ liệu sau khi scale.

Project tập trung vào:

- Kubernetes StatefulSet
- MongoDB Replica Set
- Stable pod identity
- Headless Service
- Persistent Volume Claims
- Scaling từ 3 pods lên 6 pods
- Data synchronization sau khi scale
- Pod failure recovery

---

## 2. Topic

Topic 122: Kubernetes StatefulSet Scaling - Dynamic User Store

Yêu cầu của topic:

- Dataset: 10,000 User Profiles
- Deploy database bằng Kubernetes StatefulSet
- Viết script scale replica count từ 3 lên 6
- Phân tích cách Kubernetes xử lý Persistent Volumes cho pod mới
- Cung cấp log thể hiện:
  - Pod startup tuần tự
  - PVC/PV được tạo cho pod mới
  - Trạng thái đồng bộ dữ liệu

---

## 3. Prerequisites

Trước khi chạy project, cần cài:

- Docker Desktop with Kubernetes enabled
- kubectl
- Python 3.10 hoặc cao hơn
- pip
- PowerShell
- Git

Kiểm tra Kubernetes:

    kubectl get nodes

Expected result:

    docker-desktop   Ready

Kiểm tra StorageClass:

    kubectl get storageclass

Trong project này, StorageClass được sử dụng là:

    hostpath

---

## 4. Project Structure

    dynamic-user-store/
    │
    ├── README.md
    ├── requirements.txt
    │
    ├── dataset/
    │   └── users.json
    │
    ├── scripts/
    │   ├── generate_users.py
    │   ├── insert_users.py
    │   ├── check_count.py
    │   ├── init_replica_set.ps1
    │   ├── port_forward_mongo0.ps1
    │   ├── scale_3_to_6.ps1
    │   ├── add_new_replicas.ps1
    │   └── check_sync_status.ps1
    │
    ├── k8s/
    │   ├── namespace.yaml
    │   ├── headless-service.yaml
    │   └── statefulset.yaml
    │
    ├── logs/
    │
    ├── proposal/
    │   └── project-proposal.md
    │
    ├── design/
    │   └── design-document.md
    │
    └── analysis/
        └── analysis-report.md

---

## 5. Running Order

Chạy project theo thứ tự sau:

1. Install Python dependencies
2. Generate dataset
3. Deploy MongoDB StatefulSet
4. Initialize MongoDB Replica Set
5. Insert 10,000 users
6. Check user count
7. Scale StatefulSet từ 3 lên 6
8. Add new MongoDB replicas
9. Check synchronization status
10. Run failure case demo
11. Review logs

---

## 6. Install Dependencies

Cài Python dependencies:

    pip install -r requirements.txt

File requirements.txt gồm:

    Faker
    pymongo

---

## 7. Generate Dataset

Tạo dataset 10,000 user profiles:

    python scripts/generate_users.py

Expected output:

    Generated 10,000 user profiles in dataset/users.json

Kiểm tra số lượng records:

    python -c "import json; print(len(json.load(open('dataset/users.json', encoding='utf-8'))))"

Expected output:

    10000

Dataset được lưu tại:

    dataset/users.json

Mỗi user profile gồm:

- user_id
- username
- full_name
- email
- age
- country
- city
- phone
- job

Dataset này là dữ liệu giả, không chứa thông tin cá nhân thật.

---

## 8. Deploy MongoDB StatefulSet

Apply Kubernetes manifests:

    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/headless-service.yaml
    kubectl apply -f k8s/statefulset.yaml

Kiểm tra pods:

    kubectl get pods -n dynamic-user-store

Expected initial pods:

    mongo-0
    mongo-1
    mongo-2

Kiểm tra PVC:

    kubectl get pvc -n dynamic-user-store

Expected initial PVCs:

    mongo-data-mongo-0
    mongo-data-mongo-1
    mongo-data-mongo-2

---

## 9. Initialize MongoDB Replica Set

Sau khi cả 3 MongoDB pods đều Running, khởi tạo Replica Set:

    .\scripts\init_replica_set.ps1

Replica Set ban đầu gồm:

    mongo-0
    mongo-1
    mongo-2

Kiểm tra Replica Set status:

    kubectl exec -n dynamic-user-store mongo-0 -- mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health}))"

Expected result:

    1 PRIMARY
    2 SECONDARY

Trong thực nghiệm này, mongo-1 được bầu làm PRIMARY.

---

## 10. Insert 10,000 Users

MongoDB chỉ cho ghi dữ liệu vào PRIMARY. Vì vậy, trước khi insert data, kiểm tra PRIMARY:

    kubectl exec -n dynamic-user-store mongo-0 -- mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"

Trong thực nghiệm này, PRIMARY là:

    mongo-1

Mở một terminal riêng và port-forward đến PRIMARY:

    kubectl port-forward -n dynamic-user-store pod/mongo-1 27017:27017

Giữ terminal này mở.

Mở terminal khác và chạy:

    python scripts/insert_users.py

Kiểm tra số lượng users:

    python scripts/check_count.py

Expected output:

    User count: 10000

Log liên quan:

    logs/04-insert-users.log
    logs/05-count-before-scale.log

---

## 11. Scale StatefulSet from 3 to 6

Chạy script scale:

    .\scripts\scale_3_to_6.ps1

Script này scale MongoDB StatefulSet từ 3 replicas lên 6 replicas.

Kiểm tra pods:

    kubectl get pods -n dynamic-user-store

Expected pods:

    mongo-0   1/1   Running
    mongo-1   1/1   Running
    mongo-2   1/1   Running
    mongo-3   1/1   Running
    mongo-4   1/1   Running
    mongo-5   1/1   Running

Kiểm tra StatefulSet:

    kubectl get statefulset -n dynamic-user-store

Expected result:

    mongo   6/6

Kiểm tra PVC:

    kubectl get pvc -n dynamic-user-store

Expected new PVCs:

    mongo-data-mongo-3
    mongo-data-mongo-4
    mongo-data-mongo-5

Log liên quan:

    logs/scale-3-to-6.log
    logs/10-after-scale-pods.log
    logs/11-after-scale-pvc.log
    logs/12-after-scale-statefulset.log

---

## 12. Add New MongoDB Replicas

Sau khi mongo-3, mongo-4, mongo-5 đã Running, thêm chúng vào MongoDB Replica Set:

    .\scripts\add_new_replicas.ps1

Lưu ý quan trọng:

    rs.add() phải được chạy trên PRIMARY member.

Trong thực nghiệm này:

    mongo-1 = PRIMARY

Nếu PRIMARY thay đổi, cần sửa script scripts/add_new_replicas.ps1 để chạy rs.add() từ PRIMARY hiện tại.

Các pods được thêm vào Replica Set:

    mongo-3
    mongo-4
    mongo-5

Sau khi hoàn tất, Replica Set có 6 members:

    mongo-0
    mongo-1
    mongo-2
    mongo-3
    mongo-4
    mongo-5

Expected Replica Set status:

    1 PRIMARY
    5 SECONDARY
    all members health: 1

Log liên quan:

    logs/09-add-new-replicas.log
    logs/13-after-scale-replica-status.log

---

## 13. Check Synchronization Status

Chạy script kiểm tra synchronization:

    .\scripts\check_sync_status.ps1

Script này lưu trạng thái MongoDB Replica Set vào:

    logs/sync-status.log

Expected result:

    mongo-0   SECONDARY
    mongo-1   PRIMARY
    mongo-2   SECONDARY
    mongo-3   SECONDARY
    mongo-4   SECONDARY
    mongo-5   SECONDARY

Tất cả members phải có:

    health: 1

Kiểm tra count sau scale:

    python scripts/check_count.py

Expected output:

    User count: 10000

Log liên quan:

    logs/14-count-after-scale.log
    logs/sync-status.log

---

## 14. Failure Case Demo

Để demo failure handling, xóa một MongoDB pod:

    kubectl delete pod mongo-2 -n dynamic-user-store

Theo dõi Kubernetes tạo lại pod:

    kubectl get pods -n dynamic-user-store -w

Expected behavior:

- Kubernetes tạo lại mongo-2
- Pod giữ cùng StatefulSet identity
- Pod dùng lại PVC mongo-data-mongo-2
- MongoDB Replica Set reconnect member này
- Dữ liệu không bị mất

Kiểm tra PVC sau failure:

    kubectl get pvc -n dynamic-user-store

Expected result:

    mongo-data-mongo-2   Bound

Kiểm tra Replica Set sau failure:

    kubectl exec -n dynamic-user-store mongo-1 -- mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health}))"

Log liên quan:

    logs/15-after-failure-pods.log
    logs/16-after-failure-pvc.log
    logs/17-after-failure-replica-status.log

---

## 15. Logs

Các logs quan trọng được lưu trong thư mục:

    logs/

Danh sách log chính:

    logs/01-initial-pods.log
    logs/02-initial-pvc.log
    logs/03-init-replica-set.log
    logs/04-insert-users.log
    logs/05-count-before-scale.log
    logs/06-before-scale-pods.log
    logs/07-before-scale-pvc.log
    logs/08-before-scale-replica-status.log
    logs/09-add-new-replicas.log
    logs/10-after-scale-pods.log
    logs/11-after-scale-pvc.log
    logs/12-after-scale-statefulset.log
    logs/13-after-scale-replica-status.log
    logs/14-count-after-scale.log
    logs/15-after-failure-pods.log
    logs/16-after-failure-pvc.log
    logs/17-after-failure-replica-status.log
    logs/scale-3-to-6.log
    logs/sync-status.log

Các logs này chứng minh:

- Ban đầu có 3 pods và 3 PVC
- Sau scale có 6 pods và 6 PVC
- StatefulSet đạt trạng thái 6/6
- MongoDB Replica Set có đủ 6 members
- Count sau scale vẫn là 10,000 users
- Pod bị xóa được Kubernetes tạo lại
- PVC của pod bị xóa vẫn tồn tại và được dùng lại

---

## 16. Main Analysis Summary

Kubernetes StatefulSet cung cấp:

- Stable pod identity
- Ordered startup
- Persistent storage
- Pod recovery với cùng tên pod

Khi scale từ 3 replicas lên 6 replicas, Kubernetes tạo thêm pods:

    mongo-3
    mongo-4
    mongo-5

Đồng thời Kubernetes tạo thêm PVC tương ứng:

    mongo-data-mongo-3
    mongo-data-mongo-4
    mongo-data-mongo-5

Tuy nhiên, Kubernetes không tự đồng bộ dữ liệu database. Kubernetes chỉ quản lý hạ tầng như pods, services và storage. Việc replication và synchronization được xử lý bởi MongoDB Replica Set.

---

## 17. Deliverables

Project gồm:

- Project proposal
- Two-page design document
- Source code repository
- Analysis report dựa trên lý thuyết Özsu and Valduriez
- Screen recording demo
- Logs thể hiện pod startup, PVC creation và synchronization status