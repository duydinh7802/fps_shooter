
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
- tools/: Helper scripts (Blender)

## Getting Started

1. Install Godot Engine 4.5 Standard and Blender 5.3.
2. Install Git LFS (`git lfs install`), then clone this repository.
3. In Godot: **Editor Settings → FileSystem → Import → Blender → Blender Path** → point to `blender.exe`.
   Godot needs Blender to import the `.blend` files in `assets/`.
4. Open `project.godot` using Godot Project Manager.
5. Run the main scene.
6. Turn off any Vietnamese IME (Unikey / EVKey) or switch it to English mode while playing — Telex intercepts W/A/S/D.

## Development

The project follows a milestone-based development
approach.

---

# Hướng dẫn phát triển (tiếng Việt)

Tài liệu này ghi lại toàn bộ các bước đã làm, từ một file Mixamo đến nhân vật có texture, có animation và di chuyển được trong game. Thực hiện theo đúng thứ tự các bước.

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
Mixamo animation ──► Bước 6: Blender (bỏ prefix, In Place) ─────┤
                                                                ▼
                                    Bước 7: clip .res ──► AnimationLibrary ──► swat_model.tscn
                                                                                     │
                            Bước 8–10: swat_character.tscn (AnimationTree + script) ◄┘
```

**Nguyên tắc cốt lõi:** mọi nhân vật và mọi animation đều dùng **cùng một bộ xương** (tên bone giống hệt `skeleton_reference`). Godot đổi tên tất cả về tên chuẩn của `SkeletonProfileHumanoid` qua **một file BoneMap duy nhất**: `humanoid_bone_map.tres`.

## Cấu trúc thư mục

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
    ├── source/*.blend                        ← animation đã chuẩn hoá, Godot import trực tiếp
    ├── clips/*.res                           ← clip Godot tách ra khi import
    └── humanoid_rifle.tres                   ← AnimationLibrary
scenes/
├── characters/swat/
│   ├── swat_model.tscn                       ← model SWAT + AnimationPlayer (kho animation)
│   └── swat_character.tscn                   ← nhân vật hoàn chỉnh: thân, collision, AnimationTree
└── tests/test_character.tscn                 ← scene test di chuyển
scripts/
├── characters/humanoid_character.gd          ← di chuyển, xoay, cập nhật BlendSpace (dùng chung player/AI)
└── tests/test_character_driver.gd            ← đọc WASD cho scene test
tools/blender/make_in_place.py                ← xoá chuyển động trôi của animation đi
```

## Quy ước đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| File animation | `snake_case`: `<vũ khí>_<hành động>[_<hướng>]` | `rifle_idle`, `rifle_walk_forward` |
| Material Godot | `M_<Nhân vật>_<Phần>` | `M_Swat_Body` |
| Object armature trong Blender | `Skeleton_Reference` (nhân vật), `Armature` (animation) | |
| Bone (trong Blender) | Tên Mixamo **không prefix** | `Hips`, `LeftArm`, `LeftUpLeg` |
| Bone (trong Godot sau import) | Tên profile Godot | `Hips`, `LeftUpperArm`, `LeftUpperLeg` |
| Script dùng chung | `class_name` theo PascalCase | `HumanoidCharacter` |

---

# Phần I: Asset nhân vật

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

Kết quả: trục **Y nằm dọc theo bone** ở mọi bone. Nhờ vậy sau này xoay cột sống bằng code chỉ cần xoay quanh trục Y cục bộ.

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
6. **Parent** (làm cho từng mesh hoặc chọn cả 2 cùng lúc, kết quả như nhau):
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
- Lúc import, Godot đổi tên bone và track theo bảng. Lúc chạy game, AnimationPlayer chỉ so tên: track `%GeneralSkeleton:Hips` tìm bone `Hips`.
- **Mỗi kiểu đặt tên bone cần một BoneMap riêng.** Project chỉ có 1 file, vì mọi nguồn (mesh và animation) đều được đưa về tên Mixamo không prefix trong Blender.

---

# Phần II: Animation

## Bước 6: Chuẩn hoá animation Mixamo (Blender)

### 6.1 Tải từ Mixamo
- **Format:** FBX Binary
- **Skin:** **Without Skin**
- **Frames per Second:** 30
- **Keyframe Reduction:** none
- **In Place:** ☑ nếu có. Nhiều animation (đi lùi, đi ngang cầm súng) **không có** ô này, khi đó dùng script ở 6.4.
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

### 6.4 Đưa animation đi về "In Place" (nếu Mixamo không có ô In Place)
Animation đi bộ của Mixamo mang theo chuyển động tiến: hông trôi khoảng **1.8 m mỗi vòng** rồi giật về. Trong game, **code** mới là thứ di chuyển nhân vật, nên animation phải bước tại chỗ.

Script `tools/blender/make_in_place.py` đo độ trôi ngang của Hips từ frame đầu tới frame cuối, rồi trừ dần theo thời gian. Kết quả là xoá phần trôi nhưng **giữ nhún lên xuống và lắc người**.

**Cách 1: trong Blender**
1. Mở file `.blend` của animation đi (không áp dụng cho idle).
2. Tab **Scripting** → **Text → Open** → `tools/blender/make_in_place.py` → **Run Script** (Alt+P).
3. **Window → Toggle System Console** sẽ hiện dòng `[In Place] ... drift before = 1.843 m, after = 0.0000 m`.
4. Space để phát: nhân vật bước tại chỗ. **Ctrl+S.**

**Cách 2: chạy hàng loạt bằng PowerShell** (tại thư mục project)
```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
foreach ($n in "forward","backward","left","right") {
  & $blender -b "assets\characters\animations\humanoid\source\rifle_walk_$n.blend" `
    --python "tools\blender\make_in_place.py" --python-expr "import bpy; bpy.ops.wm.save_mainfile()"
}
```

Lưu ý:
- Chạy lại lần 2 trên cùng file cũng vô hại, vì lúc đó độ trôi đã bằng 0.
- **Không** chạy cho animation xoay tại chỗ (turn) nếu định dùng root motion.
- Độ trôi đo được cho biết tốc độ thật của animation: khoảng **1.8 m/s** với các clip walk hiện có. Dùng con số này cho `walk_speed`.

### 6.5 Lưu file nguồn
Lưu file `.blend` vào `assets/characters/animations/humanoid/source/<tên>.blend`. Godot **import trực tiếp** file này.

> ⚠️ **Không export FBX từ Blender cho animation.** Khi armature không có mesh đã skin, trình export FBX của Blender ghi **tư thế ở frame đầu tiên làm rest pose**. Godot retarget dựa trên độ chênh so với rest, nên nhân vật sẽ đứng nguyên T-pose (đã đo: lệch 89 cm).
> Godot import `.blend` bằng trình export glTF của Blender, trình này ghi đúng rest pose (đã đo: lệch **0.0 cm** so với Mixamo gốc). Nếu cần file trung gian, export **glTF Binary (.glb)** với: Selected Objects ☑, +Y Up ☑, Animation Mode **Active Actions**, Always Sample ☑, Optimize Animation Size ☐.

---

## Bước 7: Đưa animation vào Godot

### 7.1 Import clip
1. Double-click file `.blend` trong `animations/humanoid/source/` → Advanced Import.
2. **`Armature/Skeleton3D`:** thiết lập như bảng ở 5.2. **Quick Load** `humanoid_bone_map.tres` và bật **Unmapped Bones**.
3. **`AnimationPlayer` → click animation** (thường tên `mixamo_com`):
   - **Loop Mode:** `Linear` cho idle/walk/run, `None` cho bắn, nạp đạn, chết
   - **Save to File:** ☑ → `animations/humanoid/clips/<tên>.res`
   - **Keep Custom Tracks:** ☐
4. **Reimport.** Khi file `.blend` thay đổi (ví dụ sau khi chạy script In Place), Godot tự import lại và clip `.res` tự cập nhật, không phải sửa library.

### 7.2 AnimationLibrary
1. Tạo **một lần**: chuột phải `animations/humanoid/` → **Create New → Resource → AnimationLibrary** → `humanoid_rifle.tres`.
2. Clip lưu dạng `.res` (nhị phân, nhẹ). Library lưu dạng `.tres`, vì chỉ chứa tham chiếu nên dễ xem diff trong git.

### 7.3 Scene model (kho animation)
1. Chuột phải `swat.blend` → **New Inherited Scene** → lưu `scenes/characters/swat/swat_model.tscn`.
2. Thêm **`AnimationPlayer` làm con trực tiếp của node gốc**, giữ Root Node = `..`.
   Node gốc là owner của `GeneralSkeleton`, nên `%GeneralSkeleton` mới tìm thấy được.
3. Panel Animation → **Animation → Manage Animations**:
   1. **Load Library** → `humanoid_rifle.tres`.
   2. Icon **Load Animation** → chọn clip `.res` → đặt tên (`rifle_idle`…).
   3. ⚠️ Bấm **💾** ở dòng library để ghi vào file `.tres`.
4. ⚠️ **Không bật Autoplay.** Khi đã có AnimationTree (Bước 8), AnimationPlayer chỉ là kho chứa animation. Nếu autoplay idle, nó sẽ ghi đè kết quả của AnimationTree mỗi frame. Muốn xem thử thì bấm ▶ rồi bấm Stop.
5. ⚠️ Bấm **Stop trước khi Ctrl+S.** Nếu không, Godot lưu tư thế đang phát thành các dòng `bones/N/rotation` trong scene.

### 7.4 Thêm animation mới (quy trình rút gọn)
1. Tải từ Mixamo (6.1).
2. Blender: import, bỏ prefix (6.2–6.3). Nếu là animation đi mà không có In Place thì chạy `make_in_place.py` (6.4). Lưu vào `source/` (6.5).
3. Godot: Quick Load BoneMap, bật Unmapped Bones, đặt Loop, Save to File (7.1).
4. Thêm clip vào `humanoid_rifle.tres` và nhớ bấm 💾 (7.3).
5. Nếu là kiểu di chuyển mới, thêm điểm vào BlendSpace2D (8.6).

---

# Phần III: Nhân vật trong game

## Bước 8: Scene nhân vật + AnimationTree

**Mục tiêu:** một scene nhân vật dùng chung cho người chơi và kẻ địch. Kiểu đi được chọn tự động theo hướng di chuyển so với hướng nhìn.

```
scenes/characters/swat/swat_character.tscn
SwatCharacter (CharacterBody3D)        ← script: humanoid_character.gd
 ├ CollisionShape3D (Capsule)
 ├ Model (swat_model.tscn, xoay Y 180°)
 │   └ AnimationPlayer                 ← kho animation, KHÔNG autoplay
 └ AnimationTree
     └ StateMachine
         └ Locomotion (BlendSpace2D)
```

### 8.1 Tạo scene
1. **Scene → New Scene → Other Node → `CharacterBody3D`**, đổi tên thành `SwatCharacter`.
2. **Ctrl+S** → `scenes/characters/swat/swat_character.tscn`.

### 8.2 Collision
1. Thêm con **`CollisionShape3D`** → **Shape → New CapsuleShape3D**: Radius `0.3`, Height `1.75`.
2. **Position:** `(0, 0.875, 0)`. Đáy capsule nằm đúng mặt sàn.

### 8.3 Model
1. Kéo `swat_model.tscn` thả vào `SwatCharacter`, đổi tên thành `Model`.
2. **Rotation:** `(0, 180, 0)`.
   Model import từ Blender quay mặt về **+Z**, trong khi "phía trước" của Godot là **−Z**. Xoay 180° để `-global_basis.z` và các phép tính hướng đều đúng với mặt nhân vật.
3. Kiểm tra: chọn `SwatCharacter`, bật Local Space (phím **T**). Mũi tên **xanh dương (Z)** phải chĩa ra **sau lưng** nhân vật.

### 8.4 AnimationTree
1. Thêm con **`AnimationTree`** vào `SwatCharacter`.
2. Inspector:

| Nhóm | Thuộc tính | Giá trị |
|---|---|---|
| AnimationTree | **Tree Root** | New **AnimationNodeStateMachine** |
| AnimationTree | **Anim Player** | **`../Model/AnimationPlayer`**. Đường dẫn tính **từ node AnimationTree**, nên phải có `../` ở đầu |
| AnimationMixer | **Active** | ☑ (mặc định đã bật) |
| AnimationMixer | **Root Node** | **`../Model`**. Từ `SwatCharacter` không tìm được `%GeneralSkeleton`, vì skeleton thuộc scene `swat_model` |
| AnimationMixer → Callback Mode | **Process** | **Physics** (cùng nhịp với `move_and_slide`) |

Sau khi gán Anim Player, **nhìn lại ô Root Node**. Godot có thể tự đổi giá trị này về `..`.

### 8.5 State Machine
Chọn `AnimationTree`, panel **AnimationTree** mở ở dưới.
1. Chuột phải vùng trống → **Add BlendSpace2D** → đổi tên thành **`Locomotion`**.
2. Công cụ **Connect nodes** → kéo **`Start` → `Locomotion`**.
3. Công cụ **Select** → click vào **mũi tên** → Inspector → **Advance → Mode: `Auto`**. Mũi tên chuyển **màu xanh lá**.
   Mặc định là `Enabled`, nghĩa là chỉ chuyển khi code ra lệnh. Khi đó state machine đứng yên ở `Start` và không phát gì.

### 8.6 BlendSpace2D
1. Click icon **✏️** trên node `Locomotion` để mở trình chỉnh.
2. Công cụ **Create points** → click vào ô → **Add Animation** → chọn clip. Sau đó chọn điểm và gõ toạ độ chính xác ở ô X/Y:

   | Toạ độ | Animation |
   |---|---|
   | `(0, 0)` | `humanoid_rifle/rifle_idle` |
   | `(0, 1)` | `humanoid_rifle/rifle_walk_forward` |
   | `(0, -1)` | `humanoid_rifle/rifle_walk_backward` |
   | `(-1, 0)` | `humanoid_rifle/rifle_walk_left` |
   | `(1, 0)` | `humanoid_rifle/rifle_walk_right` |

   Quy ước: **X dương là sang phải** của nhân vật, **Y dương là phía trước**.
3. Thiết lập **Sync**, X/Y Label, Snap, Blend Mode **không nằm trên thanh dưới** của trình chỉnh. Muốn chỉnh: ở panel state machine, **click một lần** vào node `Locomotion` (không bấm ✏️), rồi chỉnh trong Inspector:
   - **Sync** ☑ (giữ nhịp chân giữa các clip walk khi trộn)
   - **X Label** `right`, **Y Label** `forward`
   - Snap `(0.1, 0.1)`, Blend Mode `Interpolated`, Auto Triangles ☑
4. Test: công cụ **Set the blending position**, kéo chấm trong ô. Nhân vật ở viewport phải đổi kiểu đi.
5. Kéo chấm về `(0, 0)` → **Ctrl+S**.

**Checklist Bước 8:**
- Nhân vật thở nhẹ cầm súng (idle) ngay khi AnimationTree Active
- Kéo chấm blend thì đổi kiểu đi theo đúng hướng
- AnimationPlayer trong `swat_model.tscn` **không** có Autoplay

---

## Bước 9: Script nhân vật `humanoid_character.gd`

**Tạo:** `scripts/characters/humanoid_character.gd`, gắn vào node `SwatCharacter`.

**Thiết kế:** script **không đọc bàn phím**. Bộ điều khiển (người chơi, AI) chỉ gán 2 biến:

| Biến | Ý nghĩa |
|---|---|
| `move_input: Vector3` | Hướng muốn đi, toạ độ thế giới, độ dài 0..1 |
| `look_direction: Vector3` | Hướng muốn nhìn, toạ độ thế giới |

Thông số chỉnh trong Inspector: `walk_speed` (1.8, khớp tốc độ animation), `acceleration` (12), `turn_speed` (12), `blend_smoothing` (10).

Mỗi frame vật lý (`_physics_process`), script làm 3 việc theo thứ tự:

### 9.1 `_apply_movement`: di chuyển
1. `limit_length(1.0)`: giới hạn độ dài input, để đi chéo (W+D) không nhanh hơn 41%.
2. `move_toward(target, acceleration * delta)`: tăng tốc và giảm tốc dần, mất khoảng 0.15 giây để đạt 1.8 m/s.
3. Trọng lực: trên sàn thì `velocity.y = 0`, trên không thì cộng `get_gravity() * delta`.
4. `move_and_slide()`: di chuyển, trượt dọc tường, cập nhật `is_on_floor()`.

### 9.2 `_apply_facing`: xoay người
1. Bỏ trục Y của `look_direction`, vì chỉ xoay ngang.
2. `atan2(-dir.x, -dir.z)`: đổi hướng thành góc yaw. Có dấu trừ vì mặt nhân vật là −Z.

   | Hướng nhìn | yaw |
   |---|---|
   | Lên (−Z) | 0° |
   | Phải (+X) | −90° |
   | Trái (−X) | +90° |
   | Xuống (+Z) | 180° |

3. `lerp_angle(rotation.y, target_yaw, turn_speed * delta)`: mỗi frame xoay khoảng 20% góc còn thiếu, nên chậm dần khi gần tới. `lerp_angle` luôn đi đường ngắn nhất quanh vòng tròn (170° → −170° chỉ xoay 20°).

### 9.3 `_update_animation`: chọn kiểu đi
1. `global_basis.inverse() * velocity`: đổi vận tốc từ hệ thế giới sang **hệ toạ độ của nhân vật**.
2. `Vector2(local.x, -local.z) / walk_speed`: ra toạ độ BlendSpace (phải, trước) trong khoảng −1..1.
3. `lerp` cho chấm blend trượt mượt, rồi `anim_tree.set("parameters/Locomotion/blend_position", ...)`.

Ví dụ: nhân vật **nhìn sang phải** mà bấm **W** (đi lên màn hình) thì đó là đi về **bên trái của nó**, blend = `(−1, 0)`, phát `walk_left`.

---

## Bước 10: Scene test

### 10.1 Dựng scene `scenes/tests/test_character.tscn`
Root `Node3D` tên `TestCharacter`, gắn script `scripts/tests/test_character_driver.gd`.

| Node | Thiết lập |
|---|---|
| `DirectionalLight3D` | **Rotation** `(-50, -30, 0)` (không phải Position. Với đèn hướng, chỉ góc xoay có tác dụng), Shadow ☑ |
| `WorldEnvironment` | Environment → Background `Sky` → Sky → **Sky Material: New ProceduralSkyMaterial**. Ambient Light: `Sky` |
| `Floor` (**CSGBox3D**) | Size `(20, 0.2, 20)`, Position `(0, -0.1, 0)`, **Use Collision ☑** |
| `Camera3D` | Position khoảng `(0, 9, 7)`, Rotation `(-52, 0, 0)` |
| `SwatCharacter` | Kéo `swat_character.tscn` vào |

- **Use Collision** phải bật, nếu không CSGBox3D chỉ là hình vẽ và nhân vật rơi xuyên sàn.
- Position y = −0.1 để mặt trên của hộp dày 0.2 nằm đúng ở y = 0.

### 10.2 Driver test
`test_character_driver.gd` đọc WASD bằng `Input.get_vector("move_left", "move_right", "move_forward", "move_backward")` rồi gán cho `move_input`. Hướng nhìn: mặc định nhìn lên, **giữ chuột phải** thì nhìn sang phải. Bản test chỉ có 2 hướng nhìn; ngắm theo chuột sẽ làm ở giai đoạn sau.

### 10.3 Input Map
**Project → Project Settings → Input Map:** `move_forward` (W), `move_backward` (S), `move_left` (A), `move_right` (D), `shoot` (chuột trái). Mỗi phím chọn **Device: All Devices**.

### 10.4 Kiểm tra (F6)

| Thao tác | Kết quả mong đợi |
|---|---|
| Không bấm gì | Đứng yên trên sàn (y = 0), phát idle |
| W / S / A / D | Đi lên / xuống / trái / phải, 1.8 m/s, phát forward / backward / left / right |
| W + D | Đi chéo, vẫn 1.8 m/s, trộn forward + right |
| Giữ chuột phải + W | Nhân vật nhìn sang phải, đi lên, phát **walk_left** |
| Thả phím | Giảm tốc mượt rồi về idle |

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

### `.gitignore` (bổ sung)
```
# Blender backup files
*.blend1
*.blend2
```
Blender tạo file `.blend1` mỗi lần lưu đè. Quy tắc LFS `*.blend` không áp dụng cho chúng, nên nếu không ignore, chúng sẽ vào thẳng git.

### Quy tắc
- Làm trên nhánh feature (`feat/<tên>`), rồi merge vào `develop`.
- Commit message theo Conventional Commits, ví dụ `feat: add rifle walk backward animation`.
- Kiểm tra `git lfs ls-files` trước khi push: file `.blend`, `.png`, `.glb` phải nằm trong LFS.
- `.godot/` đã được ignore. **Không dùng `git stash -a`**, vì lệnh này cuốn theo cả `.godot/` và gây xung đột khi pop.
- Thư mục chỉ chứa file làm việc mà Godot không cần import thì đặt một file `.gdignore` rỗng vào đó.

---

## Lỗi thường gặp

### Asset và import
| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| Bone chĩa thẳng lên +Z trong Blender | Import FBX với Automatic Bone Orientation tắt | Sửa hướng bone theo 1.4, **trước khi skin** |
| `Version 6100 unsupported` khi import FBX | FBX 6.1 cũ | Dùng mục FBX còn lại trong menu Import (trình import mới) |
| Export FBX ra file khoảng 4KB, rỗng | Object Types không có Armature, hoặc chưa chọn armature | Không export FBX cho animation, xem 6.5 |
| Nhân vật đứng T-pose dù animation đang phát | Rest pose của file nguồn sai (FBX export lại qua Blender) | Dùng `.blend` hoặc GLB (6.5) |
| Track `%GeneralSkeleton:swat_Hips` không tìm thấy bone | Tên bone nguồn còn prefix, BoneMap không map được | Bỏ prefix trong Blender (6.3) |
| `humanoid_bone_map.tres` có type `SkeletonProfileHumanoid` | Save As nhầm ô Profile | Save As ở ô **Bone Map** ngoài cùng (5.1) |
| `ConfigFile parse error … Can't load resource … uid://…` | File `.import` trỏ tới resource đã bị xoá | Đặt lại dòng đó thành `null` hoặc load lại đúng file, rồi Reimport |
| `Skin bind #N contains named bind … but Skeleton3D has no bone` | Lỗi tạm của khung preview khi đang đổi BoneMap | Tự hết sau khi Reimport thành công |
| `Unrecognized UID` lặp liên tục | Main Scene trỏ tới scene đã xoá | Project Settings → Application → Run → Main Scene → xoá giá trị |
| Scene `.tscn` có hàng chục dòng `bones/N/rotation` | Lưu scene khi animation đang phát | Stop rồi mới lưu. Revert pose trên `GeneralSkeleton` |
| Nhân vật đi được một đoạn rồi giật về chỗ cũ mỗi vòng | Animation walk không In Place | Chạy `make_in_place.py` (6.4) |
| File `.blend1` xuất hiện trong git status | Bản backup tự động của Blender | Xoá và thêm `*.blend1` vào `.gitignore` |

### AnimationTree và nhân vật
| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| Thêm điểm vào BlendSpace nhưng không có animation để chọn | **Anim Player** sai đường dẫn (thiếu `../`), AnimationTree thấy 0 animation | Gán lại `../Model/AnimationPlayer` (8.4) |
| Nhân vật đứng T-pose khi có AnimationTree | **Root Node** là `..` (SwatCharacter), không tìm được `%GeneralSkeleton` | Root Node = `../Model` (8.4) |
| Nhân vật không phát gì, state machine đứng ở `Start` | Mũi tên `Start → Locomotion` ở chế độ Enabled | Advance Mode = **Auto** (8.5) |
| Kéo chấm blend hoặc di chuyển nhưng nhân vật luôn đứng idle | AnimationPlayer **Autoplay** idle, ghi đè AnimationTree mỗi frame | Tắt Autoplay trong `swat_model.tscn` (7.3) |
| Không thấy ô Sync trong trình chỉnh BlendSpace2D | Sync nằm trong Inspector của node, không nằm trên thanh công cụ | Click một lần vào node `Locomotion` → Inspector (8.6) |
| Bấm F5/F6 là nhân vật "tự di chuyển" (thực ra là rơi) | Sàn không có collision | `Floor` → **Use Collision ☑** (10.1) |
| Nhân vật lún xuống sàn khoảng 10 cm | Tâm hộp sàn ở y = 0 nên mặt trên ở y = 0.1 | Position y = −0.1 (10.1) |
| Ánh sáng chiếu ngang, nhân vật tối | Nhập góc xoay vào ô Position của DirectionalLight3D | Đặt vào ô **Rotation** (10.1) |
| WASD lúc nhận lúc không | Bộ gõ tiếng Việt (Unikey / EVKey, Telex) chặn phím W/A/S/D | Chuyển bộ gõ sang tiếng Anh, hoặc loại trừ Godot trong cài đặt bộ gõ |
| Phím không vào game dù bộ gõ đã tắt | Khung game nhúng trong editor chưa có focus, hoặc action đặt Device = 0 | Click vào khung game. Đặt Device = All Devices (10.3) |
| Đi chéo nhanh hơn đi thẳng | Thiếu `limit_length(1.0)` | Xem 9.1 |
| Xoay người đôi khi quay vòng dài | Dùng `lerp` thay cho `lerp_angle` | Xem 9.2 |
| Chân trượt trên sàn khi đi | `walk_speed` khác tốc độ của animation | Đặt khoảng 1.8 m/s (6.4) |

---

## Lộ trình

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 0 | Chuẩn bị asset: skeleton, SWAT, material, BoneMap | ✅ |
| 1 | Pipeline animation: idle, walk forward/backward/left/right, In Place, 1 BoneMap | ✅ |
| 2 | Scene nhân vật: `swat_character.tscn`, AnimationTree (BlendSpace2D), `humanoid_character.gd`, scene test | ✅ |
| 3 | Vũ khí: model súng, gắn vào tay (`BoneAttachment3D`), `WeaponData`, bắn hitscan, nạp đạn, hiệu ứng | ⏭ Tiếp theo |
| 4 | Điều khiển người chơi top-down: camera đi theo, WASD theo camera, ngắm theo chuột | ⬜ |
| 5 | Chiến đấu: máu, hitbox/hurtbox, animation thân trên (bắn, nạp đạn, trúng đạn, chết) | ⬜ |
| 6 | Kẻ địch: Navigation, AI | ⬜ |
| 7 | Vòng lặp game: wave, HUD, menu | ⬜ |
| 8 | Hoàn thiện: xoay thân trên khi ngắm, xoay tại chỗ, SFX, VFX, tối ưu | ⬜ |
