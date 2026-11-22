
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
                                                                                     │
                Bước 11–17: player.tscn (ngắm chuột, camera, xoay thân trên, xoay tại chỗ, sprint) ◄┘
```

**Nguyên tắc cốt lõi:** mọi nhân vật và mọi animation đều dùng **cùng một bộ xương** (tên bone giống hệt `skeleton_reference`). Godot đổi tên tất cả về tên chuẩn của `SkeletonProfileHumanoid` qua **một file BoneMap duy nhất**: `humanoid_bone_map.tres`.

## Cấu trúc thư mục

```
assets/characters/
├── skeletons/humanoid/
│   ├── source/skeleton_reference.blend       ← bộ xương gốc (không mesh, không animation)
│   └── humanoid_bone_map.tres                ← BoneMap duy nhất của project
├── models/swat/
│   ├── blender/swat.blend                    ← mesh + rig, chỉ có material slot (không có ảnh)
│   ├── source/textures/*.png                 ← texture diffuse / normal / specular
│   └── materials/M_Swat_Body.tres, M_Swat_Head.tres
└── animations/humanoid/
    ├── source/locomotion/, source/crouch/    ← animation đã chuẩn hoá (.blend), Godot import trực tiếp
    ├── clips/*.res, clips/crouch/*.res       ← clip Godot tách ra khi import
    ├── locomotion.tres                      ← AnimationLibrary: idle, walk 8 hướng, sprint 8 hướng, turn 90/180
    └── crouch.tres                          ← AnimationLibrary: idle, walk 8 hướng, turn 90/180 khi ngồi (Bước 19)
assets/weapons/source/scar_l.blend            ← súng SCAR-L đã chuẩn hoá: mét, nòng +Y, gốc ở báng cầm (Bước 21)
scenes/
├── characters/swat/
│   ├── swat_model.tscn                       ← model SWAT + AnimationPlayer (kho animation)
│   └── swat_character.tscn                   ← nhân vật hoàn chỉnh: thân, collision, AnimationTree
├── weapons/scar_l.tscn                       ← scene súng (kế thừa scar_l.blend), sau này gắn script súng
├── player/player.tscn                        ← người chơi: SwatCharacter + controller + camera
└── tests/
    ├── test_character.tscn                   ← test di chuyển (Giai đoạn 2)
    └── test_player.tscn                      ← test người chơi: ngắm chuột, camera
scripts/
├── characters/
│   ├── humanoid_character.gd                 ← di chuyển, luật xoay, AnimationTree (dùng chung player/AI)
│   ├── spine_twist_modifier.gd               ← xoay thân trên theo hướng ngắm
│   ├── lean_modifier.gd                      ← nghiêng nửa thân trên theo hướng màn hình khi giữ Q / E (Bước 20)
│   └── left_hand_ik_modifier.gd              ← (@tool) IK tay trái bám ốp súng + ngón tay nắm (Bước 21)
├── player/player_controller.gd               ← đọc WASD + chuột, ra lệnh cho nhân vật
├── camera/top_down_camera.gd                 ← camera bám theo nhân vật
└── tests/test_character_driver.gd            ← đọc WASD cho scene test cũ
tools/blender/
├── make_in_place.py                          ← xoá chuyển động trôi của animation
├── make_turn_in_place.py                     ← tách phần xoay (theo Spine, quanh gốc) khỏi clip xoay tại chỗ
├── turn_batch.py                             ← Bước 18.2 tự động: TurnYaw + tách xoay + xoá hông trôi (Bước 19)
└── mixamo_batch_import.py                    ← import hàng loạt FBX Mixamo → .blend (bỏ prefix, In Place, đưa về tâm)
tools/godot/
├── bake_turn_curves.gd                       ← EditorScript: track TurnYaw trong clip turn → Curve *_yaw.tres
└── turn_in_place_import.gd                   ← Import Script thử nghiệm: tách xoay + tạo curve ngay lúc import FBX
assets/characters/animations/humanoid/turn_curves/
├── turn_<left|right>_<90|180>_yaw.tres        ← góc Spine theo thời gian của từng clip turn (Bước 18)
└── crouch_turn_<left|right>_<90|180>_yaw.tres ← như trên, cho clip turn khi ngồi (Bước 19)
```

## Quy ước đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| File animation (nguồn `.blend` và clip `.res`) | `snake_case`: `<hành động>[_<hướng>]`. Chân không phụ thuộc vũ khí nên **không** có tiền tố vũ khí | `idle`, `walk_forward`, `sprint_backward_left`, `turn_left` |
| AnimationLibrary | Theo **mục đích**: `locomotion` (chân), sau này `rifle_upper`, `reactions`… | `locomotion/walk_forward` |
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
Lưu thành `assets/characters/skeletons/humanoid/source/skeleton_reference.blend`.

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
- Đổi tên file theo quy ước, ví dụ `walk_backward.fbx`.

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

Script `tools/blender/make_in_place.py` làm 2 việc:
1. **Xoá phần trôi:** đo độ trôi ngang của Hips từ frame đầu tới frame cuối, rồi trừ dần theo thời gian. Phần trôi bị xoá nhưng **nhún lên xuống và lắc người được giữ**.
2. **Đưa hông về tâm:** dời vị trí ngang **trung bình** của Hips trong cả clip về đúng vị trí hông ở rest pose. Một số clip Mixamo (kể cả clip đã tải với In Place) bị **lệch sẵn khỏi gốc toạ độ** một khoảng cố định. Ví dụ 4 clip sprint thẳng lệch **1.84 m**, khiến model tách khỏi capsule va chạm khi chạy.

Console in ra 2 dòng:
```
[In Place] mixamo.com: drift before = 1.843 m, after = 0.0000 m
[In Place] mixamo.com: center offset before = 1.849 m, after = 0.0000 m
```

**Cách 1: trong Blender**
1. Mở file `.blend` của animation đi (không áp dụng cho idle).
2. Tab **Scripting** → **Text → Open** → `tools/blender/make_in_place.py` → **Run Script** (Alt+P).
3. **Window → Toggle System Console** sẽ hiện dòng `[In Place] ... drift before = 1.843 m, after = 0.0000 m`.
4. Space để phát: nhân vật bước tại chỗ. **Ctrl+S.**

**Cách 2: chạy hàng loạt bằng PowerShell** (tại thư mục project)
```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
foreach ($n in "forward","backward","left","right", "forward_left","backward_left","forward_right","backward_right") {
  & $blender -b "assets\characters\animations\humanoid\source\walk_$n.blend" `
    --python "tools\blender\make_in_place.py" --python-expr "import bpy; bpy.ops.wm.save_mainfile()"
}
```

Lưu ý:
- Chạy lại lần 2 trên cùng file cũng vô hại, vì lúc đó độ trôi đã bằng 0.
- Script **tự chuyển về Object Mode** trước khi chạy. Nếu file được lưu lúc armature đang ở Edit Mode, Blender không tính tư thế animation và mọi phép đo ra 0.
- Độ trôi đo được cho biết tốc độ thật của animation: khoảng **1.8 m/s** với các clip walk hiện có. Dùng con số này cho `walk_speed`.
- ⚠️ Trong Blender, luôn **Tab về Object Mode trước khi Ctrl+S**.

### 6.4a Import hàng loạt nhiều clip (khuyên dùng khi có từ 2 clip trở lên)
`tools/blender/mixamo_batch_import.py` gộp Bước 6.2–6.5 cho **cả một thư mục FBX** trong một lệnh. Với mỗi file `.fbx`:
1. Import với Automatic Bone Orientation ☐, Ignore Leaf Bones ☐.
2. Bỏ prefix tên bone (`mixamorig:Hips` → `Hips`). Track animation tự đổi theo.
3. Đặt tên action `mixamo.com`, đặt khung thời gian scene bằng độ dài clip.
4. Với `--in-place`: đo quãng đường trôi (ra **tốc độ m/s**), xoá phần trôi, đưa hông về tâm.
5. Lưu ở **Object Mode** thành `<thư mục đích>/<tên file>.blend`.

**Chuẩn bị:** đặt tên file FBX **đúng tên clip mong muốn** (ví dụ `sprint_forward.fbx`), gom vào một thư mục **ngoài project**.
```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
& $blender -b --python "tools\blender\mixamo_batch_import.py" -- `
  "C:\Users\User\Downloads\mixamo_sprint" `
  "assets\characters\animations\humanoid\source" `
  --in-place
```
Cuối cùng script in bảng: `clip | dài (s) | trôi (m) | tốc độ (m/s)`. Dòng nào có `⚠ còn N track có prefix` thì clip đó cần kiểm tra lại.

**Đo tốc độ clip:**
- Muốn script đo được tốc độ thì tải từ Mixamo với **In Place ☐ (tắt)**: tốc độ = quãng đường trôi ÷ thời lượng.
- Nếu đã lỡ tải với In Place ☑ (độ trôi bằng 0), vẫn đo được bằng **bàn chân**: lúc chân chạm đất, nó trượt ngược về sau so với hông đúng bằng tốc độ di chuyển. Cách này đã kiểm chứng trên clip walk, cho kết quả 1.76–1.85 m/s, khớp với cách đo bằng độ trôi.

### 6.4b Animation xoay tại chỗ (Rifle Turn Left / Right)
> ⚠️ **Cách cũ.** Xoay ngược quanh Hips làm chân trụ trượt. Clip turn hiện dùng cách ở **Bước 18** (xoay theo Spine, quanh gốc, có curve). Phần dưới giữ lại để tham khảo.

Clip Mixamo gốc vừa **bước chân** vừa **xoay hông** khoảng 80°. Trong game, code tự xoay thân nhân vật (Bước 15). Nếu giữ phần xoay trong clip, nhân vật sẽ xoay gấp đôi. Vì vậy cần **xoá phần xoay hông, giữ bước chân**.

Script `tools/blender/make_turn_in_place.py`:
1. Đo hướng hông ở từng frame bằng đường nối 2 đùi.
2. Xoay ngược Hips quanh trục đứng đi qua chính nó, đúng bằng góc đã xoay so với frame đầu.
3. Ghi lại keyframe xoay của Hips.

Chạy **lần lượt 2 script** cho mỗi file turn. Thứ tự quan trọng: xoá xoay trước, xoá trôi sau.
```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
foreach ($n in "left","right") {
  $f = "assets\characters\animations\humanoid\source\turn_$n.blend"
  & $blender -b $f --python "tools\blender\make_turn_in_place.py" --python-expr "import bpy; bpy.ops.wm.save_mainfile()"
  & $blender -b $f --python "tools\blender\make_in_place.py"      --python-expr "import bpy; bpy.ops.wm.save_mainfile()"
}
```
Kết quả in ra console, **ghi lại góc xoay** để dùng ở Bước 15:
```
[Turn In Place] ... hips turned +76.6 deg -> now max 0.00 deg     ← turn_left:  77°, 1.30 s
[Turn In Place] ... hips turned -84.7 deg -> now max 0.00 deg     ← turn_right: 85°, 1.47 s
```
Loop Mode của 2 clip turn để **Linear**. Khi cần xoay quá 90°, clip lặp lại để chân bước tiếp.

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
5. Nếu sau khi import lại thấy cảnh báo `ext_resource, invalid UID … using text path instead`: clip được tạo lại với UID mới nhưng library vẫn ghi UID cũ. Godot vẫn load đúng theo đường dẫn. Để hết cảnh báo, mở **Manage Animations** và bấm **💾** ở dòng library, hoặc chạy **Project → Tools → Upgrade Project Files…**.

### 7.2 AnimationLibrary
1. Tạo **một lần**: chuột phải `animations/humanoid/` → **Create New → Resource → AnimationLibrary** → `locomotion.tres`.
2. Clip lưu dạng `.res` (nhị phân, nhẹ). Library lưu dạng `.tres`, vì chỉ chứa tham chiếu nên dễ xem diff trong git.
3. **Chia library theo mục đích, không theo vũ khí.** `locomotion` chứa toàn bộ chuyển động chân (idle, walk, sprint, turn), dùng chung cho mọi vũ khí. Sau này, clip thân trên của từng vũ khí (bắn, nạp đạn) vào library riêng như `rifle_upper`, rồi trộn với chân bằng Blend2 có Filter. Nhờ vậy số clip là **cộng** chứ không **nhân** khi thêm vũ khí.

### 7.2b Đổi tên library hoặc clip (khi refactor)
Đổi tên phải sửa **đủ 4 chỗ**, nếu không AnimationTree sẽ không tìm thấy animation (nhân vật đứng im):
1. **File** (`.tres`, `.res`): đổi trong **FileSystem của Godot** để giữ UID.
2. **Tên gọi của library trong AnimationPlayer**: Manage Animations → double-click tên library → đổi. *Tên gọi này độc lập với tên file.*
3. **Tên animation trong library**: Manage Animations → đổi từng tên.
4. **Mọi node trong AnimationTree** trỏ tới tên cũ (các điểm BlendSpace, các state). Chọn từng node → Inspector → Animation.

Kiểm tra: chọn `AnimationTree` → mỗi node phải hiện được animation. Nếu Inspector để trống ô Animation thì tên đó không còn tồn tại.

### 7.3 Scene model (kho animation)
1. Chuột phải `swat.blend` → **New Inherited Scene** → lưu `scenes/characters/swat/swat_model.tscn`.
2. Thêm **`AnimationPlayer` làm con trực tiếp của node gốc**, giữ Root Node = `..`.
   Node gốc là owner của `GeneralSkeleton`, nên `%GeneralSkeleton` mới tìm thấy được.
3. Panel Animation → **Animation → Manage Animations**:
   1. **Load Library** → `locomotion.tres`.
   2. Icon **Load Animation** → chọn clip `.res` → đặt tên (`idle`, `walk_forward`…).
   3. ⚠️ Bấm **💾** ở dòng library để ghi vào file `.tres`.
4. ⚠️ **Không bật Autoplay.** Khi đã có AnimationTree (Bước 8), AnimationPlayer chỉ là kho chứa animation. Nếu autoplay idle, nó sẽ ghi đè kết quả của AnimationTree mỗi frame. Muốn xem thử thì bấm ▶ rồi bấm Stop.
5. ⚠️ Bấm **Stop trước khi Ctrl+S.** Nếu không, Godot lưu tư thế đang phát thành các dòng `bones/N/rotation` trong scene.

### 7.4 Thêm animation mới (quy trình rút gọn)
1. Tải từ Mixamo (6.1).
2. Blender: import, bỏ prefix (6.2–6.3). Animation đi không có In Place thì chạy `make_in_place.py` (6.4). Animation xoay tại chỗ thì chạy `make_turn_in_place.py` rồi `make_in_place.py` (6.4b). Lưu vào `source/` ở **Object Mode** (6.5).
3. Godot: Quick Load BoneMap, bật Unmapped Bones, đặt Loop, Save to File (7.1).
4. Thêm clip vào `locomotion.tres` và nhớ bấm 💾 (7.3).
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
         ├ Locomotion (BlendSpace2D, 9 điểm)
         ├ TurnLeft   (thêm ở Bước 15)
         └ TurnRight  (thêm ở Bước 15)
```

⚠️ Script của `SwatCharacter` phải là **file** `scripts/characters/humanoid_character.gd`, **không phải script nhúng (built-in)**. Khi bấm Attach Script, bỏ tích **Built-in Script**. Kiểm tra: ô Script trong Inspector phải hiện `humanoid_character.gd`, không phải `swat_character.tscn::GDScript_…`.

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
   | `(0, 0)` | `locomotion/idle` |
   | `(0, 1)` | `locomotion/walk_forward` |
   | `(0, -1)` | `locomotion/walk_backward` |
   | `(-1, 0)` | `locomotion/walk_left` |
   | `(1, 0)` | `locomotion/walk_right` |
   | `(0.71, 0.71)` | `locomotion/walk_forward_right` |
   | `(-0.71, 0.71)` | `locomotion/walk_forward_left` |
   | `(-0.71, -0.71)` | `locomotion/walk_backward_left` |
   | `(0.71, -0.71)` | `locomotion/walk_backward_right` |

   Quy ước: **X dương là sang phải** của nhân vật, **Y dương là phía trước**.
   - **Chỉ 1 điểm idle** ở `(0, 0)`. Nhiều điểm trùng vị trí làm Godot chia tam giác trộn bị lỗi.
   - Điểm chéo đặt ở **(±0.71, ±0.71)**, tức là nằm trên **vòng tròn bán kính 1**, không phải (±0.5, ±0.5). Khi đi chéo hết tốc độ, script đưa vào blend là `(0.71, 0.71)`, nên điểm chéo phải nằm đúng ở đó mới phát đúng clip chéo.
   - Nếu ô nhập tự làm tròn, tạm đặt Snap về `0.01` rồi gõ lại.
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
| `aim_direction: Vector3` | Hướng muốn ngắm, toạ độ thế giới (trước Bước 12 tên là `look_direction`) |

Thông số nhóm **Movement** trong Inspector: `walk_speed` (1.8, khớp tốc độ animation), `acceleration` (12), `blend_smoothing` (10). Các thông số xoay ở nhóm **Turning**, xem Bước 12–15.

Bước này mô tả phiên bản đầu tiên (thân luôn xoay theo hướng nhìn). Từ Bước 12, phần xoay được viết lại thành `_update_facing` với luật ngưỡng.

### 9.1 `_apply_movement`: di chuyển
1. `limit_length(1.0)`: giới hạn độ dài input, để đi chéo (W+D) không nhanh hơn 41%.
2. `move_toward(target, acceleration * delta)`: tăng tốc và giảm tốc dần, mất khoảng 0.15 giây để đạt 1.8 m/s.
3. Trọng lực: trên sàn thì `velocity.y = 0`, trên không thì cộng `get_gravity() * delta`.
4. `move_and_slide()`: di chuyển, trượt dọc tường, cập nhật `is_on_floor()`.

### 9.2 Xoay người (phiên bản đầu, đã thay ở Bước 12)
1. Bỏ trục Y của hướng nhìn, vì chỉ xoay ngang.
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
`test_character_driver.gd` đọc WASD bằng `Input.get_vector("move_left", "move_right", "move_forward", "move_backward")` rồi gán cho `move_input`. Hướng ngắm (`aim_direction`): mặc định nhìn lên, **giữ chuột phải** thì nhìn sang phải. Bản test chỉ có 2 hướng nhìn; ngắm theo chuột thật làm ở Bước 11.

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

# Phần IV: Điều khiển người chơi

**Mục tiêu:** nhân vật ngắm theo con trỏ chuột. Góc nhỏ thì **chỉ thân trên vặn**, góc lớn thì **chân bước xoay** theo.

```
aim_yaw  = góc tới con trỏ chuột          → thân trên (SpineTwistModifier)
body_yaw = rotation.y của SwatCharacter    → hông và chân
twist    = angle_difference(body_yaw, aim_yaw), giới hạn ±max_twist_angle
```

| Trạng thái | Độ lệch giữa ngắm và thân | Chân | Thân trên |
|---|---|---|---|
| Đứng yên | ≤ 60° | đứng im | vặn đúng bằng `twist` |
| Đứng yên | > 60° liên tục 0.1 s | **xoay đều 150°/s** + phát `TurnLeft`/`TurnRight` cho tới khi còn lệch < 5° | vặn phần còn thiếu |
| Đang đi | bất kỳ | luôn bám theo hướng ngắm, BlendSpace chọn kiểu đi | vặn phần còn thiếu |

## Bước 11: Ngắm theo chuột và camera

### 11.1 Cấu trúc
```
scenes/player/player.tscn
Player (Node3D)              ← script: player_controller.gd
 ├ SwatCharacter             ← instance swat_character.tscn
 └ CameraRig (Node3D)        ← script: top_down_camera.gd
     └ Camera3D              ← Position (0, 9, 6), Rotation (-56, 0, 0), FOV 50
```
Camera **không** làm con của `SwatCharacter`. Nhân vật xoay theo chuột, nếu camera là con thì camera sẽ quay theo. `CameraRig` chỉ đi theo **vị trí**.

### 11.2 `scripts/camera/top_down_camera.gd`
- `@export var target: Node3D` (gán `SwatCharacter`), `follow_speed` (8).
- `_ready()`: đặt camera ngay vị trí target, để không trượt từ gốc toạ độ tới.
- `_process(delta)`: `global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))`.
  - Camera thuộc phần hiển thị nên đặt trong `_process` (chạy theo FPS).
  - `1 - exp(-k·delta)` là công thức làm mượt **không phụ thuộc FPS**.

### 11.3 `scripts/player/player_controller.gd`
- `@export`: `character: HumanoidCharacter`, `camera: Camera3D`, `aim_height` (1.2 m), `aim_dead_zone` (0.3 m).
- **WASD theo camera:** `Basis(Vector3.UP, camera.global_rotation.y) * Vector3(input.x, 0, input.y)`. Xoay camera kiểu isometric thì W vẫn là lên trên màn hình.
- **Tia chuột:**
  1. `camera.project_ray_origin(mouse)` và `project_ray_normal(mouse)` đổi điểm 2D trên màn hình thành tia 3D.
  2. `Plane(Vector3.UP, nhân_vật + UP * aim_height).intersects_ray(...)` tìm điểm tia cắt mặt phẳng ngang cao 1.2 m (ngang nòng súng). Trả về `null` nếu tia không cắt.
  3. `aim_direction = điểm_cắt − vị_trí_nhân_vật` (bỏ trục Y). Chuột gần chân hơn `aim_dead_zone` thì giữ hướng cũ, tránh nhân vật giật.
- `Player` là cha của `SwatCharacter`, nên `_physics_process` của controller chạy **trước** nhân vật. Lệnh luôn được gán trước khi nhân vật di chuyển trong cùng frame.

### 11.4 Dựng scene
1. `player.tscn` theo cấu trúc 11.1. Gán export: `CameraRig.target` = `SwatCharacter`, `Player.character` = `SwatCharacter`, `Player.camera` = `CameraRig/Camera3D`.
2. `scenes/tests/test_player.tscn`: duplicate `test_character.tscn`, bỏ script driver, xoá `SwatCharacter` và `Camera3D`, kéo `player.tscn` vào. Mở rộng sàn `(40, 0.2, 40)` và thêm vài **CSGBox3D** (Use Collision ☑) làm mốc để thấy camera di chuyển.

## Bước 12: Tách hướng ngắm và hướng thân

Trong `humanoid_character.gd`:
- Đổi tên `look_direction` thành **`aim_direction`** (sửa cả `player_controller.gd` và `test_character_driver.gd`; tìm bằng **Ctrl+Shift+F**).
- Thêm biến công khai, cho script khác đọc:

  | Biến | Ý nghĩa | Ai đọc |
  |---|---|---|
  | `aim_yaw` | góc ngắm (radian) | debug, Bước 13 |
  | `twist` | độ lệch ngắm so với thân, đã giới hạn ±`max_twist_angle` | `SpineTwistModifier` |
  | `is_turning` | đang xoay chân tại chỗ | state machine (Bước 15) |

- **`_update_facing(delta)`** thay cho `_apply_facing`:
  1. `aim_yaw = atan2(-dir.x, -dir.z)`.
  2. `diff = angle_difference(rotation.y, aim_yaw)`: độ lệch ngắn nhất, từ −180° đến 180°. **Dương = chuột bên trái thân.**
  3. `is_moving` = tốc độ ngang > `moving_threshold` (0.2 m/s). Dùng vận tốc thật, không dùng `move_input`.
  4. Đang đi: `rotation.y = lerp_angle(rotation.y, aim_yaw, moving_turn_speed * delta)`.
  5. Đứng yên: máy trạng thái 2 trạng thái (**đứng im ⇄ đang xoay**) với **vùng đệm (hysteresis)**: bắt đầu xoay khi lệch > 60°, dừng khi lệch < 5°. Hai ngưỡng khác nhau để chân không giật qua lại khi chuột rung quanh mốc 60°.
  6. `twist = clampf(angle_difference(rotation.y, aim_yaw), -max, max)`, tính **sau** khi thân đã xoay trong frame.

## Bước 13: Xoay thân trên (`SpineTwistModifier`)

### 13.1 `scripts/characters/spine_twist_modifier.gd`
```gdscript
class_name SpineTwistModifier
extends SkeletonModifier3D

var twist := 0.0
@export var bone_weights := {&"Spine": 0.25, &"Chest": 0.35, &"UpperChest": 0.4}
```
- `_ready()`: tìm số thứ tự bone **một lần** bằng `find_bone`, lưu vào `_bone_ids`.
- `_process_modification()`: với mỗi bone:
  1. `up_in_bone = (bone_global_pose.basis.orthonormalized().inverse() * Vector3.UP).normalized()`: trục đứng của skeleton nhìn từ hệ toạ độ của bone. Nhờ vậy code không phụ thuộc vào hướng trục của từng bone.
  2. `set_bone_pose_rotation(id, get_bone_pose_rotation(id) * Quaternion(up_in_bone, twist * weight))`. Nhân **bên phải** nghĩa là xoay thêm trong hệ của bone, sau tư thế animation.

### 13.2 Vì sao tổng tỉ lệ bằng 1.0
- Tay nối với `UpperChest`, sau này súng nằm trong tay. Ngực phải chỉ **đúng hướng chuột**, nên `Spine + Chest + UpperChest = 1.0`.
- Chia cho 3 bone để lưng cong đều. Dồn vào 1 bone trông như gãy lưng.
- Không đưa `Neck`/`Head` vào, vì đầu đi theo ngực là đủ, thêm vào sẽ quá tay.

### 13.3 Gắn vào nhân vật (bằng code, không cần Editable Children)
```gdscript
@onready var skeleton: Skeleton3D = $Model/Skeleton_Reference/GeneralSkeleton
var _spine_twist: SpineTwistModifier

func _ready() -> void:
	_spine_twist = SpineTwistModifier.new()
	skeleton.add_child(_spine_twist)        # modifier phải là con trực tiếp của skeleton

func _update_spine_twist(delta: float) -> void:   # gọi trong _physics_process
	var weight := clampf(twist_smoothing * delta, 0.0, 1.0)
	_spine_twist.twist = lerp_angle(_spine_twist.twist, twist, weight)
```

### 13.4 Cần biết về `SkeletonModifier3D`
- Thứ tự mỗi frame: AnimationTree đặt tư thế → modifier cộng thêm → vẽ → Godot **khôi phục** tư thế gốc. Vì vậy góc xoay **không bị cộng dồn**.
- Muốn đọc tư thế **đã** có phần modify (ví dụ để đo), phải đọc trong tín hiệu `skeleton.skeleton_updated`. Đọc ở thời điểm khác sẽ thấy tư thế **chưa** modify.
- Xem modifier khi game đang chạy: dock Scene → tab **Remote** → `.../GeneralSkeleton/SpineTwistModifier`.

## Bước 14: Tinh chỉnh

### 14.1 Ba cải tiến trong `_update_facing`
| Vấn đề | Cách sửa |
|---|---|
| Vụt chuột qua cũng làm chân xoay | **`turn_delay`** (0.1 s): bộ đếm `_over_threshold_time += delta` khi lệch quá ngưỡng, về 0 khi về trong ngưỡng. Đủ 0.1 giây mới bắt đầu xoay |
| Chân xoay chậm dần (lerp) không giống người bước | **Xoay đều theo độ/giây:** `rotation.y = wrapf(rotation.y + clampf(diff, -step, step), -PI, PI)`, với `step = deg_to_rad(idle_turn_speed) * delta`. Thời gian xoay **biết trước**, cần cho Bước 15 |
| Khó chỉnh vì không thấy số | **Debug:** mũi tên **đỏ** (hướng ngắm, ngang ngực), mũi tên **xanh** (hướng chân, sát sàn), `Label3D` trên đầu hiện góc thân, góc ngắm, twist và state đang phát. Bật/tắt bằng `show_debug` |

- `wrapf(x, -PI, PI)` đưa góc về khoảng −180° đến 180° sau khi cộng dồn.
- Mũi tên dùng `top_level = true` để không xoay theo thân. `Label3D` dùng `billboard` (luôn quay về camera) và `no_depth_test` (không bị model che).

### 14.2 Thông số nhóm Turning
| Thông số | Mặc định | Ý nghĩa |
|---|---|---|
| `max_twist_angle` | 60° | Đứng yên: lệch quá góc này thì chân xoay. Muốn xoay sớm hơn thì đặt 45 |
| `turn_stop_angle` | 5° | Đang xoay: lệch dưới góc này thì dừng |
| `turn_delay` | 0.1 s | Thời gian phải lệch liên tục trước khi xoay chân |
| `idle_turn_speed` | 150°/s | Tốc độ xoay chân khi đứng yên. **Phải khớp với Timeline Length ở Bước 15** |
| `moving_turn_speed` | 12 | Tốc độ thân bám theo hướng ngắm khi đang đi |
| `moving_threshold` | 0.2 m/s | Nhanh hơn mức này coi là đang đi |
| `twist_smoothing` | 15 | Độ mượt của thân trên |

### 14.3 Chỉnh khi game đang chạy
F6 → dock Scene → tab **Remote** → chọn `Player/SwatCharacter` → đổi số trong Inspector, có tác dụng ngay. Giá trị trong Remote **không tự lưu**: ghi lại rồi nhập vào `swat_character.tscn` sau khi dừng game.

## Bước 15: Animation xoay tại chỗ
> ⚠️ **Cách cũ, đã thay bằng Bước 18.** Thân xoay đều 150°/s trong khi clip có nhịp riêng nên chân trượt. State `TurnLeft`/`TurnRight` đã xoá, `idle_turn_speed` đã bỏ.


### 15.1 Chuẩn bị clip
Làm theo 6.4b: `make_turn_in_place.py` rồi `make_in_place.py` cho `turn_left` và `turn_right`. Ghi lại góc: **77°** (trái), **85°** (phải).

### 15.2 Thêm state vào State Machine
Trong `swat_character.tscn` → `AnimationTree`:
1. Chuột phải → **Add Animation** → `locomotion/turn_left`, đặt tên **`TurnLeft`**. Làm tương tự với `TurnRight`.
2. Click **một lần** vào từng node → Inspector:

   | Thuộc tính | `TurnLeft` | `TurnRight` |
   |---|---|---|
   | Use Custom Timeline | ☑ | ☑ |
   | **Timeline Length** | **0.51** | **0.57** |
   | Stretch Time Scale | ☑ | ☑ |
   | Loop Mode | Linear | Linear |

   **Công thức:** `Timeline Length = góc của clip ÷ idle_turn_speed`. Trái: 77 / 150 = 0.51. Phải: 85 / 150 = 0.57. Chân trong animation xoay cùng tốc độ với thân thì bàn chân mới không trượt.
3. Nối 4 mũi tên: `Locomotion ⇄ TurnLeft`, `Locomotion ⇄ TurnRight`. Mỗi mũi tên đặt:
   - **Xfade Time** `0.15`
   - **Switch Mode** `Immediate`
   - **Advance Mode** **`Enabled`** (mặc định). **KHÔNG** đặt Auto: Auto làm state machine tự nhảy sang Turn dù nhân vật không xoay. Chỉ `Start → Locomotion` mới là Auto.

### 15.3 Code
```gdscript
@export var idle_turn_speed := 150.0
const PLAYBACK_PATH := &"parameters/playback"
var _playback: AnimationNodeStateMachinePlayback
var _anim_state := &"Locomotion"

func _ready() -> void:
	_playback = anim_tree.get(PLAYBACK_PATH)
	...

func _update_state_machine() -> void:   # gọi ngay sau _update_facing
	var wanted := &"Locomotion"
	if is_turning:
		wanted = &"TurnLeft" if angle_difference(rotation.y, aim_yaw) > 0.0 else &"TurnRight"
	if wanted != _anim_state:
		_anim_state = wanted
		_playback.travel(wanted)
```
- `parameters/playback` là đối tượng điều khiển state machine. `travel(tên)` tự tìm đường theo các mũi tên và trộn theo Xfade Time.
- Chỉ gọi `travel()` khi state mong muốn **thay đổi**. Gọi mỗi frame có thể làm animation khựng.
- Chiều xoay dùng cùng quy ước dấu với `twist`: dương là trái.

### 15.4 Tinh chỉnh tốc độ xoay
Đổi `idle_turn_speed` thì **phải đổi Timeline Length** theo công thức:

| Muốn | `idle_turn_speed` | TurnLeft | TurnRight |
|---|---|---|---|
| Chậm, nặng nề | 100 | 0.77 | 0.85 |
| **Mặc định** | **150** | **0.51** | **0.57** |
| Nhanh, kiểu arcade | 200 | 0.39 | 0.43 |

Bàn chân trượt về phía trước thì **giảm** Timeline Length. Bước chân quá dồn dập thì **tăng**.

### 15.5 Kiểm tra (F6 trên `test_player.tscn`)
| Thao tác | Kết quả mong đợi |
|---|---|
| Đứng yên, chuột lệch dưới 60° | Chữ debug `Locomotion`, mũi tên xanh đứng im, ngực vặn theo mũi tên đỏ |
| Vụt chuột ra sau rồi trả lại nhanh | Chân không xoay |
| Đứng yên, lệch khoảng 90° sang trái | `TurnLeft`, chân bước xoay khoảng 0.6 s, rồi về `Locomotion` |
| Lệch sang phải | `TurnRight` |
| Lệch 150° | Clip xoay lặp lại, xoay khoảng 1 s |
| Đang xoay thì bấm W | Về ngay `Locomotion`, đi bình thường |
| Giữ W + D, nhìn lên | Phát đúng clip `walk_forward_right` (blend khoảng (0.71, 0.71)) |

## Bước 16: Sprint 8 hướng (giữ Shift)

**Thiết kế:** giữ Shift thì tốc độ tối đa tăng từ `walk_speed` lên `run_speed`, **vẫn ngắm theo chuột**. Luật xoay (vặn thân trên, xoay tại chỗ) giữ nguyên. Chân đổi sang clip sprint theo đúng hướng chạy so với hướng nhìn.

```
BlendSpace "Locomotion": 17 điểm, 2 vòng

                     sprint_forward (0, 3.2)
     sprint_fwd_left (-2.26, 2.26)   sprint_fwd_right (2.26, 2.26)
                    walk: vòng bán kính 1 (8 điểm)
 sprint_left (-3.2, 0) ──────── idle (0, 0) ──────── sprint_right (3.2, 0)
     sprint_back_left (-2.26, -2.26) sprint_back_right (2.26, -2.26)
                     sprint_backward (0, -3.2)
```

### 16.1 Clip
1. Mixamo: 8 clip chạy cầm súng (forward, backward, left, right, 4 hướng chéo). Thiết lập như 6.1. Đặt tên `sprint_<hướng>.fbx`.
2. Chạy `mixamo_batch_import.py` với `--in-place` (6.4a). Lưu vào `source/sprint_<hướng>.blend`.
3. Kiểm tra **hông nằm đúng tâm**: 4 clip thẳng ban đầu lệch 1.84 m, đã sửa bằng bước "đưa hông về tâm" của `make_in_place.py` (6.4).
4. Import trong Godot như 7.1: **Loop Mode Linear cho cả 8 clip**, Save to File `clips/sprint_<hướng>.res`. Thêm vào library `locomotion`.

### 16.2 Tốc độ đo được (bằng bàn chân)
| Clip | m/s | | Clip | m/s |
|---|---|---|---|---|
| `sprint_forward` | 6.24 | | `sprint_forward_left` | 5.69 |
| `sprint_backward` | 6.06 | | `sprint_forward_right` | 5.86 |
| `sprint_left` | 6.11 | | `sprint_backward_left` | 5.44 |
| `sprint_right` | 6.37 | | `sprint_backward_right` | 5.06 |

Chọn **`run_speed = 5.8 m/s`** (trung bình, nghiêng về các hướng chéo vốn chậm hơn).

### 16.3 Input Map
**Project Settings → Input Map:** thêm action **`run`** → phím **Shift** → **Device: All Devices**.

### 16.4 BlendSpace
Chọn `AnimationTree` → click **một lần** vào node `Locomotion` → Inspector:
- **Min Space** `(-3.5, -3.5)`, **Max Space** `(3.5, 3.5)`. Khung mặc định ±1 không chứa được điểm sprint.
- **Snap** `(0.01, 0.01)`, để gõ được 2.26.

Thêm 8 điểm trên **vòng bán kính R = run_speed ÷ walk_speed = 5.8 ÷ 1.8 ≈ 3.2**, điểm chéo ở `R × 0.707 ≈ 2.26`:

| Toạ độ | Animation | | Toạ độ | Animation |
|---|---|---|---|---|
| `(0, 3.2)` | `locomotion/sprint_forward` | | `(2.26, 2.26)` | `locomotion/sprint_forward_right` |
| `(0, -3.2)` | `locomotion/sprint_backward` | | `(-2.26, 2.26)` | `locomotion/sprint_forward_left` |
| `(-3.2, 0)` | `locomotion/sprint_left` | | `(-2.26, -2.26)` | `locomotion/sprint_backward_left` |
| `(3.2, 0)` | `locomotion/sprint_right` | | `(2.26, -2.26)` | `locomotion/sprint_backward_right` |

### 16.5 Code
**`humanoid_character.gd`:**
```gdscript
@export var run_speed := 5.8         ## m/s, khớp tốc độ của animation sprint (giữ Shift)
var is_running := false              ## controller gán, giống move_input / aim_direction

# _apply_movement
	var max_speed := run_speed if is_running else walk_speed
	var target := Vector3(move_input.x, 0.0, move_input.z).limit_length(1.0) * max_speed

# _update_animation: cho chấm blend ra tới vòng sprint
	_blend = _blend.lerp(target.limit_length(run_speed / walk_speed), clampf(blend_smoothing * delta, 0.0, 1.0))
```
**`player_controller.gd`:**
```gdscript
	character.is_running = Input.is_action_pressed("run")
```
- Toạ độ blend vẫn là `vận tốc ÷ walk_speed`. Đi bộ ra vòng trong (1), chạy hết tốc độ ra vòng ngoài (3.2). Lúc đang tăng tốc, chấm nằm giữa 2 vòng và Godot trộn walk với sprint theo tỉ lệ.
- Nếu giữ `limit_length(1.0)` như cũ, chấm blend không bao giờ ra tới vòng sprint, và nhân vật chạy 5.8 m/s nhưng phát animation đi bộ (chân trượt rất nặng).

### 16.6 Tinh chỉnh
Đổi `run_speed` thì **phải đổi bán kính vòng sprint**: `R = run_speed ÷ walk_speed`, điểm chéo `= R × 0.707`.

| Muốn | `run_speed` | Điểm thẳng | Điểm chéo |
|---|---|---|---|
| Chạy nước rút (mặc định) | 5.8 | 3.2 | 2.26 |
| Chạy vừa phải | 4.5 | 2.5 | 1.77 |

Clip sprint được quay ở khoảng 6 m/s. Giảm `run_speed` nhiều thì bước chân sẽ trượt. Nếu muốn chạy chậm hơn, nên dùng clip "Rifle Run" (chạy thường) thay cho clip sprint.

### 16.7 Kiểm tra
| Thao tác | Kết quả mong đợi |
|---|---|
| Shift + W | Tăng tốc khoảng 0.3 s lên 5.8 m/s, blend (0, 3.2), phát `sprint_forward` |
| Shift + W + D | blend khoảng (2.28, 2.28), phát `sprint_forward_right` |
| Shift + W, chuột bên phải | Thân xoay −90°, blend (−3.2, 0), phát **`sprint_left`** |
| Shift + S, chuột phía trên | blend (0, −3.2), phát `sprint_backward` |
| Thả Shift | Giảm về 1.8 m/s, về clip walk |
| Giữ Shift khi đứng yên | Không đổi gì, vẫn idle và xoay tại chỗ |

## Bước 17: Camera mượt trên màn hình tần số cao (Physics Interpolation)

**Triệu chứng:** khi sprint, nhân vật bị **nhoè, rung, như có bóng mờ**.

**Nguyên nhân:** màn hình 144 Hz vẽ 144 frame/giây, nhưng nhân vật chỉ di chuyển trong `_physics_process` (**60 lần/giây**), còn camera di chuyển trong `_process` (**144 lần/giây**). Khoảng 2/3 số frame, camera trượt đi trong khi nhân vật đứng yên, rồi frame sau nhân vật nhảy bù lên. Chạy càng nhanh càng rõ: sprint 5.8 m/s thì mỗi lần nhảy gần 10 cm.

### 17.1 Bật nội suy vật lý
**Project Settings → General → bật Advanced Settings → Physics → Common → Physics Interpolation ☑.**
Vật lý vẫn tính 60 lần/giây, nhưng khi vẽ, Godot nội suy vị trí của các node di chuyển trong `_physics_process` (như `CharacterBody3D`) giữa 2 bước. Nhân vật mượt ở mọi tần số màn hình.

### 17.2 Sửa `top_down_camera.gd`
```gdscript
@export var follow_speed := 10.0      ## viết 10.0 (float), viết 10 thì Inspector chỉ cho nhập số nguyên

func _ready() -> void:
	# Rig tự di chuyển trong _process nên tắt nội suy cho nó (Camera3D con tắt theo, chế độ Inherit)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	...

func _process(delta: float) -> void:
	# Bám theo vị trí ĐANG ĐƯỢC VẼ (đã nội suy), không phải vị trí vật lý nhảy 60 lần/giây
	var target_pos := target.get_global_transform_interpolated().origin
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target_pos, weight)
```
- `get_global_transform_interpolated()`: vị trí đã nội suy, đúng vị trí nhân vật đang hiện trên màn hình.
- Node nào tự di chuyển trong `_process` (camera, UI 3D…) thì phải **tắt** nội suy cho node đó. Nếu không, nó bị trễ thêm 1 bước vật lý và rung theo kiểu khác.

### 17.3 Lưu ý
- **Khi sprint, nhân vật lệch về phía hướng chạy** khoảng `tốc độ ÷ follow_speed` (5.8 ÷ 10 ≈ 0.6 m). Đây là độ trễ có chủ ý của camera. Muốn bám sát hơn thì tăng `follow_speed` lên 15–20.
- AnimationTree đang để **Callback Mode = Physics**, nên tư thế xương cập nhật 60 lần/giây. Nếu thấy tay chân hơi giật ở màn 144 Hz, đổi sang **Idle**.

## Bước 18: Xoay tại chỗ theo Spine (Turn 90 / 180)

Thay cho Bước 15. Mục tiêu: **khi xoay, trục của nhân vật xoay cùng bone Spine trong animation**, đúng nhịp bước chân của clip gốc.

### 18.1 Ý tưởng
Clip turn của Mixamo vừa bước chân vừa **xoay cả người**. Trong game, thứ xoay là `CharacterBody3D`, nên phải tách 2 phần ra:
1. **Blender:** ghi góc của bone Spine ở từng frame vào một Empty `TurnYaw` (đây là "curve"), rồi xoay ngược cả bộ xương đúng góc đó → trong clip, Spine nhìn thẳng một hướng, chân vẫn bước.
2. **Godot:** khi xoay, code đặt `rotation.y = góc lúc bắt đầu + góc Spine của clip tại thời điểm đó`.

Trục xoay trong Blender (3D Cursor ở gốc, dưới chân) trùng với trục xoay trong Godot (gốc `CharacterBody3D`), nên ghép lại ra đúng chuyển động gốc. Đã đo: hướng Spine so với trục nhân vật dao động **0.1–0.2°** suốt lúc xoay.

Mỗi clip xoay một góc **thật** khác số trên tên của nó. Góc này dùng ở 18.5:

| Clip | Góc Spine | Thời lượng (Godot) |
|---|---|---|
| `turn_left_90` | +76.6° | 1.333 s |
| `turn_left_180` | +185.5° | 1.900 s |
| `turn_right_90` | −84.7° | 1.500 s |
| `turn_right_180` | −179.7° | 1.900 s |

Dấu: **+ là xoay trái**, giống `rotation.y` và `angle_difference` trong code.

### 18.2 Blender: bake `TurnYaw` và tách xoay (thao tác tay, từ FBX gốc)
Làm cho từng clip, ví dụ `turn_right_180` từ file Mixamo `Rifle Turn.fbx`.

**1. File mới, import FBX.** File → New → General → **A**, **X** xoá cube / camera / light. File → Import → **FBX (.fbx)**, giữ mặc định.

**2. Bỏ prefix bone.** Chọn Armature → **Ctrl+F2** (Batch Rename) → Data type **Bones**, Find `swat:` (prefix Mixamo đặt theo tên nhân vật), Replace để trống → OK. Animation tự cập nhật theo tên mới.

**3. Khung clip và cursor.** Timeline: **Start 1**, **End** = frame cuối của clip (ví dụ 57). **Shift+C** đưa 3D Cursor về gốc.

**4. Empty `TurnYaw` ghi góc Spine.**
- **Shift+A → Empty → Plain Axes**, **F2** đặt tên object đúng là **`TurnYaw`** (Godot và code tìm theo tên này). Location 0, 0, 0.
- Tab **Object Constraint** → **Copy Rotation**: Target `Armature`, Bone `Spine`, Axis **chỉ Z** (Blender dùng Z là trục đứng), Order `XYZ Euler`, Mix `Replace`, World Space / World Space. Kéo timeline: trục Empty xoay theo ngực.
- Chỉ chọn `TurnYaw` → **Object → Animation → Bake Action…**: Start / End của clip, ☑ Only Selected, ☑ Visual Keying, ☑ Clear Constraints, ☐ Overwrite Current Action, Bake Data **Object** → OK.
- Đổi tên **action** (không phải tên object): Dope Sheet → **Action Editor**, chọn `TurnYaw` → ô tên action → **`turn_right_180_yaw`**.
- Kiểm tra: Graph Editor → **Z Euler Rotation** đi từ ≈0 tới góc của clip (bảng 18.1). Clip 180° vượt mốc ±180 vẫn liền mạch.
- ⚠ Nếu đường Z **nhảy thẳng đứng khoảng 180°** giữa chừng (gặp ở clip 180° khi ngồi, vì Spine cúi), Copy Rotation đã bị lật Euler. Với clip đó, dùng `turn_batch.py` (Bước 19.2).

**5. Empty `Unturn` (tạm) để xoay ngược.** **Shift+A → Empty → Plain Axes**, tên **`Unturn`**, Location 0, 0, 0. **Copy Rotation**: Target `TurnYaw`, Axis **chỉ Z**, hàng **Invert** tick **Z**, Order `XYZ Euler`, World / World.

**6. Gắn Hips vào `Unturn`.** Về **frame 1**. Chọn Armature → **Ctrl+Tab** (Pose Mode) → chọn bone **Hips** → tab **Bone Constraint** → **Child Of** → Target `Unturn` → bấm **Set Inverse**. Kéo timeline: chân vẫn bước, ngực nhìn một hướng.

**7. Bake Hips vào clip.**
- Pose Mode → **Alt+A** (bỏ chọn hết) → **Select → Select Pattern…** → Pattern `Hips`, ☐ Extend → OK. Hips phải sáng màu xanh. Tab Bone chỉ hiện bone **active**, không có nghĩa là bone đó đang được **chọn**.
- **Pose → Animation → Bake Action…**: Start / End của clip, ☑ Only Selected, ☑ Visual Keying, ☑ Clear Constraints, ☑ **Overwrite Current Action**, Bake Data **Pose** → OK.
- Kiểm tra: tab Bone Constraint của Hips **trống**. Kéo timeline: ngực vẫn đứng yên.

**8. Dọn và lưu.** Object Mode → xoá **`Unturn`**, **giữ `TurnYaw`**. Các Empty con của Armature (`HeadTop_End`, `LeftHandIndex4`…) là điểm cuối bone của Mixamo, để nguyên. **File → Save As** → `source/locomotion/turn/turn_right_180.blend`.

> **Tự động hoá bước 5–7:** `make_turn_in_place.py` làm đúng việc của `Unturn` + bake Hips (đo Spine, xoay ngược quanh 3D Cursor). Vẫn phải bake `TurnYaw` (bước 4) **trước** khi chạy script, vì sau đó Spine không còn xoay để copy.
> ```powershell
> & $blender -b --python tools\blender\make_turn_in_place.py -- <file.blend> ...
> ```

### 18.3 Godot: import
Nhấp đúp file `.blend` → **Advanced Import Settings**:
1. Cây trái → **Skeleton3D** → **Retarget → Bone Map** = `humanoid_bone_map.tres`.
2. **Animations** → animation của Armature (tên kiểu `Armature|mixamo_com|Layer0`) → ☑ Save to File, Path **`clips/turn/turn_right_180.res`**, Loop Mode **None**.
3. *(Dự phòng)* animation **`turn_right_180_yaw`** → ☑ Save to File, Path **`turn_curves/turn_right_180_yaw.res`** (Animation chứa track `TurnYaw`). Hiện code dùng `.tres` (18.4). File `.res` để dành cho hàm `_yaw_to_curve()`.
4. **Reimport**. Mỗi animation phải lưu vào **file riêng**. Trùng path thì animation sau đè animation trước.
5. Thêm `clips/turn/*.res` vào library `locomotion` (Manage Animations, 7.1).

Mẹo nhớ: animation tên **`_yaw`** → thư mục **`turn_curves`**. Animation của Armature (bước chân) → **`clips/turn`**.

### 18.4 Tạo curve `.tres`
Godot không có nút chuyển track animation thành `Curve`, nên dùng EditorScript `tools/godot/bake_turn_curves.gd`:
1. Mở file trong Script Editor → **File → Run** (**Ctrl+Shift+X**).
2. Script đọc track `TurnYaw` trong mọi file ở các thư mục của `SOURCE_DIRS` (`source/locomotion/turn/`, `source/crouch/turn/`), lấy góc quanh trục Y ở từng frame (30 fps), cộng dồn, tạo `Curve` (X = giây, Y = độ, `max_domain` = thời lượng clip) và lưu bằng `ResourceSaver` → `turn_curves/<tên>_yaw.tres`.
3. Output: `[Bake Turn] turn_right_180.blend  -179.7°  1.900 s  58 điểm → …_yaw.tres`. File chưa có `TurnYaw` thì báo lỗi đỏ và bỏ qua.

### 18.5 AnimationTree: `TurnInPlace`
1. Xoá state `TurnLeft` / `TurnRight` cũ.
2. Chuột phải → **Add BlendSpace1D** → tên đúng **`TurnInPlace`**.
3. Bên trong: **Min `-190`**, **Max `190`**, **Blend Mode `Discrete`** (chỉ phát đúng 1 clip, không trộn bước chân của 2 clip).
4. Điểm đặt **đúng góc cuối của curve** (bảng 18.1), vì code đặt `blend_position` bằng giá trị này:

   | Toạ độ | Clip |
   |---|---|
   | `185.5` | `turn_left_180` |
   | `76.6` | `turn_left_90` |
   | `-84.7` | `turn_right_90` |
   | `-179.7` | `turn_right_180` |
5. Mũi tên, Advance Mode **Enabled**: `Locomotion → TurnInPlace` Xfade **0.15**, `TurnInPlace → Locomotion` Xfade **0.2**.

### 18.6 Code (`humanoid_character.gd`)
```gdscript
@export var turn_curves: Array[Curve] = []   # 4 file *_yaw.tres

# Đứng yên, lệch quá max_twist_angle trong turn_delay → _start_turn(diff):
#   chọn curve CÙNG CHIỀU có góc cuối gần góc lệch nhất,
#   chốt _turn_start_yaw = rotation.y, đặt TurnInPlace/blend_position = góc cuối curve.
# Đang xoay:
_turn_time += delta
var spine_turned := _turn_curve.sample(minf(_turn_time, _turn_curve.max_domain))
rotation.y = wrapf(_turn_start_yaw + deg_to_rad(spine_turned), -PI, PI)
# Hết curve → về Locomotion. Còn lệch quá 60° thì lần sau chọn clip mới xoay tiếp.
# Đang đi (có vận tốc) → huỷ xoay tại chỗ.
```
- Thân chỉ xoay **đúng góc của clip** (ví dụ 76.6° chứ không phải 90°). Phần lệch còn lại do twist thân trên bù.
- `_yaw_to_curve()` (dự phòng) đọc file `_yaw.res` kiểu Animation và đổi sang Curve. Cách dùng ghi ngay trên hàm.

### 18.7 Gán curve và kiểm tra
1. Mở **`swat_character.tscn`** (scene gốc, không phải scene test) → SwatCharacter → Turning → **Turn Curves** → Size 4 → kéo 4 file `turn_curves/*_yaw.tres` vào → Ctrl+S. Thứ tự không quan trọng.
2. Clip bước chân có kèm track `TurnYaw` 1 key. Muốn hết cảnh báo `couldn't resolve track: 'TurnYaw'`: chuột phải **Model** → Add Child Node → **Node3D** tên **`TurnYaw`**.
3. F6 `test_player.tscn`:

| Thao tác | Kết quả mong đợi |
|---|---|
| Đứng yên, chuột lệch dưới 60° | Chỉ vặn thân trên |
| Lệch khoảng 60–130° | `TurnInPlace` phát clip 90, thân xoay theo nhịp bước chân (chậm → nhanh → dừng) |
| Lệch nhiều hơn | Phát clip 180 |
| Đang xoay thì bấm W | Huỷ xoay, đi bình thường |

### 18.8 Thêm góc mới (45°, 135°…)
Làm 18.2 → 18.4 cho clip mới, thêm clip vào library, thêm điểm vào `TurnInPlace` tại góc Output in ra, thêm curve vào Turn Curves. Code không cần sửa.

---

## Bước 19: Ngồi (Crouch): idle, đi 8 hướng, xoay 90/180

Bấm **C** để ngồi / đứng. Khi ngồi, nhân vật đi chậm 8 hướng và xoay tại chỗ bằng clip turn crouch, theo cách của Bước 18. Giữ **Shift** thì đứng dậy chạy luôn.

### 19.1 Clip
| Clip (library `crouch`) | File Mixamo | Ghi chú |
|---|---|---|
| `idle` | Crouching Idle | Hông cao 0.44 m |
| `walk_forward` … `walk_backward_right` (8 clip) | Walk Crouching Forward / Left / … | In Place bằng script, tốc độ đo được **1.96 m/s**, hông 0.68 m |
| `turn_left_90`, `turn_left_180`, `turn_right_90`, `turn_right_180` | Turn Left 90 Crouch … | Hông 0.77 m, Loop None |

Đặt tên file nguồn đúng tên clip: `crouch_walk_forward.blend`, `crouch_turn_left_90.blend`… Trong library, tiền tố `crouch_` được bỏ, nên clip có tên `crouch/walk_forward`.

### 19.2 Blender (bằng script)
```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 5.3\blender.exe"
# Walk: import + bỏ prefix + In Place + đưa về tâm (in ra tốc độ)
& $blender -b --python tools\blender\mixamo_batch_import.py -- <thư mục fbx walk> <thư mục tạm walk> --in-place
# Turn: import + bỏ prefix (không In Place)
& $blender -b --python tools\blender\mixamo_batch_import.py -- <thư mục fbx turn> <thư mục tạm turn>
# Turn: TurnYaw + tách xoay + xoá hông trôi, lưu thẳng vào source/crouch/turn
& $blender -b --python tools\blender\turn_batch.py -- assets\characters\animations\humanoid\source\crouch\turn <các file .blend trong thư mục tạm turn>
```
`turn_batch.py` làm đúng Bước 18.2, chỉ khác 2 chỗ:
1. **`TurnYaw` được key thẳng bằng góc Spine đo được** (trục ngang vai ↔ vai chiếu xuống sàn), không dùng Copy Rotation. Khi ngồi, Spine cúi về trước nên Copy Rotation "chỉ Z" bị lật Euler 180° ở clip 180°. Đo được: clip `turn_left_180` ra +5° thay vì +185°. Với clip 90°, 2 cách cho kết quả như nhau.
2. **Xoá dần phần hông trôi.** Clip turn crouch vừa xoay vừa bước lệch chỗ 24–42 cm. Nếu để nguyên, cuối clip người lệch khỏi capsule rồi giật về khi chuyển sang idle. Script trừ dần phần lệch theo thời gian để cuối clip hông về đúng chỗ đầu clip.

Kết quả: Spine còn xoay **0.00°**, hông còn trôi **0.0 cm**.

### 19.3 Godot: import, curve, library
1. Với mỗi file `.blend`, mở Advanced Import:
   - Skeleton3D → Bone Map = `humanoid_bone_map.tres`.
   - Animation của Armature → Save to File `clips/crouch/<idle|walk|turn>/<tên>.res`.
   - Loop Mode **Linear** cho idle/walk, **None** cho turn (như 18.3).
2. Chạy `tools/godot/bake_turn_curves.gd` (File → Run). Script tạo `turn_curves/crouch_turn_*_yaw.tres`:

   | Clip | Góc Spine | Thời lượng |
   |---|---|---|
   | `crouch_turn_left_90` | +90.4° | 1.267 s |
   | `crouch_turn_left_180` | +185.3° | 1.533 s |
   | `crouch_turn_right_90` | −83.8° | 1.500 s |
   | `crouch_turn_right_180` | −179.4° | 1.467 s |
3. Tạo AnimationLibrary **`crouch.tres`** chứa 13 clip. Mở `swat_model.tscn` → AnimationPlayer → Manage Animations → **Load Library** `crouch.tres` (tên gọi `crouch`).

### 19.4 AnimationTree
Thêm 2 state cạnh `Locomotion` / `TurnInPlace`:

| State | Loại | Thiết lập |
|---|---|---|
| **`Crouch`** | BlendSpace2D | Min/Max **±1.1**, **Sync ☑**. `idle` (0, 0). `walk_forward` (0, 1), `walk_backward` (0, −1), `walk_left` (−1, 0), `walk_right` (1, 0), 4 clip chéo **(±0.71, ±0.71)** |
| **`CrouchTurn`** | BlendSpace1D | Min −190, Max 190, **Discrete**. Điểm `185.3` → `turn_left_180`, `90.4` → `turn_left_90`, `-83.8` → `turn_right_90`, `-179.4` → `turn_right_180` |

Mũi tên đặt Advance Mode **Enabled** (code gọi `travel()`):
- `Locomotion ↔ Crouch`: Xfade **0.3**.
- `Crouch → CrouchTurn`: **0.15**.
- `CrouchTurn → Crouch`: **0.2**.

### 19.5 Code
```gdscript
# humanoid_character.gd
@export var crouch_speed := 1.95                      # = tốc độ clip crouch_walk
@export var crouch_turn_curves: Array[Curve] = []     # 4 file crouch_turn_*_yaw.tres
var is_crouching := false                             # controller bật/tắt

# _apply_movement: ngồi → crouch_speed, giữ Shift → run_speed, còn lại → walk_speed
# _start_turn: ngồi → chọn trong crouch_turn_curves, đặt CrouchTurn/blend_position,
#              chốt _turn_state = "CrouchTurn" (bấm C giữa chừng thì clip xoay vẫn chạy hết)
# _update_state_machine: đang xoay → _turn_state, ngồi → "Crouch", còn lại → "Locomotion"
# _update_animation: blend = vận tốc ÷ (crouch_speed nếu ngồi, walk_speed nếu đứng)
#                    Crouch/blend_position = blend.limit_length(1.0)  (Crouch không có vòng sprint)

# player_controller.gd
if Input.is_action_just_pressed("crouch"):
	character.is_crouching = not character.is_crouching
if character.is_running:
	character.is_crouching = false
```
Input Map: action **`crouch`** = phím **C** (Physical, All Devices).

Trong `swat_character.tscn` → Turning → **Crouch Turn Curves**, gán 4 file `crouch_turn_*_yaw.tres`. Dưới `Model` đã có Node3D `TurnYaw` để hết cảnh báo track (18.7).

### 19.6 Kiểm tra (F6 `test_player.tscn`)
| Thao tác | Kết quả mong đợi (đã test headless) |
|---|---|
| Bấm C | State `Crouch`, nhân vật hạ người |
| Đang ngồi, bấm W | Đi crouch 1.95 m/s, chân không trượt |
| Ngồi yên, chuột lệch khoảng 90° | `CrouchTurn` phát clip 90, thân xoay +90.4° / −83.8° |
| Ngồi yên, chuột lệch khoảng 180° | Phát clip 180, nhân vật không bị trôi khỏi chỗ |
| Giữ Shift khi đang ngồi | Đứng dậy chạy |
| Bấm C lần nữa | Về `Locomotion` |

### 19.7 Lưu ý: độ cao hông không khớp
3 nhóm clip có độ cao hông khác nhau: idle **0.44 m**, walk **0.68 m**, turn **0.77 m**. Vì vậy khi chuyển idle ↔ walk / turn, người sẽ nhô lên rồi hạ xuống.

Muốn mượt hơn:
1. Tải thêm từ Mixamo một clip **crouch idle cùng bộ với clip turn**. Đầu clip turn có hông cao 0.77 m, nên idle mới cũng nên cao khoảng đó.
2. Thay file `crouch_idle.blend`.
3. Làm lại 19.3, chỉ phần import.

---

## Bước 20: Nghiêng người (Q / E)

Giữ **Q** thì nghiêng về **bên trái màn hình**, giữ **E** thì nghiêng về **bên phải màn hình**, nhả phím thì về thẳng. Hướng nghiêng tính theo thế giới (theo camera, giống WASD), **không** theo trái/phải của nhân vật. Ví dụ nhân vật quay mặt sang phải màn hình mà bấm E, người sẽ ngả về phía trước.

Cách làm giống Bước 13: **`LeanModifier`** (`scripts/characters/lean_modifier.gd`) là một `SkeletonModifier3D`, cộng thêm góc nghiêng **sau** khi AnimationTree đã đặt tư thế. Nhờ vậy nó dùng được cho mọi state (đứng, ngồi, đi, xoay) mà không cần clip.

### 20.1 Cách hoạt động
- `lean` là một **Vector3 nằm ngang trong thế giới**: hướng của nó là phía đầu ngả về, độ dài là góc nghiêng (radian).
- Trục quay = `UP × hướng`. Quay quanh trục này một góc dương thì đỉnh đầu ngả đúng về hướng đó.
- **Cả nửa thân trên nghiêng như một khối từ eo**: toàn bộ góc dồn vào bone `Spine` (ngay trên hông). Ngực, tay, súng, đầu là con của Spine nên đi theo. Muốn lưng cong dần thì chia góc sang `Chest` / `UpperChest`.
- Modifier được gắn **sau `SpineTwistModifier`**, nên vặn theo chuột chạy trước, nghiêng chạy sau.
- **Không dịch Hips**: Hips là bone gốc, dịch nó sẽ kéo cả bàn chân trượt theo.

### 20.2 Input và code
- Input Map: `lean_left` = **Q**, `lean_right` = **E** (Physical, All Devices).
- `player_controller.gd` → `_get_lean_input()`: lấy `Input.get_axis("lean_left", "lean_right")`, xoay theo góc ngang của camera thành hướng thế giới.
- `humanoid_character.gd` → `_update_lean()`:
  - Hướng đích = `lean_input × max_lean_angle`.
  - Khi ngồi, nhân thêm `crouch_lean_scale`.
  - Khi sprint, hướng đích = 0.
  - `lean` tiến dần về hướng đích bằng `Vector3.lerp`. Đổi Q ↔ E thì người đi qua tư thế thẳng, không bật ngang.
- Debug label hiện thêm `lean` (độ lớn, đơn vị độ).

### 20.3 Thông số để chỉnh
| Ở đâu | Thông số | Mặc định | Ý nghĩa |
|---|---|---|---|
| SwatCharacter → Lean | `max_lean_angle` | 22° | Góc nghiêng tối đa |
| | `crouch_lean_scale` | 0.7 | Khi ngồi chỉ nghiêng bằng chừng này phần |
| | `lean_smoothing` | 10 | Lớn = nghiêng nhanh, nhỏ = nghiêng chậm |
| `lean_modifier.gd` | `bone_weights` | Spine 1.0, Chest 0, UpperChest 0 | Cách chia góc cho cột sống, tổng = 1. Dồn vào Spine = nghiêng thẳng từ eo |
| | `head_counter` | 0 | 0 = đầu nghiêng theo người, 1 = đầu thẳng hẳn |

Modifier được tạo bằng code nên không hiện trong Inspector. Muốn chỉnh `bone_weights` / `head_counter`, sửa giá trị mặc định trong file `.gd`.

### 20.4 Kiểm tra (F6 `test_player.tscn`)
Kết quả test headless: nhân vật quay mặt 0°, 90°, 180°, −90° rồi giữ E, lần nào đầu cũng ngả về phải màn hình khoảng 20 cm (lệch hướng 3–10° do nhịp thở của clip idle).

| Thao tác | Kết quả mong đợi |
|---|---|
| Giữ E / Q | Nửa thân trên ngả về phải / trái màn hình, nhả phím thì về thẳng |
| Xoay chuột trong lúc giữ E | Người vẫn ngả về phải màn hình |
| Giữ E khi đi / khi ngồi | Chân bước bình thường, thân trên nghiêng |
| Giữ Shift chạy | Người về thẳng |

⚠ Ở kiểu gõ **Telex**, phím **E** dùng để gõ dấu (`ee` → `ê`), nên bộ gõ có thể chặn phím E. Chuyển bộ gõ sang tiếng Anh khi chơi.

## Bước 21: Vũ khí – model, gắn vào tay, IK tay trái, ngón tay nắm súng

Kết quả cuối cùng của bước này:
- Súng SCAR-L nằm trong tay phải.
- Tay trái luôn bám vào ốp súng: ngón tay ôm quanh ốp, bàn tay khoá theo súng. Đúng ở mọi tư thế: đứng, đi, chạy, ngồi, nghiêng.
- Xem và chỉnh được ngay trong editor, không cần F6.

### 21.1 Chuẩn hoá model trong Blender
File gốc `SCAR L.fbx` (tải về) có 3 vấn đề cần sửa:

| | FBX gốc | Sau khi chuẩn hoá | Lý do |
|---|---|---|---|
| Kích thước | dài 10.36 đơn vị | **0.89 m** (scale ×0.086) | Bằng SCAR-L thật, khớp nhân vật |
| Hướng nòng | +X | **+Y** của Blender | glTF đổi +Y Blender → **−Z** Godot = phía trước |
| Gốc toạ độ | mỗi bộ phận một chỗ | **đỉnh báng cầm** (chỗ tay phải nắm) | Súng xoay quanh tay |

Cũng cần: xoá viên đạn `5.56x45` thừa, gộp 8 bộ phận còn 3, đổi tên material tiếng Nga.

**Thao tác:**
1. **File → New → General** → **A** rồi **X** để xoá Cube / Camera / Light.
2. **File → Import → FBX** → chọn `SCAR L.fbx` → **Import FBX**. Click `5.56x45` → **X** để xoá.
3. **Đưa gốc về báng cầm:**
   - **N** → tab **View** → **3D Cursor**: X `-1.7`, Y `0`, Z `1.45`. Nhìn từ trước (**Numpad 1**) để chỉnh cho cursor nằm giữa báng cầm.
   - **A** để chọn hết → **Object → Set Origin → Origin to 3D Cursor** → **Alt+G**.
4. **Xoay và scale** (vẫn đang chọn hết):
   - **Transform Pivot Point** → **3D Cursor** → **Shift+C** để đưa cursor về gốc.
   - Gõ **R Z 90** (nòng sang +Y) → **S 0.086** → **Ctrl+A → All Transforms**.
5. **Gộp bộ phận:**
   - Chọn `Fire Selector`, `IronSights`, `IronSights 2`, `Trigger`, cuối cùng **Ctrl+click** thân `SCAR L` để thân là active → **Ctrl+J**.
   - **F2** đổi tên: thân → `ScarL`, băng đạn → `Mag`, khoá nòng → `Bolt`.
   - Chọn `Mag`, `Bolt`, cuối cùng `ScarL` → **Ctrl+P → Object (Keep Transform)**.
   - `Mag` và `Bolt` để riêng: sau này animation nạp đạn cần rút băng đạn, còn khoá nòng có thể giật khi bắn.
6. **Thêm Empty** (**Shift+A → Empty → Plain Axes**, Rotation để 0, parent vào `ScarL`):
   - `Muzzle` = (0, 0.57, 0.095): tâm miệng nòng, điểm bắn đạn.
   - `LeftHandGrip` = (0, 0.32, 0.07): mặt dưới ốp tay, chỗ tay trái nắm.
   - Rotation 0 nghĩa là trục −Z của Empty trong Godot trùng hướng nòng.
7. **Material:** đổi tên thành `M_Scar_Metal1/2`, `M_Scar_BaseLight/Dark`, `M_Scar_Plastic`. Sau đó **File → Clean Up → Purge Unused Data**. Model chỉ có màu, không có texture.
8. **Ctrl+S** → `assets/weapons/source/scar_l.blend`, lưu ở Object Mode.

**Kiểm tra** (đã đo bằng script):
- `ScarL` dài 0.891 m; Location / Rotation = 0, Scale = 1.
- Cây object:
  ```
  ScarL
  ├── Bolt
  ├── LeftHandGrip
  ├── Mag
  └── Muzzle
  ```

### 21.2 Gắn súng vào tay phải
Cây node trong `swat_character.tscn`:
```
Model (Editable Children)
└── Skeleton_Reference/GeneralSkeleton
    ├── RightHandAttachment (BoneAttachment3D, Bone Name = RightHand)   ← bám xương cổ tay phải
    │   └── WeaponSocket (Node3D)                                        ← dời / xoay súng vào lòng bàn tay
    │       └── scar_l (scar_l.tscn, transform = 0)
    └── LeftHandIKModifier                                               ← IK tay trái + ngón tay (21.3–21.4)
```
- `BoneAttachment3D` copy vị trí xương **sau** khi mọi modifier (twist, lean, IK) chạy xong, nên súng đi theo thân trên.
- `WeaponSocket` tách riêng vì xương `RightHand` nằm ở **cổ tay**. Socket lo phần dời súng vào lòng bàn tay. Đổi súng chỉ cần thay node con, không phải chỉnh lại socket.

**Thao tác:**
1. **Tạo scene súng:** FileSystem → chuột phải `scar_l.blend` → **New Inherited Scene** → **Ctrl+S** → `scenes/weapons/scar_l.tscn`. Sau này script súng gắn vào root của scene này.
2. Mở `swat_character.tscn` → chuột phải `Model` → tick **Editable Children**.
3. Chuột phải `Model/Skeleton_Reference/GeneralSkeleton` → **Add Child Node** → `BoneAttachment3D` → đặt tên `RightHandAttachment` → Inspector **Bone Name** = `RightHand`.
4. Chuột phải `RightHandAttachment` → **Add Child Node** → `Node3D` → đặt tên `WeaponSocket`.
5. Kéo **`scenes/weapons/scar_l.tscn`** (không phải file `.blend`) thả lên `WeaponSocket`. Kiểm tra Position / Rotation của `scar_l` đều là 0.
6. Chỉnh vị trí súng trên tay: chọn **`WeaponSocket`** (không chỉnh `scar_l`) → dời / xoay bằng gizmo. Bấm **T** để xoay theo trục Local. Giá trị gợi ý ban đầu (tính từ tư thế idle): Position (0.026, 0.055, 0.005), Rotation (73.3, 121.2, 45.2).

⚠ **Lỗi hay gặp:**
- Kéo nhầm file `.blend` vào thay vì `.tscn`.
- Chỉnh lệch trên `scar_l` thay vì trên `WeaponSocket`.

Cả hai vẫn hiển thị đúng, nhưng sau này đổi súng hoặc gắn script súng sẽ bị sai.

### 21.3 IK tay trái và ngón tay nắm súng (`LeftHandIKModifier`)
Animation Mixamo tự cử động tay trái, nên tay trái không biết súng ở đâu. Khi đi, tay trái lệch ốp súng 10–17 cm.

`scripts/characters/left_hand_ik_modifier.gd` là một `SkeletonModifier3D` chạy **sau `LeanModifier`**. Mỗi frame nó làm 4 việc:
1. **IK 2 xương** (`LeftUpperArm` → `LeftLowerArm` → `LeftHand`) bằng định lý cos. Nó đổi góc vai và góc khuỷu sao cho vai cách cổ tay đúng bằng vai cách điểm đích, rồi xoay cả cánh tay sang hướng đích. Khuỷu gập trong mặt phẳng mà animation đang gập.
2. **Điểm đặt lên `LeftHandGrip` không phải cổ tay mà là điểm tiếp xúc.** Điểm này lấy trung bình khớp gốc của các ngón trong `contact_bones` (mặc định là gốc ngón trỏ), để ốp súng nằm ở khe giữa ngón cái và ngón trỏ như cầm súng thật. Xương ngón là con của `LeftHand`, khoảng cách tới cổ tay cố định, nên IK vẫn giải tới `LeftHand`.
3. **Khoá hướng bàn tay theo súng** (`hand_lock` = 1): lòng bàn tay ngửa lên ôm đáy ốp, ngón tay chĩa chéo về trước. Nếu giữ hướng của animation thì khi đi hoặc ngồi, ốp súng chéo 40–50° so với ngón tay và ngón co lại sẽ không ôm trúng.
4. **Co ngón:** mỗi đốt bằng tư thế gốc (rest pose) xoay thêm `finger_curl_*` quanh trục +X. Trục này được đo trên skeleton: gập quanh +X thì đầu ngón cong về +Z, phía lòng bàn tay. Ngón cái xoay quanh X (vắt ngang lòng bàn tay) và Z (gập lên phía súng).

**Đích được tính từ xương tay phải ngay trong frame này**, không đọc `LeftHandGrip.global_position`. Lý do: BoneAttachment3D chỉ cập nhật sau khi các modifier chạy xong, nên vị trí đọc được là của frame trước, và tay trái sẽ trễ 1 frame, rung khi đi. Cách làm:
- Lúc gán `target`, modifier nhân dồn transform cục bộ từ `LeftHandGrip` lên tới `RightHandAttachment`. Giá trị này cố định.
- Mỗi frame lấy `pose(RightHand) × giá trị đó`.

**Thao tác:**
1. Mở `swat_character.tscn` → click root `SwatCharacter` → Inspector nhóm **Weapon** → **Weapon Socket** → **Assign** → chọn `WeaponSocket` → **Ctrl+S**.
2. Chuột phải `GeneralSkeleton` → **Add Child Node** → gõ `LeftHandIK` → chọn **LeftHandIKModifier** → **Create** → **Ctrl+S**.
   - Không thấy trong danh sách thì: **Project → Reload Current Project**.
   - Không thêm node này thì game vẫn chạy (code tự tạo), nhưng không xem được trong editor.
3. Ngay lập tức tay trái dính vào ốp súng và ngón tay co lại ở khung 3D. Chỉnh trong Inspector theo bảng dưới.
4. Giá trị chỉnh trong Inspector được lưu vào `swat_character.tscn` khi **Ctrl+S**, không cần sửa file `.gd`.

**Thông số:**

| Ở đâu | Thông số | Mặc định | Ý nghĩa |
|---|---|---|---|
| SwatCharacter → Weapon | `weapon_socket` | `WeaponSocket` | Nhân vật tìm `LeftHandGrip` bên trong để làm đích IK (lúc chạy game; sau này đổi súng) |
| | `left_hand_ik` | bật | Tắt để so sánh với tay trái của animation gốc |
| LeftHandIKModifier | `contact_bones` | [`LeftIndexProximal`] | Điểm tiếp xúc = trung bình khớp gốc các ngón trong danh sách. Thêm cả 4 ngón (Index, Middle, Ring, Little + `Proximal`) → súng nằm giữa hàng khớp, dịch 3.4 cm về phía ngón út |
| | `contact_amount` | 0.85 (scene đang dùng 0.95) | 0 = cổ tay, 0.55 ≈ giữa lòng bàn tay, 1 = đúng khớp ngón. Tăng = súng dịch lên phía ngón tay |
| | `palm_depth` | 0.015 m | Độ dày nửa bàn tay theo +Z (quay vào súng). Tay lún vào ốp thì tăng, hở khỏi ốp thì giảm |
| → Hand Rotation | `hand_lock` | 1 | 0 = bàn tay xoay theo animation, 1 = khoá theo súng |
| | `hand_rotation` | (0, 30, 0)° | Xoay bàn tay theo trục súng. **Y**: ngón chĩa về trước / sau. **Z**: lăn quanh nòng (lòng bàn tay nghiêng). **X**: gập cổ tay |
| → Fingers | `finger_grip` | 1 | 0 = ngón theo animation, 1 = ngón nắm theo các góc dưới |
| | `finger_curl_base / mid / tip` | 15 / 70 / 45° | Góc gập từng đốt của 4 ngón: gốc (Proximal) / giữa (Intermediate) / đầu (Distal) |
| | `thumb_across / thumb_bend` | 0 / 0° | Ngón cái: vắt ngang lòng bàn tay / gập lên phía súng |

**Thấy gì thì chỉnh gì:**

| Thấy gì | Chỉnh |
|---|---|
| Ốp súng nằm quá sâu / quá nông trong tay | `contact_amount` (tăng = súng dịch về phía ngón) |
| Tay lún vào ốp / hở khỏi ốp | `palm_depth` |
| Cổ tay gập gãy | `hand_rotation` Y tăng lên 40–45 (khi đi / ngồi đẹp hơn, nhưng đứng yên bị bẻ nhiều hơn) |
| Lòng bàn tay nghiêng, không ôm đáy ốp | `hand_rotation` Z ±10–20 |
| Ngón lơ lửng / chui vào ốp | Tăng / giảm `finger_curl_mid`, `finger_curl_tip` |
| Gốc ngón nhô ra khỏi ốp | Tăng `finger_curl_base` |
| Ngón cái chưa ôm thành trái | Tăng `thumb_bend`, hoặc chỉnh `thumb_across` ±20 |
| Muốn tay đặt ở chỗ khác trên súng | Dời Empty `LeftHandGrip` trong Blender, hoặc dời `WeaponSocket` |

**Kết quả test headless:**

Sai số lớn nhất giữa điểm tiếp xúc và `LeftHandGrip`:

| | idle | đi | sprint | ngồi | ngồi đi | nghiêng E |
|---|---|---|---|---|---|---|
| IK tắt | 9.7 cm | 16.6 cm | 17.4 cm | 15.1 cm | 16.5 cm | 9.7 cm |
| IK bật | 0.0 cm | 0.0 cm | 0.0 cm | 0.0 cm | 0.0 cm | 0.0 cm |

Cổ tay bẻ nhiều nhất theo `hand_rotation` Y (vì thế chọn 30):

| Y | idle | đi | ngồi | ngồi đi |
|---|---|---|---|---|
| 20° | 17° | 31° | 49° | 33° |
| **30°** | **24°** | **20°** | **34°** | **23°** |
| 45° | 41° | 10° | 16° | 11° |
| 60° | 58° | 20° | 13° | 19° |

Vị trí đầu ngón so với `LeftHandGrip`. Mặt cắt ốp rộng ±2.4 cm, hai thành bên cao 1–5 cm:
- Ngón trỏ: (+2.7, 5.1) cm, tỳ thành phải.
- Ngón út: (+3.8, 4.0) cm, tỳ thành phải.
- Ngón cái: (−2.8, 4.1) cm, tỳ thành trái.
- Đầu ngón trôi so với súng: 0 cm ở mọi tư thế.

### 21.4 Xem IK ngay trong editor
`LeftHandIKModifier` là script `@tool`, nên chạy được cả trong editor:
- `target` để trống: modifier tự tìm node `LeftHandGrip` dưới skeleton.
- Trong editor, đích được tính lại mỗi frame. Dời `WeaponSocket` hay kéo thanh trượt trong Inspector là thấy ngay.
- Lúc chạy game, `humanoid_character.gd` tìm lại node này và dời nó xuống **cuối** danh sách con, để nó chạy sau Twist và Lean (hai modifier này được thêm bằng code). Nếu scene không có node này thì code tự tạo.
- Twist và Lean **không** chạy trong editor, chỉ IK chạy.

**Xem từng tư thế:**
- **Cách A, tua từng frame (rõ nhất):** chọn `AnimationTree` → bỏ tick **Active** → chọn `Model/AnimationPlayer` → panel **Animation** → chọn clip (ví dụ `crouch/walk_forward`) → kéo timeline. Xem xong thì tick lại **Active**. Có quên thì cũng không sao, vì `_ready()` luôn bật lại `anim_tree.active = true`.
- **Cách B, giữ AnimationTree bật:** chọn `AnimationTree` → panel **AnimationTree** → bấm ▶ trên state (Locomotion, Crouch…). Bấm ✏ để mở BlendSpace → chọn công cụ **Set the blending position…** → click để đổi hướng đi.
- **Phóng to tay:** chọn node trong cây Scene → **F** để camera nhảy tới.

⚠ Trong Godot 4.5, `Skeleton3D.get_bone_global_pose()` gọi **ngoài** modifier trả về tư thế **trước** modifier. Muốn đo tư thế cuối cùng (sau twist / lean / IK) thì đọc qua một `BoneAttachment3D`.

### 21.5 Hướng nâng cấp
| Cách | Làm gì | Khi nào |
|---|---|---|
| Súng theo thân, IK 2 tay | Súng gắn vào ngực, luôn chĩa đúng hướng ngắm; cả 2 tay IK vào `RightHandGrip` / `LeftHandGrip` | **Nên làm tiếp**, trước bước bắn hitscan: hiện nòng chĩa theo tay phải của animation (lúc idle chúc xuống chéo trái) |
| Animation thân trên riêng | Clip Mixamo rifle aiming, trộn cho Spine trở lên bằng filter trong AnimationTree | Để vai / khuỷu ra dáng cầm súng, IK chỉ phải sửa ít |
| Hand pose làm sẵn | 1 frame tư thế nắm dựng trong Blender, áp lên xương ngón thay cho các góc `finger_curl_*` | Khi cần tay đẹp hơn, hoặc nhiều loại súng |
| Ngón tự ôm theo collision | Raycast từng đốt ngón | Không khuyên: camera top-down nhìn không ra khác biệt |

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
| Script Blender báo góc/độ trôi bằng 0 dù animation có chuyển động | File `.blend` được lưu lúc armature ở **Edit Mode**, Blender không tính tư thế | Script đã tự chuyển Object Mode. Lần sau Tab về Object Mode trước khi Ctrl+S |
| Animation turn làm nhân vật xoay gấp đôi | Clip còn phần xoay hông | Chạy `make_turn_in_place.py` (6.4b) |
| Cảnh báo `ext_resource, invalid UID … using text path instead` | Clip được tạo lại với UID mới, library còn UID cũ | Bấm 💾 ở Manage Animations, hoặc Project → Tools → Upgrade Project Files (7.1) |
| Có file `*.tscn12345678.tmp` cạnh scene | Godot lưu dở | Xoá file `.tmp` |
| Khi chạy, model tách khỏi capsule va chạm khoảng 1–2 m | Clip bị **lệch sẵn khỏi gốc toạ độ** dù không trôi (gặp ở clip sprint thẳng) | Chạy `make_in_place.py` để đưa hông về tâm (6.4) |
| Script batch báo độ trôi 0 m nên không biết tốc độ clip | Tải từ Mixamo với In Place ☑ | Tải lại với In Place ☐, hoặc đo bằng bàn chân (6.4a) |
| Sau khi đổi tên library/clip, nhân vật đứng im | Tên gọi library trong AnimationPlayer hoặc các node AnimationTree còn tên cũ | Sửa đủ 4 chỗ (7.2b) |
| Đổi tên clip xong, clone sang máy khác lại xuất hiện clip tên cũ | `save_to_file/fallback_path` trong file `.import` vẫn là tên cũ | Mở Advanced Import của file nguồn, chọn lại Save to File path, Reimport |

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
| Đi chéo hết tốc độ nhưng không phát đúng clip chéo | Điểm chéo trong BlendSpace đặt ở (±0.5, ±0.5) | Đặt ở **(±0.71, ±0.71)** (8.6) |
| Giật khi chuyển từ đứng yên sang đi | Nhiều điểm idle trùng ở (0, 0) trong BlendSpace | Chỉ giữ 1 điểm idle (8.6) |

### Điều khiển người chơi
| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| `Class "HumanoidCharacter" hides a global script class` tại `swat_character.tscn::GDScript_…` | `SwatCharacter` đang dùng **script nhúng (built-in)** trùng `class_name` với file `.gd`. Nhân vật thành CharacterBody3D trống, không di chuyển | Trong editor: đóng tab script nhúng (Don't Save) → Detach Script → kéo `humanoid_character.gd` vào → kiểm tra Inspector → Ctrl+S |
| Đã sửa file `.tscn` bên ngoài nhưng lỗi script nhúng quay lại | Scene đang mở trong editor vẫn giữ bản cũ trong bộ nhớ, Ctrl+S ghi đè | Sửa **trong editor**, hoặc Reload Current Project và chọn Don't Save |
| Nhân vật không xoay theo chuột | Controller chưa gán export `character` / `camera`, hoặc còn dùng tên cũ `look_direction` | Gán export (11.4). Tìm `look_direction` bằng Ctrl+Shift+F, đổi thành `aim_direction` |
| Camera quay vòng theo nhân vật | Camera là con của `SwatCharacter` | Camera nằm trong `CameraRig` riêng (11.1) |
| Nhân vật giật qua lại khi chuột ở sát chân | Hướng ngắm thay đổi quá mạnh khi chuột rất gần | `aim_dead_zone` khoảng 0.3 m (11.3) |
| Chân giật qua lại khi chuột rung quanh mốc 60° | Chỉ dùng một ngưỡng | Hai ngưỡng bắt đầu / dừng khác nhau (hysteresis, Bước 12) |
| Lia chuột nhanh cũng làm chân bước xoay | Không có độ trễ | `turn_delay` khoảng 0.1 s (14.1) |
| State machine tự nhảy sang TurnLeft dù nhân vật không xoay | Mũi tên `Locomotion → TurnLeft` đặt Advance Mode = Auto | Đặt **Enabled**, để code gọi `travel()` (15.2) |
| Bàn chân trượt khi xoay tại chỗ | Timeline Length không khớp `idle_turn_speed` | `Timeline Length = góc clip ÷ idle_turn_speed` (15.4) |
| Đo tư thế bằng code không thấy phần xoay thân trên | Đọc tư thế ngoài thời điểm modifier chạy | Đọc trong tín hiệu `skeleton_updated` (13.4) |
| Giữ Shift chạy nhanh nhưng phát animation đi bộ, chân trượt | Blend vẫn `limit_length(1.0)`, chấm không ra tới vòng sprint | `limit_length(run_speed / walk_speed)` (16.5) |
| Không thêm được điểm sprint ở (0, 3.2) | Khung BlendSpace mặc định ±1 | Min/Max Space ±3.5 (16.4) |
| Chạy nhanh bị chân trượt | Bán kính vòng sprint không khớp `run_speed` | `R = run_speed ÷ walk_speed` (16.6) |
| Clip sprint khựng sau một nhịp | Loop Mode = None | Advanced Import → Loop Mode Linear |
| Khi sprint, nhân vật nhoè, rung, như có bóng mờ | Màn hình tần số cao (144 Hz) trong khi nhân vật di chuyển 60 lần/giây | Bật Physics Interpolation, camera dùng `get_global_transform_interpolated()` (Bước 17) |
| `follow_speed` trong Inspector chỉ nhập được số nguyên | Khai báo `:= 10` nên kiểu là `int` | Viết `:= 10.0` |

### Xoay tại chỗ theo Spine (Bước 18)
| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| Đứng yên chỉ vặn thân trên, chân không bao giờ xoay | Turn Curves chưa gán, hoặc gán ở scene test thay vì `swat_character.tscn` | Gán ở scene gốc (18.7). Output có cảnh báo `chưa gán Turn Curves` |
| Bake Action Hips xong vẫn còn Child Of, clip không đổi | ☑ Only Selected nhưng **không có bone nào được chọn** | Alt+A → Select → Select Pattern `Hips` → bake lại (18.2 bước 7) |
| Godot báo không có track `TurnYaw` | Đặt tên **object** là `turn_..._yaw`, hoặc chưa bake Empty | Object tên `TurnYaw`, **action** tên `turn_..._yaw` (18.2 bước 4) |
| Empty `TurnYaw` copy được góc 0 | Bake Empty sau khi đã tách xoay (Spine không còn xoay) | Bake `TurnYaw` **trước** bước 5–7. Lấy lại FBX gốc |
| Khi xoay nhân vật đứng cứng | `clips/turn/*.res` đang chứa animation `_yaw` (đặt ngược path, hoặc 2 animation cùng 1 path) | Animation Armature → `clips/turn/`, animation `_yaw` → `turn_curves/`, mỗi cái 1 file (18.3) |
| `couldn't resolve track: 'TurnYaw'` | Clip bước chân kèm track `TurnYaw`, nhân vật không có node đó | Vô hại. Thêm Node3D `TurnYaw` dưới `Model` để hết (18.7) |
| Xoay xong lệch hướng hoặc phát sai clip | Toạ độ điểm `TurnInPlace` khác góc cuối của curve | Đặt đúng bảng 18.1 |
| Chân vẫn bị kéo về chỗ cũ sau khi xoay | Clip `.res` chưa import lại, hoặc còn dùng cách cũ (xoay quanh Hips) | Reimport file nguồn. Làm theo 18.2 |
| Clip 180° bị lật hông ở cuối | Góc đo bằng wrap cả góc (nhảy dấu ở ±180°) | Cộng dồn từng frame (script / EditorScript hiện tại đã làm) |

### Ngồi (Bước 19)
| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| Bấm C không có gì xảy ra | Input Map chưa có action `crouch`, hoặc bộ gõ tiếng Việt chặn phím | Thêm action (19.5). Tắt bộ gõ |
| Ngồi yên, chuột lệch nhiều nhưng chỉ vặn thân trên | Chưa gán Crouch Turn Curves | Gán trong `swat_character.tscn` (19.5). Output có cảnh báo `chưa gán Crouch Turn Curves` |
| Curve `crouch_turn_*_180` ra góc khoảng 0° hoặc nhảy 180° | `TurnYaw` bake bằng Copy Rotation chỉ Z, bị lật Euler vì Spine cúi | Dùng `turn_batch.py` (19.2) |
| Xoay xong, người giật về chỗ cũ | Clip turn crouch còn phần hông trôi | `turn_batch.py` đã xoá phần này. Reimport clip |
| Đi khi ngồi bị trượt chân | `crouch_speed` khác tốc độ clip | Đặt 1.95 m/s (đo được 1.96) |
| Chuyển idle ↔ đi thấy người nhô lên | Clip idle và walk khác độ cao hông | Xem 19.7 |

---

## Lộ trình

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| 0 | Chuẩn bị asset: skeleton, SWAT, material, BoneMap | ✅ |
| 1 | Pipeline animation: idle, walk 8 hướng, sprint 8 hướng, turn trái/phải, In Place + đưa về tâm, 1 BoneMap, library `locomotion`, script Blender (batch import) | ✅ |
| 2 | Scene nhân vật: `swat_character.tscn`, AnimationTree (BlendSpace2D), `humanoid_character.gd`, scene test | ✅ |
| 3 | Điều khiển người chơi: ngắm theo chuột, camera đi theo, WASD theo camera, xoay thân trên (`SpineTwistModifier`), xoay tại chỗ theo Spine (Turn 90/180, BlendSpace1D `TurnInPlace`, curve góc Spine), sprint 8 hướng (Shift), camera mượt (Physics Interpolation), ngồi (C: idle, đi 8 hướng, xoay 90/180, library `crouch`), nghiêng người (Q / E, `LeanModifier`) | ✅ |
| 4 | Vũ khí: model SCAR-L chuẩn hoá ✅, gắn vào tay (`BoneAttachment3D`) ✅, IK tay trái + ngón tay nắm súng (`LeftHandIKModifier`, xem trước trong editor) ✅, súng theo thân + IK 2 tay, `WeaponData`, bắn hitscan, nạp đạn, hiệu ứng | 🔄 Đang làm |
| 5 | Chiến đấu: máu, hitbox/hurtbox, animation thân trên (bắn, nạp đạn, trúng đạn, chết) | ⬜ |
| 6 | Kẻ địch: Navigation, AI (dùng lại `HumanoidCharacter`, chỉ thay controller) | ⬜ |
| 7 | Vòng lặp game: wave, HUD, menu | ⬜ |
| 8 | Hoàn thiện: camera nhìn trước (look-ahead), foot IK, SFX, VFX, tối ưu | ⬜ |
