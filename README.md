
# FPS Shooter

A 3D Top-down / Isometric Shooter game
developed using Godot Engine 4.x and GDScript.

## Tech Stack

- Godot Engine 4.5
- GDScript
- Blender 5.3 (asset pipeline, `.blend` import)
- Git + Git LFS

## Project Structure

- assets/: Game assets
- scenes/: Godot scenes
- scripts/: Game logic
- resources/: Reusable game data
- addons/: Godot plugins
- docs/: Project documentation

## Getting Started

1. Install Godot Engine 4.5 Standard and Blender 5.3.
2. Install Git LFS (`git lfs install`), then clone this repository.
3. In Godot: **Editor Settings → FileSystem → Import → Blender → Blender Path** → point to `blender.exe`.
   Godot needs Blender to import the `.blend` files in `assets/`.
4. Open `project.godot` using Godot Project Manager.
5. Run the main scene.

## Development

The project follows a milestone-based development
approach.

---

# Quy trình asset nhân vật (Character Asset Pipeline)

Tài liệu này ghi lại toàn bộ quy trình chuẩn bị nhân vật: từ một file Mixamo đến nhân vật có texture và animation chạy được trong Godot. Thực hiện theo đúng thứ tự các bước.

## Tổng quan

```
reference_swat.fbx (Mixamo)
        │  Bước 1–2
        ▼
skeleton_reference.blend ──────────────► bộ xương gốc dùng chung cho mọi nhân vật
        │  Bước 3 (skin mesh)
        ▼
swat.blend (mesh + rig) ──► Bước 4: texture/material ──► Bước 5: BoneMap trong Godot
                                                                │
Mixamo animation ──► Bước 6: Blender (bỏ prefix, export GLB) ───┤
                                                                ▼
                                       Bước 7: clip .res ──► AnimationLibrary ──► swat_model.tscn
```

**Nguyên tắc cốt lõi:** mọi nhân vật và mọi animation đều dùng **cùng một bộ xương** (tên bone giống hệt `skeleton_reference`). Godot đổi tên tất cả về tên chuẩn của `SkeletonProfileHumanoid` qua **một file BoneMap duy nhất**: `humanoid_bone_map.tres`.

## Cấu trúc thư mục asset

```
assets/characters/
├── skeletons/humanoid/
│   ├── blender/skeleton_reference.blend      ← bộ xương gốc (không mesh, không animation)
│   └── humanoid_bone_map.tres                ← BoneMap duy nhất của project
├── models/swat/
│   ├── blender/swat.blend                    ← mesh + rig, chỉ có material slot (không có ảnh)
│   ├── source/textures/*.png                 ← texture diffuse / normal / specular
│   └── materials/M_Swat_Body.tres, M_Swat_Head.tres
└── animations/humanoid/
    ├── mixamo/blender/*.blend                ← file làm việc trong Blender (có .gdignore)
    ├── mixamo/source/*.glb                   ← animation đã chuẩn hoá
    ├── mixamo/clips/*.res                    ← clip Godot tách ra từ GLB
    └── humanoid_rifle.tres                   ← AnimationLibrary
scenes/characters/swat/swat_model.tscn        ← model SWAT + AnimationPlayer
```

## Quy ước đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| File animation | `snake_case`: `<vũ khí>_<hành động>[_<hướng>]` | `rifle_idle`, `rifle_walk_forward` |
| Material Godot | `M_<Nhân vật>_<Phần>` | `M_Swat_Body` |
| Object armature trong Blender | `Skeleton_Reference` (nhân vật), `Armature` (animation) | |
| Bone (trong Blender) | Tên Mixamo **không prefix** | `Hips`, `LeftArm`, `LeftUpLeg` |
| Bone (trong Godot sau import) | Tên profile Godot | `Hips`, `LeftUpperArm`, `LeftUpperLeg` |

---

## Bước 1: Tạo skeleton reference (Blender)

**Đầu vào:** `reference_swat.fbx`, tải từ Mixamo kèm nhân vật SWAT. File có 56 bone prefix `swat:`, 2 mesh và 1 animation.

### 1.1 Import
1. **File → New → General**, nhấn **A → X** để xoá Cube, Camera và Light.
2. **File → Import → FBX (.fbx)** → chọn file, rồi đặt:
   - Transform → Scale: `1.0`
   - Armature → **Ignore Leaf Bones: ☑**
   - Armature → **Automatic Bone Orientation: ☐** (giữ nguyên trục bone gốc)

### 1.2 Dọn sạch, chỉ giữ lại xương
1. Outliner: xoá `Soldier_body`, `Soldier_head`, `Geo` và **toàn bộ Empty** `..._End` / `...4` (đầu ngón tay, đỉnh đầu, mũi chân).
2. Xoá action: đổi Display Mode của Outliner sang **Blender File** → **Actions** → chuột phải `mixamo.com` → **Delete**.
   Action có **Fake User** nên Purge không tự xoá được.
3. Pose Mode: **A**, rồi **Alt+G / Alt+R / Alt+S** để về rest pose.

### 1.3 Chuẩn hoá transform
1. Object Mode, chọn armature → **Ctrl+A → All Transforms**.
   Mixamo import với scale `0.01` và Rotation X `90°`. Sau bước này phải là Location và Rotation bằng `0`, Scale bằng `1`.
2. Kiểm tra: chân chạm sàn ở Z = 0, cao khoảng 1.74m, mặt nhìn về **−Y**.
3. Đổi tên object và armature data thành `Skeleton_Reference`.
4. Object Data → Pose → chọn **Pose Position**, không để Rest Position.
5. **File → Clean Up → Purge Unused Data**, chạy 1–2 lần.

### 1.4 Sửa hướng bone
Vì tắt Automatic Bone Orientation, mọi bone đều chĩa thẳng lên +Z. Cần sửa trong Edit Mode, **trước khi skin mesh**:
1. **Đuôi bone nối tới đầu bone con chính:**
   - Hips → Spine
   - Spine2 → Neck
   - Hand → Middle1
   - Các bone chỉ có 1 con: nối vào con đó
2. **Bone cuối chuỗi** (Head, đốt ngón số 3, ToeBase): đặt đuôi vào vị trí của các node `_End` / `...4` gốc trong FBX.
3. **Mắt:** đuôi chĩa về trước (−Y). **Jaw:** chĩa về trước và hơi xuống.
4. **Roll theo quy ước "gập quanh trục X":**
   - Tay, bàn tay, ngón tay, bàn chân, ngón chân, mắt, jaw: trục Z hướng **+Z**
   - Hips, cột sống, cổ, đầu, chân: trục Z hướng **−Y**
5. **Không đổi** vị trí đầu (head) của bone nào, tức là không dời khớp.

### 1.5 Bỏ prefix tên bone
1. Edit Mode → **A** → **Ctrl+F2** (Batch Rename):
   - **Bones / Selected → Find/Replace**
   - Find `swat:`, Replace để trống
2. Kết quả: `Hips`, `Spine`, `LeftArm`… Không được còn dấu `:`, vì Godot dùng `:` trong NodePath của track animation.

### 1.6 Lưu
Lưu thành `assets/characters/skeletons/humanoid/blender/skeleton_reference.blend`.

**Checklist:**
- 1 object duy nhất là `Skeleton_Reference`
- 56 bone, 1 root là `Hips`, T-pose
- Transform sạch
- Không có mesh, action hay Empty
- Bone nối đuôi nhau, roll đồng bộ

---

## Bước 2: Quy tắc dùng skeleton reference

- `skeleton_reference.blend` là **bản gốc chỉ đọc**. Mỗi nhân vật có một file riêng, tạo bằng **Save As** từ file này.
- Trong file nhân vật **được phép** dời khớp cho vừa mesh.
- **Không được** đổi tên bone, đổi cây phân cấp hay thêm/xoá bone.

---

## Bước 3: Gắn mesh vào skeleton (rigging / skinning)

### 3A. Mesh đã có rig Mixamo (trường hợp SWAT)
**Đầu vào:** `swat.fbx` (FBX 6.1, đã rig). Khớp xương của nó trùng 100% với `Skeleton_Reference`, nên **giữ nguyên weight gốc**, không cần skin lại.

1. Mở `skeleton_reference.blend` → **File → Save As** → `assets/characters/models/swat/blender/swat.blend`.
2. **File → Import → FBX.** FBX 6.1 không đọc được bằng trình import cũ (báo lỗi `Version 6100 unsupported`), phải dùng **mục FBX còn lại** trong menu, tức là trình import mới.
3. **Đổi tên bone trên rig cũ để vertex group tự đổi theo:**
   1. Chọn `Armature` (rig cũ) → Edit Mode → **A** → **Ctrl+F2**.
   2. Find `swat:`, Replace để trống.
   3. Kiểm tra: Object Data của mesh → **Vertex Groups** phải là `Hips`, `Spine`…
4. **Tách mesh khỏi rig cũ:**
   1. Chọn `Soldier_body` và `Soldier_head`.
   2. **Alt+P → Clear and Keep Transformation**.
   3. **Ctrl+A → All Transforms**.
5. **Armature modifier:** với từng mesh, đổi ô **Object** sang `Skeleton_Reference`. Mỗi mesh chỉ giữ đúng 1 modifier Armature.
6. **Parent:**
   1. Chọn mesh trước, **Shift+Click `Skeleton_Reference` sau cùng**.
   2. **Ctrl+P → Object (Keep Transform)**.
   3. **Không** chọn *With Automatic Weights* hay *With Empty Groups*, vì sẽ ghi đè weight.
7. **Dọn:**
   1. Xoá rig cũ, `Geo` và các Empty `_End`.
   2. **Purge Unused Data.**
8. **Test:**
   1. Pose Mode, xoay thử `LeftForeArm`, `Head`, `LeftUpLeg`, ngón tay. Mesh phải cong theo xương.
   2. **A → Alt+R / Alt+G** để về T-pose, rồi lưu.

### 3B. Mesh chưa có rig
1. Save As từ `skeleton_reference.blend`.
2. Import mesh, rồi chuẩn hoá: chân chạm Z = 0, mặt nhìn −Y, chiều cao khớp xương, **Ctrl+A → All Transforms**.
3. Edit Mode: **M → By Distance** (gộp đỉnh trùng), **Shift+N** (tính lại normal).
   **Không** làm việc này với mesh đã có UV seam, custom normals hay shape key.
4. Dời khớp xương cho vừa mesh (bật X-Axis Mirror), rồi **Shift+N → Recalculate Roll**.
5. Chọn mesh, rồi Shift+Click xương → **Ctrl+P → With Automatic Weights**.
6. Weight Paint, ưu tiên sửa: vai/nách → hông/đùi → khuỷu tay/đầu gối → cổ → ngón tay.
7. Menu **Weights**: **Clean → Limit Total (4) → Normalize All**.
8. Phần cứng (mũ, giáp cứng): gán 100% vào một bone. Súng để thành mesh riêng, gắn qua `BoneAttachment3D` trong Godot.

**Checklist mesh:**
- Parent là `Skeleton_Reference`, có đúng 1 modifier Armature trỏ vào nó
- Tên mọi vertex group trùng tên bone
- Không có đỉnh thiếu weight
- Tối đa 4 bone mỗi đỉnh, tổng weight bằng 1
- Transform sạch

---

## Bước 4: Texture và material

**Nguyên tắc:** file `.blend` chỉ chứa mesh, rig và **material slot**, không nhúng ảnh. Material được dựng trong Godot.

### 4.1 Blender: gỡ texture khỏi .blend
1. Shader Editor, với từng material: xoá node **Image Texture** và **Normal Map**. Chỉ giữ *Principled BSDF* và *Material Output*.
2. Đổi tên material: `Soldier_body1` → `M_Swat_Body`, `Soldier_head6` → `M_Swat_Head`.
3. **Giữ nguyên material slot.** `Soldier_head` dùng cả 2 material, xoá slot thì Godot không biết face nào nhận material nào.
4. **Purge Unused Data** (2 lần) để xoá ảnh nhúng, rồi lưu. File giảm còn khoảng 1MB.

### 4.2 Sắp xếp texture
Copy 6 texture vào `assets/characters/models/swat/source/textures/`. Dời file trong FileSystem của Godot để Godot tự cập nhật đường dẫn.

### 4.3 Godot: tạo material
1. FileSystem → `materials/` → **Create New → Resource → StandardMaterial3D** → `M_Swat_Body.tres`, `M_Swat_Head.tres`.
2. Với mỗi material:
   - **Albedo → Texture:** `*_diffuse.png`
   - **Normal Map → Enabled ☑**, **Texture:** `*_normal.png`
   - **Roughness:** khoảng 0.7 (mặc định 1.0 trông rất mờ)
3. Double-click `swat.blend` → **Advanced Import → Materials**: với từng material → **Use External ☑** → **Path** trỏ tới file `.tres` → **Reimport**.

**Lưu ý:**
- Godot tự nhận diện normal map khi texture được gán vào ô Normal Map, và chuyển chế độ nén cho phù hợp.
- Nếu chi tiết bị lõm ngược: chọn file normal → tab **Import** → **Normal Map Invert Y** → Reimport.
- Godot **không** dùng map specular trực tiếp. Muốn dùng thì đảo ngược ảnh rồi gán vào kênh Roughness.

---

## Bước 5: BoneMap và Retarget trong Godot

### 5.1 Tạo `humanoid_bone_map.tres` (chỉ làm 1 lần)
1. Double-click `swat.blend` → Advanced Import → chọn **`Skeleton3D`** trong cây bên trái.
2. **Retarget → Bone Map → New BoneMap**.
3. Mở BoneMap → **Profile → New SkeletonProfileHumanoid**. Godot tự map.
4. Kiểm tra sơ đồ hình người ở cả 4 tab Body / Face / Left Hand / Right Hand:
   - Mọi chấm xanh, chỉ `Root` trống (rig Mixamo không có root).
   - `Neck1` không được map (profile chỉ có 1 Neck), đó là bình thường.
5. **Lưu BoneMap ra file:** bấm **▼ ở ô `Bone Map`** (ô ngoài cùng) → **Save As** → `assets/characters/skeletons/humanoid/humanoid_bone_map.tres`.
   ⚠️ **Không** Save As ở ô `Profile` bên trong, vì như vậy chỉ lưu khung profile rỗng, không có bảng map.
   File đúng bắt đầu bằng `[gd_resource type="BoneMap"`.
6. **Reimport.**

### 5.2 Thiết lập Skeleton3D (dùng cho mọi nhân vật và animation)

| Mục | Giá trị |
|---|---|
| Retarget → Bone Map | `humanoid_bone_map.tres` (**Quick Load**, không tạo mới) |
| Remove Tracks → Except Bone Transform | ☐ |
| Remove Tracks → Unimportant Positions | ☑ |
| Remove Tracks → Unmapped Bones | ☑ (bỏ track của `Neck1`) |
| Bone Renamer → Rename Bones | ☑ |
| Bone Renamer → Unique Node → Make Unique | ☑ (skeleton đổi tên thành `GeneralSkeleton`) |
| Rest Fixer → Apply Node Transforms / Normalize Position Tracks / Reset All Bone Poses After Import | ☑ |
| Rest Fixer → Overwrite Axis | ☑ (xử lý chênh lệch hướng bone giữa các rig) |
| Rest Fixer → Fix Silhouette | ☐ (rig là T-pose) |

**Kết quả:**
- Skeleton tên `GeneralSkeleton`, bone mang tên profile (`Hips`, `Chest`, `UpperChest`, `LeftUpperArm`…).
- Track animation có dạng `%GeneralSkeleton:<bone>`, nên khớp mọi nhân vật bất kể cây node phía trên khác nhau.
- Khi viết code hoặc gắn `BoneAttachment3D`, dùng **tên profile**. Ví dụ `RightHand`.

### 5.3 BoneMap hoạt động thế nào
- BoneMap là bảng tra `ô profile → tên bone trong file nguồn`, ví dụ `bone_map/LeftUpperArm = "LeftArm"`.
- Auto mapping (đoán theo tên và cây phân cấp) chỉ chạy **lúc tạo**. Sau đó Godot chỉ tra bảng đã lưu.
- **Mỗi kiểu đặt tên bone cần một BoneMap riêng.** Project chỉ có 1 file, vì mọi nguồn (mesh và animation) đều được đưa về tên Mixamo không prefix trong Blender.

---

## Bước 6: Chuẩn hoá animation Mixamo (Blender)

### 6.1 Tải từ Mixamo
- **Format:** FBX Binary
- **Skin:** **Without Skin**
- **Frames per Second:** 30
- **Keyframe Reduction:** none
- **In Place:** ☑ với animation di chuyển
- Đổi tên file theo quy ước, ví dụ `rifle_walk_backward.fbx`.

### 6.2 Import vào Blender
1. **File → New → General**, rồi **A → X**.
2. **File → Import → FBX:**
   - **Automatic Bone Orientation: ☐**
   - **Ignore Leaf Bones: ☐**
   - Scale `1.0`

### 6.3 Bỏ prefix
1. Chọn `Armature` → Edit Mode → **A** → **Ctrl+F2**.
2. **Bones / Selected → Find/Replace**: Find là prefix (`mixamorig:`, `swat:`…), **Replace để trống**.
3. Blender tự cập nhật đường dẫn track animation theo tên bone mới.
4. Kiểm tra: Space để phát, animation phải còn nguyên.
5. *(Tuỳ chọn)* Đổi tên action thành `mixamo.com` và lưu file làm việc vào `mixamo/blender/<tên>.blend`.

### 6.4 Export GLB (KHÔNG export FBX)
Chọn `Armature` → **File → Export → glTF 2.0**:

| Nhóm | Thiết lập |
|---|---|
| Format | **glTF Binary (.glb)** |
| Include | ☑ Selected Objects |
| Transform | ☑ +Y Up |
| Data → Armature | ☑ Use Rest Position, ☐ Export Deformation Bones Only |
| Animation | ☑ Animation · Mode: **Active Actions** · ☐ Limit to Playback Range · ☑ **Always Sample Animations** · Sampling Rate 1 · ☐ **Optimize Animation Size** |

1. Lưu preset tên `Mixamo Anim GLB` (bấm **+** cạnh Operator Presets).
2. Lưu file vào `assets/characters/animations/humanoid/mixamo/source/<tên>.glb`.

> ⚠️ **Vì sao không dùng FBX?** Khi armature không có mesh đã skin, trình export FBX của Blender ghi **tư thế ở frame đầu tiên làm rest pose**. Godot retarget dựa trên độ chênh so với rest, nên nhân vật sẽ đứng nguyên T-pose. Đã đo: lệch 89 cm. GLB ghi đúng rest pose, và đã đo lệch **0.0 cm** so với animation Mixamo gốc.

---

## Bước 7: Đưa animation vào Godot

### 7.1 Import clip
1. Double-click file `.glb` trong `mixamo/source/` → Advanced Import.
2. **`Armature/Skeleton3D`:** thiết lập như bảng ở 5.2. **Quick Load** `humanoid_bone_map.tres` và bật **Unmapped Bones**.
3. **`AnimationPlayer` → click animation** (với GLB, animation thường tên `Animation`):
   - **Loop Mode:** `Linear` cho idle/walk/run, `None` cho bắn, nạp đạn, chết
   - **Save to File:** ☑ → `mixamo/clips/<tên>.res`
   - **Keep Custom Tracks:** ☐
4. **Reimport.** Import lại GLB thì file clip tự cập nhật theo.

### 7.2 AnimationLibrary
1. Tạo **một lần**: chuột phải `animations/humanoid/` → **Create New → Resource → AnimationLibrary** → `humanoid_rifle.tres`.
2. Clip lưu dạng `.res` (nhị phân, nhẹ). Library lưu dạng `.tres`, vì chỉ chứa tham chiếu nên dễ xem diff trong git.

### 7.3 Scene model
1. Chuột phải `swat.blend` → **New Inherited Scene** → lưu `scenes/characters/swat/swat_model.tscn`.
2. Thêm **`AnimationPlayer` làm con trực tiếp của node gốc**, giữ Root Node = `..`.
   Node gốc là owner của `GeneralSkeleton`, nên `%GeneralSkeleton` mới tìm thấy được.
3. Panel Animation → **Animation → Manage Animations**:
   1. **Load Library** → `humanoid_rifle.tres`.
   2. Icon **Load Animation** → chọn clip `.res` → đặt tên (`rifle_idle`…).
   3. ⚠️ Bấm **💾** ở dòng library để ghi vào file `.tres`.
4. Chọn `humanoid_rifle/rifle_idle` → **Autoplay on Load** (icon **A**).
5. ⚠️ Bấm **Stop trước khi Ctrl+S.** Nếu không, Godot lưu tư thế đang phát thành các dòng `bones/N/rotation` trong scene.

### 7.4 Thêm animation mới (quy trình rút gọn)
1. Tải từ Mixamo (6.1).
2. Blender: import, bỏ prefix, export GLB bằng preset (6.2–6.4).
3. Godot: Quick Load BoneMap, bật Unmapped Bones, đặt Loop, Save to File (7.1).
4. Thêm clip vào `humanoid_rifle.tres` và nhớ bấm 💾 (7.3).

---

## Git và LFS

### `.gitattributes`
```
* text=auto eol=lf
*.blend filter=lfs diff=lfs merge=lfs -text
*.png filter=lfs diff=lfs merge=lfs -text
*.fbx filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
```
Cuối file phải có ký tự xuống dòng. Khi thêm định dạng mới (`.wav`, `.ogg`, `.ttf`, `.jpg`…), thêm luôn vào LFS.

### Quy tắc
- Làm trên nhánh feature (`feat/<tên>`), rồi merge vào `develop`.
- Commit message theo Conventional Commits, ví dụ `feat: add rifle walk backward animation`.
- Kiểm tra `git lfs ls-files` trước khi push: file `.blend`, `.png`, `.glb` phải nằm trong LFS.
- `.godot/` đã được ignore. **Không dùng `git stash -a`**, vì lệnh này cuốn theo cả `.godot/` và gây xung đột khi pop.
- Đặt file `.gdignore` (rỗng) trong các thư mục chỉ chứa file làm việc của Blender (ví dụ `mixamo/blender/`). Godot sẽ không import chúng nữa.

---

## Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| Bone chĩa thẳng lên +Z trong Blender | Import FBX với Automatic Bone Orientation tắt | Sửa hướng bone theo 1.4, **trước khi skin** |
| `Version 6100 unsupported` khi import FBX | FBX 6.1 cũ | Dùng mục FBX còn lại trong menu Import (trình import mới) |
| Export FBX ra file khoảng 4KB, rỗng | Object Types không có Armature, hoặc chưa chọn armature | Shift+Click Armature trong Object Types. Tốt nhất là dùng GLB |
| Nhân vật đứng T-pose dù animation đang phát | Rest pose của file nguồn sai (FBX export lại qua Blender) | Export **GLB** (6.4) |
| Track `%GeneralSkeleton:swat_Hips` không tìm thấy bone | Tên bone nguồn còn prefix, BoneMap không map được | Bỏ prefix trong Blender (6.3) |
| `humanoid_bone_map.tres` có type `SkeletonProfileHumanoid` | Save As nhầm ô Profile | Save As ở ô **Bone Map** ngoài cùng (5.1) |
| `ConfigFile parse error … Can't load resource … uid://…` | File `.import` trỏ tới resource đã bị xoá | Đặt lại dòng đó thành `null` hoặc load lại đúng file, rồi Reimport |
| `Skin bind #N contains named bind … but Skeleton3D has no bone` | Lỗi tạm của khung preview khi đang đổi BoneMap | Tự hết sau khi Reimport thành công |
| `Unrecognized UID` lặp liên tục | Main Scene trỏ tới scene đã xoá | Project Settings → Application → Run → Main Scene → xoá giá trị |
| Scene `.tscn` có hàng chục dòng `bones/N/rotation` | Lưu scene khi animation đang phát | Stop rồi mới lưu. Revert pose trên `GeneralSkeleton` |
| Animation chạy trong editor nhưng không tự chạy | Chưa bật Autoplay | Panel Animation → icon **A** |

---

## Lộ trình

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 0 | Chuẩn bị asset: skeleton, SWAT, material, BoneMap | ✅ |
| 1 | Pipeline animation: idle, walk forward/left/right | 🔄 Còn: walk backward, đưa đủ clip vào library, refactor 1 BoneMap |
| 2 | Scene nhân vật: `swat_character.tscn` + AnimationTree (BlendSpace2D) | ⬜ |
| 3 | Điều khiển người chơi top-down: camera, WASD, ngắm theo chuột | ⬜ |
| 4 | Chiến đấu: vũ khí, bắn, máu, hitbox | ⬜ |
| 5 | Kẻ địch: Navigation, AI | ⬜ |
| 6 | Vòng lặp game: wave, HUD, menu | ⬜ |
| 7 | Hoàn thiện: SFX, VFX, tối ưu | ⬜ |
