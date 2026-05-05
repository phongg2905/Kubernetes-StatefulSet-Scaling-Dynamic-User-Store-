PROJECT PROPOSAL: DYNAMIC USER STORE

1. TÊN DỰ ÁN

Kubernetes StatefulSet Scaling: Dynamic User Store


2. TOPIC ĐƯỢC CHỌN

Topic 122: Kubernetes StatefulSet Scaling - Dynamic User Store

Yêu cầu chính của topic là triển khai một database bằng Kubernetes StatefulSet, sử dụng dataset gồm 10,000 User Profiles, sau đó viết script scale số lượng replicas từ 3 lên 6. Project cũng cần phân tích cách Kubernetes xử lý Persistent Volumes khi có pod mới được tạo, đồng thời cung cấp log thể hiện quá trình startup của pods và trạng thái đồng bộ dữ liệu.


3. MỤC TIÊU DỰ ÁN

Mục tiêu của project này là xây dựng một hệ thống lưu trữ hồ sơ người dùng có trạng thái, chạy trên Kubernetes và có khả năng scale từ 3 database pods lên 6 database pods.

Cụ thể, project hướng tới các mục tiêu sau:

- Tạo dataset gồm 10,000 user profiles giả.
- Triển khai MongoDB bằng Kubernetes StatefulSet.
- Khởi tạo MongoDB Replica Set với 3 pods ban đầu.
- Insert 10,000 users vào database.
- Scale StatefulSet từ 3 replicas lên 6 replicas.
- Quan sát cách Kubernetes tạo thêm pod mới theo thứ tự.
- Quan sát cách Kubernetes tạo PVC/PV cho các pod mới.
- Thêm các pod mới vào MongoDB Replica Set.
- Kiểm tra trạng thái đồng bộ dữ liệu sau khi scale.
- Demo failure case bằng cách xóa một pod và quan sát quá trình recovery.


4. DATASET

Dataset của project gồm 10,000 user profiles được tạo bằng thư viện Python Faker. Đây là dữ liệu giả, không chứa thông tin cá nhân thật, chỉ dùng cho mục đích kiểm thử hệ thống.

Mỗi user profile gồm các trường sau:

- user_id
- username
- full_name
- email
- age
- country
- city
- phone
- job

Dataset được lưu tại:

dataset/users.json

Lý do em chọn dữ liệu giả là vì project tập trung vào kiểm thử hạ tầng database phân tán trên Kubernetes, không tập trung vào phân tích dữ liệu người dùng thật. Việc sử dụng synthetic data cũng giúp tránh các vấn đề về quyền riêng tư.


5. CÔNG NGHỆ SỬ DỤNG

Project sử dụng các công nghệ sau:

- Container platform: Docker Desktop Kubernetes
- Database: MongoDB
- Database replication: MongoDB Replica Set
- Kubernetes controller: StatefulSet
- Service discovery: Headless Service
- Storage: Persistent Volume Claims / Persistent Volumes
- Dataset generation: Python Faker
- Database client: PyMongo
- Automation scripts: PowerShell và Python


6. THIẾT KẾ HỆ THỐNG DỰ KIẾN

Hệ thống được thiết kế theo mô hình sau:

Python Scripts -> MongoDB Replica Set -> Kubernetes StatefulSet -> PVC/PV Storage

Trong đó:

- Python scripts dùng để tạo dataset, insert dữ liệu và kiểm tra số lượng records.
- MongoDB dùng để lưu trữ user profiles.
- MongoDB Replica Set đảm nhiệm replication và data synchronization.
- StatefulSet quản lý các MongoDB pods có trạng thái.
- Headless Service cung cấp DNS ổn định cho từng MongoDB pod.
- PVC/PV cung cấp persistent storage riêng cho từng pod.

Ban đầu hệ thống chạy với 3 MongoDB pods:

- mongo-0
- mongo-1
- mongo-2

Sau khi scale, hệ thống chạy với 6 MongoDB pods:

- mongo-0
- mongo-1
- mongo-2
- mongo-3
- mongo-4
- mongo-5


7. LÝ DO SỬ DỤNG STATEFULSET

Em sử dụng StatefulSet thay vì Deployment vì MongoDB là ứng dụng có trạng thái. Database pod cần có tên ổn định, network identity ổn định và persistent storage riêng.

StatefulSet phù hợp với project vì nó hỗ trợ:

- Stable pod identity.
- Ordered startup.
- Ordered scaling.
- Stable DNS thông qua Headless Service.
- Persistent storage thông qua volumeClaimTemplates.
- Pod recovery với cùng tên pod khi pod bị xóa.

Khi scale từ 3 lên 6 replicas, Kubernetes sẽ tạo thêm các pod mới theo thứ tự:

mongo-3 -> mongo-4 -> mongo-5

Mỗi pod mới cũng sẽ có PVC riêng tương ứng:

- mongo-data-mongo-3
- mongo-data-mongo-4
- mongo-data-mongo-5


8. QUY TRÌNH THỰC HIỆN

Project được thực hiện theo các bước chính:

1. Tạo cấu trúc thư mục project.
2. Viết script tạo dataset 10,000 user profiles.
3. Viết Kubernetes YAML cho namespace, Headless Service và StatefulSet.
4. Deploy MongoDB StatefulSet với 3 replicas.
5. Khởi tạo MongoDB Replica Set.
6. Insert 10,000 users vào MongoDB.
7. Kiểm tra số lượng records trong database.
8. Viết và chạy script scale StatefulSet từ 3 lên 6 replicas.
9. Kiểm tra pod startup và PVC mới được tạo.
10. Thêm mongo-3, mongo-4, mongo-5 vào MongoDB Replica Set.
11. Kiểm tra trạng thái đồng bộ dữ liệu.
12. Demo failure case bằng cách xóa một MongoDB pod.
13. Ghi lại logs để làm bằng chứng thực nghiệm.
14. Viết design document, analysis report và README.


9. FAILURE CASE DỰ KIẾN

Failure case được demo bằng cách xóa một MongoDB pod:

kubectl delete pod mongo-2 -n dynamic-user-store

Kết quả mong đợi:

- Kubernetes phát hiện pod bị xóa.
- StatefulSet tạo lại pod mongo-2.
- Pod mới giữ cùng StatefulSet identity.
- Pod dùng lại PVC mongo-data-mongo-2.
- MongoDB Replica Set reconnect member này.
- Dữ liệu không bị mất.

Failure case này giúp chứng minh StatefulSet phù hợp với database có trạng thái vì pod có thể được khôi phục với cùng tên và cùng persistent storage.


10. KẾT QUẢ MONG ĐỢI

Sau khi hoàn thành project, hệ thống cần đạt các kết quả sau:

- Dataset gồm 10,000 user profiles được tạo thành công.
- MongoDB được deploy bằng Kubernetes StatefulSet.
- Hệ thống ban đầu chạy với 3 pods.
- MongoDB Replica Set được khởi tạo thành công.
- Database chứa đủ 10,000 users.
- StatefulSet được scale từ 3 replicas lên 6 replicas.
- Kubernetes tạo thêm mongo-3, mongo-4, mongo-5.
- Kubernetes tạo thêm PVC cho các pod mới.
- MongoDB Replica Set có đủ 6 members.
- Data synchronization status được kiểm tra thành công.
- Failure case cho thấy pod bị xóa được tạo lại và dữ liệu không bị mất.


11. DELIVERABLES

Các deliverables của project gồm:

- Project proposal.
- Two-page design document.
- Source code repository trên GitHub/GitLab.
- README hướng dẫn chạy project rõ ràng.
- Analysis report dựa trên lý thuyết Özsu and Valduriez.
- Logs chứng minh quá trình deploy, scale, PVC creation và synchronization.
- Screen recording demo 3-5 phút.
- Presentation cho final exam.


12. KẾT LUẬN

Project Dynamic User Store giúp em kiểm tra cách Kubernetes hỗ trợ triển khai và scale một database có trạng thái. Kubernetes StatefulSet đảm nhiệm phần hạ tầng như pod identity, ordered startup và persistent storage. MongoDB Replica Set đảm nhiệm phần dữ liệu như replication, PRIMARY/SECONDARY và synchronization.

Qua project này, em có thể phân tích rõ sự khác nhau giữa vai trò của Kubernetes và vai trò của database trong một hệ thống cơ sở dữ liệu phân tán.