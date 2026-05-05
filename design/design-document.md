Design Document: Dynamic User Store

1. Tổng quan hệ thống

Trong project này, em xây dựng hệ thống Dynamic User Store để lưu trữ 10,000 hồ sơ người dùng. Hệ thống sử dụng MongoDB làm cơ sở dữ liệu và được triển khai trên Kubernetes bằng StatefulSet. Mục tiêu chính là kiểm tra cách Kubernetes quản lý database có trạng thái khi scale từ 3 pod lên 6 pod.

Dataset được tạo bằng Python Faker, lưu tại dataset/users.json. Đây là dữ liệu giả, không chứa thông tin cá nhân thật, chỉ dùng để kiểm thử insert dữ liệu, kiểm tra số lượng records, scale hệ thống và đồng bộ dữ liệu.

Trạng thái ban đầu:
•	mongo-0 
•	mongo-1 
•	mongo-2 

Trạng thái sau khi scale:
•	mongo-0 
•	mongo-1 
•	mongo-2 
•	mongo-3 
•	mongo-4 
•	mongo-5 


2. Kiến trúc hệ thống

Hệ thống gồm các thành phần chính:
•	Python scripts: tạo dataset, insert dữ liệu và kiểm tra số lượng records. 
•	MongoDB Replica Set: lưu trữ và đồng bộ dữ liệu. 
•	Kubernetes StatefulSet: quản lý các MongoDB pod có trạng thái. 
•	Headless Service: cung cấp DNS ổn định cho từng pod. 
•	Persistent Volume Claims: cấp storage riêng cho từng MongoDB pod. 
•	PowerShell scripts: scale hệ thống, add replicas, check sync và ghi log. 

Luồng hoạt động tổng quát:

    Python scripts → MongoDB Replica Set → Kubernetes StatefulSet → PVC/PV Storage

Python script insert 10,000 user profiles vào MongoDB. MongoDB chạy trong Kubernetes dưới dạng các pod được quản lý bởi StatefulSet. Mỗi pod có một PVC riêng để lưu dữ liệu. Khi scale lên 6 pod, Kubernetes tạo thêm pod và PVC mới. Sau đó, các pod mới được thêm vào MongoDB Replica Set để tham gia đồng bộ dữ liệu.


3. Dataset

Dataset gồm 10,000 user profiles. Mỗi user có các trường:
    user_id, username, full_name, email, age, country, city, phone, job 

File dataset: dataset/users.json

Em dùng dữ liệu giả vì project tập trung vào kiểm thử hạ tầng database trên Kubernetes, không tập trung vào dữ liệu người dùng thật. Cách này giúp tránh vấn đề quyền riêng tư nhưng vẫn đủ dữ liệu để kiểm tra insert, count, scale và synchronization.


4. StatefulSet và Headless Service

Em sử dụng StatefulSet thay vì Deployment vì MongoDB là ứng dụng có trạng thái. Database pod cần tên ổn định, network identity ổn định và storage riêng. Nếu dùng Deployment, pod có thể bị thay thế bằng tên ngẫu nhiên, không phù hợp với MongoDB Replica Set.

StatefulSet tạo pod theo thứ tự ordinal:

    mongo-0 → mongo-1 → mongo-2 → mongo-3 → mongo-4 → mongo-5

Khi scale từ 3 lên 6, Kubernetes tạo thêm:

    mongo-3 → mongo-4 → mongo-5

Điều này giúp quan sát được quá trình startup tuần tự của pod, đúng với yêu cầu project.

Hệ thống dùng Headless Service tên là mongo. Service này tạo DNS ổn định cho từng pod, ví dụ:

    mongo-0.mongo.dynamic-user-store.svc.cluster.local đến mongo-5.mongo.dynamic-user-store.svc.cluster.local

Các DNS này được dùng trong cấu hình MongoDB Replica Set. Nhờ vậy, các member có thể giao tiếp với nhau bằng hostname ổn định, không phụ thuộc vào IP tạm thời của pod.


5. Persistent Volume Design

MongoDB cần persistent storage để dữ liệu không mất khi pod bị restart hoặc bị xóa. Vì vậy, trong StatefulSet, em dùng volumeClaimTemplates để tạo PVC riêng cho từng pod.

PVC ban đầu:
•	mongo-data-mongo-0 
•	mongo-data-mongo-1 
•	mongo-data-mongo-2 

PVC sau khi scale:
•	mongo-data-mongo-3 
•	mongo-data-mongo-4 
•	mongo-data-mongo-5 

Mỗi pod dùng một PVC riêng. Ví dụ, mongo-3 dùng mongo-data-mongo-3. Trong môi trường Docker Desktop Kubernetes, StorageClass là hostpath, mỗi PVC có dung lượng 1Gi.

Kubernetes chịu trách nhiệm tạo PVC, bind PV và attach volume vào pod. Tuy nhiên, Kubernetes không tự đồng bộ dữ liệu database. Phần đồng bộ dữ liệu thuộc trách nhiệm của MongoDB Replica Set.


6. MongoDB Replica Set

MongoDB được cấu hình thành Replica Set tên là rs0.

Ban đầu Replica Set gồm:
•	mongo-0 
•	mongo-1 
•	mongo-2 

Trong thực nghiệm, mongo-1 được bầu làm PRIMARY, các node còn lại là SECONDARY. PRIMARY xử lý thao tác ghi dữ liệu, còn SECONDARY replicate dữ liệu từ PRIMARY hoặc từ các SECONDARY khác.

Sau khi Kubernetes scale StatefulSet lên 6 pod, các pod mới mongo-3, mongo-4, mongo-5 cần được thêm vào MongoDB Replica Set bằng lệnh MongoDB. Đây là bước ở tầng database, không phải Kubernetes tự làm. Sau khi hoàn tất, Replica Set có 6 members: 1 PRIMARY và 5 SECONDARY.


7. Scaling Workflow

Quy trình thực hiện chính:
1.	Tạo dataset 10,000 user profiles. 
2.	Deploy MongoDB StatefulSet với 3 replicas. 
3.	Khởi tạo MongoDB Replica Set. 
4.	Insert 10,000 users vào MongoDB. 
5.	Check count = 10000. 
6.	Chạy script scripts/scale_3_to_6.ps1. 
7.	Kubernetes tạo mongo-3, mongo-4, mongo-5. 
8.	Kubernetes tạo PVC mới cho các pod mới. 
9.	Add các pod mới vào MongoDB Replica Set. 
10.	Check sync status và count sau scale. 

Các log trong thư mục logs/ dùng để chứng minh trạng thái pod, PVC, StatefulSet, Replica Set và số lượng records sau khi scale.


8. Failure Handling

Failure case được demo bằng cách xóa một pod MongoDB:
kubectl delete pod mongo-2 -n dynamic-user-store

Kết quả mong đợi:
•	Kubernetes tạo lại pod mongo-2. 
•	Pod giữ cùng identity. 
•	Pod dùng lại PVC mongo-data-mongo-2. 
•	MongoDB Replica Set đưa node quay lại trạng thái SECONDARY. 
•	Dữ liệu không bị mất. 

Điều này chứng minh StatefulSet phù hợp với database có trạng thái vì pod có thể được khôi phục với cùng tên và cùng storage.


9. Kết luận

Thiết kế Dynamic User Store tách rõ trách nhiệm giữa Kubernetes và MongoDB. Kubernetes quản lý pod, service, PVC/PV, scaling và recovery. MongoDB quản lý dữ liệu, replication, PRIMARY/SECONDARY và synchronization.

Khi scale từ 3 pod lên 6 pod, Kubernetes tạo thêm pod và PVC mới. Sau đó, MongoDB Replica Set xử lý việc thêm node mới và đồng bộ dữ liệu. Thiết kế này đáp ứng yêu cầu project: deploy database bằng StatefulSet, scale từ 3 lên 6, quan sát PV/PVC attachment, ghi log startup và kiểm tra data synchronization status.
