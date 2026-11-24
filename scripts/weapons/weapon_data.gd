class_name WeaponData
extends Resource
## Thông số của MỘT khẩu súng. Mỗi súng = 1 file .tres (ví dụ data/weapons/scar_l.tres).
## Script Weapon chỉ ĐỌC các số này → thêm súng mới không cần sửa code.

enum FireMode { SEMI, AUTO, BURST }   ## SEMI: mỗi lần bấm 1 phát, AUTO: giữ cò bắn liên tục, BURST: mỗi lần bấm 1 loạt

@export var display_name := "Weapon"
@export var fire_mode := FireMode.AUTO
@export_range(30.0, 1500.0, 10.0) var fire_rate := 600.0   ## phát / phút (600 = 0.1 giây một phát)
@export_range(2, 10) var burst_count := 3                   ## số phát mỗi loạt (chỉ dùng cho BURST)
@export var damage := 25.0                                  ## sát thương mỗi phát (dùng ở D3)
@export var max_range := 60.0                               ## tầm bắn, m
@export var magazine_size := 30                             ## số viên trong một băng đạn
@export var reserve_ammo := 90                              ## đạn dự trữ lúc bắt đầu (dùng ở D7)
@export var reload_time := 2.5                              ## giây (dùng ở D7)
@export_range(0.0, 15.0, 0.1) var spread := 0.0             ## độ toả đạn, độ (dùng ở D6)
