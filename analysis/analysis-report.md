ANALYSIS REPORT: DYNAMIC USER STORE

1. GIỚI THIỆU

Trong project Dynamic User Store, em triển khai một hệ thống lưu trữ 10,000 hồ sơ người dùng trên Kubernetes bằng StatefulSet. Database được sử dụng là MongoDB, chạy ở chế độ Replica Set. Hệ thống ban đầu có 3 MongoDB pod, sau đó được scale lên 6 pod để kiểm tra cách Kubernetes xử lý một database có trạng thái.

Theo yêu cầu của topic, phần phân tích tập trung vào ba nội dung chính: cách Kubernetes StatefulSet hỗ trợ stateful database, cách Persistent Volume được gắn vào pod mới khi scale, và cách dữ liệu được đồng bộ sau khi mở rộng hệ thống. Để giải thích thiết kế, em liên hệ project với các khái niệm trong lý thuyết cơ sở dữ liệu phân tán của Özsu và Valduriez, bao gồm replication, reliability, scalability, distribution transparency và recovery.


2. GÓC NHÌN CƠ SỞ DỮ LIỆU PHÂN TÁN

Theo Özsu và Valduriez, một hệ cơ sở dữ liệu phân tán là hệ thống trong đó dữ liệu được lưu trữ trên nhiều node khác nhau, nhưng người dùng hoặc ứng dụng có thể truy cập như một hệ thống thống nhất. Trong project này, dữ liệu user profiles không chỉ nằm trong một container đơn lẻ mà được quản lý bởi MongoDB Replica Set chạy trên nhiều pod trong Kubernetes.

Các node MongoDB trong hệ thống gồm:

- mongo-0
- mongo-1
- mongo-2
- mongo-3
- mongo-4
- mongo-5

Sau khi scale và thêm các node mới vào MongoDB Replica Set, hệ thống có 1 PRIMARY và 5 SECONDARY. PRIMARY nhận thao tác ghi dữ liệu, còn các SECONDARY nhận dữ liệu replicate từ PRIMARY hoặc từ các node khác. Đây là cách project thể hiện mô hình replication trong cơ sở dữ liệu phân tán.


3. REPLICATION

Replication là một khái niệm quan trọng trong lý thuyết cơ sở dữ liệu phân tán. Theo Özsu và Valduriez, replication giúp tăng availability, reliability và fault tolerance bằng cách duy trì nhiều bản sao dữ liệu trên nhiều node.

Trong project này, MongoDB Replica Set là thành phần chịu trách nhiệm replication. Khi em insert 10,000 user profiles vào database, dữ liệu được ghi vào PRIMARY. Sau đó, các SECONDARY đồng bộ dữ liệu từ PRIMARY thông qua cơ chế replication của MongoDB.

Điểm quan trọng là Kubernetes không trực tiếp thực hiện replication dữ liệu. Kubernetes chỉ tạo và quản lý pod, service, PVC và StatefulSet. Việc đồng bộ dữ liệu nằm ở tầng database, tức MongoDB Replica Set.

Thiết kế hệ thống có sự phân chia trách nhiệm rõ ràng:

- Kubernetes quản lý hạ tầng.
- MongoDB quản lý dữ liệu và replication.

Thiết kế này phù hợp với lý thuyết cơ sở dữ liệu phân tán vì replication phải được xử lý bởi hệ quản trị cơ sở dữ liệu, nơi hiểu cấu trúc dữ liệu, trạng thái ghi, vai trò PRIMARY/SECONDARY và cơ chế đồng bộ.


4. SCALABILITY

Scalability là khả năng hệ thống mở rộng để xử lý nhu cầu tăng lên. Trong project, scalability được thể hiện bằng việc scale StatefulSet từ 3 replicas lên 6 replicas.

Ban đầu hệ thống có:

- mongo-0
- mongo-1
- mongo-2

Sau khi scale, hệ thống có thêm:

- mongo-3
- mongo-4
- mongo-5

Kubernetes StatefulSet giúp việc scale diễn ra có trật tự. Các pod mới được tạo theo thứ tự ordinal, cụ thể là mongo-3 trước, sau đó mongo-4, rồi mongo-5. Đây là điểm quan trọng đối với database có trạng thái vì các node database thường cần identity ổn định và quá trình khởi động có thể cần được quan sát kỹ.

Tuy nhiên, việc scale StatefulSet chỉ tạo thêm pod và storage ở tầng Kubernetes. Nó không tự động biến các pod mới thành member của MongoDB Replica Set. Vì vậy, sau khi Kubernetes tạo mongo-3, mongo-4, mongo-5, em cần chạy script để thêm các pod này vào Replica Set.

Điều này cho thấy scaling trong hệ thống gồm hai lớp:

- Kubernetes scaling: tạo thêm pod và PVC.
- Database scaling: thêm node mới vào Replica Set để tham gia replication.

Thiết kế này phù hợp với hệ thống phân tán vì việc mở rộng hạ tầng và việc mở rộng cụm database là hai bước liên quan nhưng không giống nhau.


5. PERSISTENT STORAGE VÀ VOLUME ATTACHMENT

Đối với database có trạng thái, persistent storage là yêu cầu bắt buộc. Nếu dữ liệu chỉ nằm trong container filesystem, dữ liệu có thể bị mất khi pod bị xóa hoặc restart. Vì vậy, project sử dụng Persistent Volume Claim cho từng MongoDB pod.

StatefulSet sử dụng volumeClaimTemplates để tự động tạo PVC cho mỗi pod. Ban đầu hệ thống có:

- mongo-data-mongo-0
- mongo-data-mongo-1
- mongo-data-mongo-2

Sau khi scale lên 6 pod, Kubernetes tạo thêm:

- mongo-data-mongo-3
- mongo-data-mongo-4
- mongo-data-mongo-5

Mỗi pod có một PVC riêng:

- mongo-0 dùng mongo-data-mongo-0
- mongo-1 dùng mongo-data-mongo-1
- mongo-2 dùng mongo-data-mongo-2
- mongo-3 dùng mongo-data-mongo-3
- mongo-4 dùng mongo-data-mongo-4
- mongo-5 dùng mongo-data-mongo-5

Khi StatefulSet scale từ 3 lên 6, Kubernetes thực hiện các bước chính:

1. Nhận desired replica count mới là 6.
2. Tạo pod mới theo ordinal, bắt đầu từ mongo-3.
3. Tạo PVC mới từ volumeClaimTemplates.
4. PVC được bind với Persistent Volume.
5. Pod được schedule lên node.
6. Volume được attach và mount vào container MongoDB.
7. MongoDB trong pod mới bắt đầu chạy.
8. Pod mới được thêm vào Replica Set.
9. MongoDB xử lý data synchronization.

Điểm cần nhấn mạnh là Kubernetes xử lý volume attachment, còn MongoDB xử lý data synchronization. Đây là sự khác biệt quan trọng giữa storage-level management và database-level replication.


6. RELIABILITY VÀ FAULT TOLERANCE

Theo Özsu và Valduriez, reliability và fault tolerance là các yêu cầu quan trọng của hệ cơ sở dữ liệu phân tán. Hệ thống cần tiếp tục hoạt động hoặc phục hồi được khi có node gặp lỗi.

Trong project, fault tolerance được thể hiện ở hai tầng.

Tầng Kubernetes:

- StatefulSet đảm bảo số lượng pod mong muốn.
- Nếu pod bị xóa, Kubernetes tạo lại pod với cùng tên.
- PVC cũ vẫn tồn tại và được gắn lại vào pod mới.

Tầng MongoDB:

- Replica Set duy trì nhiều bản sao dữ liệu.
- Nếu một node SECONDARY bị lỗi, các node khác vẫn hoạt động.
- Node bị lỗi khi quay lại có thể reconnect và tiếp tục đồng bộ.

Failure case trong project là xóa pod mongo-2:

kubectl delete pod mongo-2 -n dynamic-user-store

Kết quả mong đợi là Kubernetes tạo lại pod mongo-2. Pod mới vẫn dùng lại PVC mongo-data-mongo-2, nên dữ liệu persistent không bị mất. Sau đó MongoDB Replica Set reconnect member này và đưa nó quay lại trạng thái SECONDARY.

Failure case này chứng minh StatefulSet phù hợp với database có trạng thái vì nó giữ được pod identity và storage identity. Nếu dùng Deployment, pod có thể bị tạo lại với tên ngẫu nhiên, không phù hợp với MongoDB Replica Set.


7. DISTRIBUTION TRANSPARENCY

Distribution transparency là khả năng che giấu sự phân tán của hệ thống đối với người dùng hoặc ứng dụng. Theo lý thuyết cơ sở dữ liệu phân tán, hệ thống nên làm cho người dùng cảm giác như đang làm việc với một database thống nhất, dù dữ liệu nằm trên nhiều node.

Trong project này, distribution transparency được thể hiện ở mức tương đối. Python script chỉ cần kết nối đến MongoDB thông qua port-forward đến PRIMARY để insert và check count. Người dùng không cần trực tiếp thao tác với từng file dữ liệu trong từng pod.

Tuy nhiên, ở góc độ quản trị hệ thống, sự phân tán vẫn được quan sát rõ qua các lệnh kubectl, trạng thái pod, PVC và Replica Set. Điều này phù hợp với mục tiêu học tập của project vì em cần chứng minh rõ cách hệ thống phân tán được triển khai, scale và phục hồi.


8. LÝ DO THIẾT KẾ PHÙ HỢP

Thiết kế sử dụng StatefulSet, Headless Service, PVC và MongoDB Replica Set là phù hợp vì mỗi thành phần giải quyết một vấn đề cụ thể của database phân tán.

StatefulSet phù hợp vì:

- Cung cấp pod name ổn định.
- Hỗ trợ startup theo thứ tự.
- Hỗ trợ scale có kiểm soát.
- Gắn mỗi pod với một PVC riêng.
- Tạo lại pod với cùng identity khi có lỗi.

Headless Service phù hợp vì:

- Cung cấp DNS ổn định cho từng MongoDB pod.
- Cho phép MongoDB members giao tiếp bằng hostname cố định.
- Không phụ thuộc vào IP tạm thời của pod.

PVC/PV phù hợp vì:

- Đảm bảo dữ liệu tồn tại sau restart hoặc pod deletion.
- Mỗi database pod có storage riêng.
- Pod được tạo lại có thể dùng lại volume cũ.

MongoDB Replica Set phù hợp vì:

- Hỗ trợ PRIMARY/SECONDARY.
- Hỗ trợ data replication.
- Hỗ trợ member recovery.
- Cho phép kiểm tra synchronization status sau khi scale.

Nhìn theo lý thuyết của Özsu và Valduriez, hệ thống đáp ứng được các yêu cầu quan trọng của cơ sở dữ liệu phân tán: replication, reliability, scalability, recovery và một phần distribution transparency.


9. GIỚI HẠN CỦA PROJECT

Project vẫn có một số giới hạn:

- Hệ thống chạy trên Docker Desktop Kubernetes local, chưa phải production cluster.
- Các pod đều chạy trên cùng một node docker-desktop, nên chưa mô phỏng đầy đủ multi-node physical failure.
- Dataset là synthetic data, không phải dữ liệu thực tế.
- Scale từ 3 lên 6 chỉ tăng số lượng replica, không phải sharding dữ liệu.
- Kubernetes không tự thêm pod mới vào MongoDB Replica Set, cần script xử lý.
- PRIMARY có thể thay đổi sau restart, nên script add replicas cần chạy trên PRIMARY hiện tại.

Những giới hạn này là chấp nhận được vì mục tiêu project là demo StatefulSet scaling, PVC attachment và MongoDB synchronization trong môi trường local.


10. KẾT LUẬN

Project Dynamic User Store cho thấy Kubernetes StatefulSet phù hợp để triển khai database có trạng thái như MongoDB. Khi scale từ 3 lên 6, Kubernetes tạo thêm pod mới theo thứ tự và tạo PVC riêng cho từng pod mới. Điều này chứng minh StatefulSet hỗ trợ stable identity, ordered startup và persistent storage.

Từ góc nhìn cơ sở dữ liệu phân tán của Özsu và Valduriez, project thể hiện các khái niệm quan trọng như replication, scalability, reliability, fault tolerance và recovery. MongoDB Replica Set xử lý replication và data synchronization, trong khi Kubernetes xử lý deployment, storage attachment và pod recovery.

Kết luận chính của project là Kubernetes và MongoDB có vai trò khác nhau nhưng bổ trợ cho nhau. Kubernetes quản lý hạ tầng phân tán, còn MongoDB quản lý dữ liệu phân tán. Sự kết hợp này giúp hệ thống có thể scale, giữ dữ liệu bền vững và phục hồi sau lỗi pod.