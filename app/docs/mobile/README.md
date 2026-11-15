# Kallo 手机端重设计

> 状态：**已按此方案实现手机紧凑壳**（见 `app/lib/design/mobile.dart`、`views/mobile/`、`widgets/mobile/`）；桌面工作室未改，桌面 goldens 全部通过。
>
> 视觉稿： [工作流](board-1.png) · [印相与两个房间](board-2.png) · [空状态与设置](board-3.png) · [可交互 HTML](mockups.html)
>
> 现在的手机端：[current-select.png](current-select.png)

---

## 0. 一句话方向

**不要把桌面工作室缩小，要把暗房放进口袋。**

桌面的组织是「两个房间 + 一个晾片架 + 右侧仪表盘」；手机不该把这套家具按比例压进 390 pt，而应该变成：

> 一个主体（照片或相纸）+ 一块仪表盘（当前这一步的 2–3 个控制）+ 一条步骤（选片 / 显影 / 印相）。

房间仍然只有三个，步骤仍然只有三个；变化的是它们不再同时出现。**屏幕一次只回答一个问题。**

---

## 1. 为什么现在的手机端不对

现在的紧凑分支不是一套手机布局，而是桌面布局的减法：

- `Studio` 在宽度 `< 700` 时保留 56 pt 顶部 chrome、52 pt 底栏，把侧边栏拿掉（`app/lib/views/studio.dart:109`、`:190`、`:330`）。
- `SelectStage` 把桌面工作区与 inspector 改成上下两块：上面照片，下面 `_materials(stacked: true)`，面板占屏高 46%（`app/lib/views/select_stage.dart:105–119`）。
- `DevelopStage` / `PrintStage` 同样把 inspector 压进 46% / 50% 的底部面板（`app/lib/views/develop_stage.dart:553–561`、`app/lib/views/print_stage.dart:379–389`）。
- 于是手机上同时存在：状态栏、56 pt 顶栏、内容区、第二层可滚动面板、底部 52 pt 导航。**内容很少超过屏幕的一半。**

| 问题 | 具体表现 | 后果 |
|---|---|---|
| 两层导航 | 顶部步骤胶囊 + 底部「暗房 / 晾片架 / 观景台 / 设置」 | 同一件事被说两遍；顶栏 56 pt 只为放一个胶囊 |
| 面板是桌面 inspector | 46% / 50% 固定高度，内部再滚动 | 照片小，控制藏在第二层滚动里；首屏看不到「去显影」 |
| 触摸目标太小 | 按钮 30–36 pt，步进器 ± 28 pt，chip 约 24 pt，开关 30 pt | 低于 iOS 44 pt；单手容易点错 |
| 字号是桌面字号 | body 13、small 11.5、caption 10.5；底栏 10.5 | 手机上看起来像缩放过的桌面 |
| 选择材料是「货架」 | 24 支胶片 + 相纸全部平铺成 chips，塞进 46% 的滚动区 | 找一支胶片要滚很久；选中态只是一块橙色 chip |
| 手机横向会掉回桌面 | 断点只看宽度 `< 700`；iPhone 横向 844 pt | 出现 232 pt 侧栏 + 304 pt inspector，内容只剩约 300 pt |
| 晾片架/观景台是桌面几何 | 观景台 40 pt 边距、每行一张巨大 35 mm 框；晾片架一行最多一张 | 一屏一张，翻十张要滑十屏 |
| 只有 hover 的放大镜 | `Gallery._lookAt` 在 hover 时出玻璃；触摸没有 hover | 手机上的 Loupe 开关没有实际作用 |
| 设置是压在工作台上的抽屉 | 紧凑分支仍是「横向 tab 轨 + 页面」 | 不是 iOS 的设置页，且遮住正在做的事 |
| 改材料会静默清空试片 | `_chooseFilm` / `_choosePaper` / `_setTemperature` 直接替换 strip | 有试片时换胶片/相纸/温度，试片消失且没有确认 |

这些问题不是换几个颜色能解决的。它们来自同一个前提：**桌面的空间关系被当成了产品结构**。手机需要自己的结构。

---

## 2. 设计原则

1. **一个主体。** 选片页的主体是原片；显影页是正在显影的试片；印相页是成品；晾片架是纸；观景台是胶片。主体占屏幕的主要面积，控制让路。
2. **最多两层导航。** 房间 = 底部 tab；步骤 = 顶部分段控件；任务 = sheet。不要再出现「房间胶囊 + 底栏房间」这种重复。
3. **主要动作永远在拇指下。** 每个工作页只有一个 filled CTA，固定在底部安全区上方；不藏在面板滚动里。
4. **控制 ≥ 44 pt，正文 ≥ 15 pt。** 这是手机，不是 27 寸显示器。桌面字号不进入紧凑壳。
5. **渐进披露。** 时间、曝光、滤镜、曲线不在同一屏堆满。曲线、材料参数、纸张数据放进 Details sheet；主屏只留在场的控制。
6. **Apple 的语义，Kallo 的材质。** 用 iOS 的导航栏、tab bar、segmented control、sheet、grouped list、44 pt 行、动态字体；但颜色仍是 safelight 橙、相纸暖白、胶片黑，字体仍是 Inter，绝无 Material。
7. **空状态是一扇门。** 每个空房间都告诉人这是什么、下一步去哪，并给一个动作；空不是错误。
8. **破坏性操作要说出来。** 换胶片/相纸/温度/照片会另起一条试片；有试片时先确认，并写清会丢掉几张。
9. **桌面不受影响。** 所有手机代码走独立的紧凑壳；桌面 goldens 不变。

---

## 3. 信息架构

```text
Kallo
├─ Darkroom（底部 tab）
│  ├─ Select        ← 原片 + 材料
│  ├─ Develop       ← 试片 + 时间 + 试片条
│  └─ Print         ← 成品 + 时间/曝光/平衡/玻璃
├─ Drying rack（底部 tab）
│  └─ Print viewer（全屏，无 tab）
├─ Gallery（底部 tab）
│  └─ Frame viewer（全屏，无 tab）
└─ Settings（齿轮，模态整页）
   ├─ Appearance
   ├─ Language
   ├─ Library
   ├─ Colour
   └─ About
```

- **三个房间，不是四个。** 设置不是房间，是齿轮打开的整页；底栏只放三个地方。中文标签用「暗房 / 晾片 / 观景」，不放「晾片架 / 观景台」四个字。
- **三个步骤，不是三个页面栈。** 分段控件切换步骤；状态留在原处。从观景台回到暗房，仍在刚才那一步。
- **任务用 sheet。** 选胶片、选相纸、温度、Details、印相选项、导出、确认，都是 sheet；不把桌面 inspector 塞回主屏。
- **查看是全屏。** 晾片架和观景台点开一张，进入无 tab 的全屏 viewer；返回后保留滚动位置。
- **返回层级（Android 返回键 / iOS 边缘滑动）：** 先关 sheet → 再退一步（Print → Develop → Select）→ 最后退出暗房；viewer/settings 先关自己，不退出 app。

---

## 4. 布局系统

### 4.1 断点

| 壳 | 条件 | 布局 |
|---|---|---|
| **compact（手机）** | `shortestSide < 600`，或移动平台且 `shortestSide < 700` | 本方案；单列，底部 tab |
| **medium（平板/窄窗口）** | `700 ≤ shortestSide < 1100` | 单列，内容最大宽度 600，底部 tab；不恢复侧栏 |
| **expanded（桌面）** | `shortestSide ≥ 1100` | 现有桌面工作室，完全不动 |

这样 iPhone 横向（844 × 390，shortestSide 390）仍然被判定为手机壳；v1 另外把手机锁在竖屏（见 4.3），等到横屏工作台落地再解除。iPad 竖屏（768）进入手机/medium 壳，不会出现 232 + 304 两个侧栏挤掉内容；桌面 1280 仍是现在的样子。

> 现有 `width < 700` 的断点在 iPhone 横向会直接掉回桌面。这是必须在第一阶段修掉的。

### 4.2 纵向骨架（390 × 844）

```text
┌──────────────────────────────┐
│ status 47                    │  safe top
├──────────────────────────────┤
│ nav 52  KALLO │ Select/… │ ⚙ │  compact navigation
├──────────────────────────────┤
│                              │
│                              │
│         stage (flex)         │  主体：照片 / 相纸 / 墙
│                              │
│                              │
├──────────────────────────────┤
│ instrument deck 192–236      │  当前步骤的控制
├──────────────────────────────┤
│ tab bar 49 + safe 34         │  三个房间
└──────────────────────────────┘
```

- **nav 52**：34 pt 高的三等分 segmented control 居中；左侧 KALLO 字标 9.5 pt；右侧齿轮 44 × 44。没有房间名胶囊。
- **tab bar 49 + 34 safe**：图标 24、标签 10.5；选中 safelight 橙，未选中 `inkFaint`；顶部 0.5 pt hairline，没有阴影。三个 tab 均分。
- **deck 192–236**：不是桌面 inspector。显影 236（试片条 + 时间尺），印相 192（2×2 控制）。只放当前步骤必须的控制；CTA 固定在 deck 底部。
- **stage**：`Expanded`，不是 46%。照片按 `BoxFit.contain`；相纸按纸张比例；永远不裁掉照片本身。
- **边距 16**：内容、卡片、CTA 都是 16；section 间距 24；卡片内 14–16。

### 4.3 横向（手机横屏，第二期）

**当前实现选择先锁竖屏**：390 pt 高的横屏窗口放不下竖向的 stage + deck，而把手机掉回桌面双栏更糟。`main()` 在 iOS/Android 上设置
`SystemChrome.setPreferredOrientations([portraitUp, portraitDown])`；桌面不受影响。横屏工作台是下一阶段，结构已经写在这里：

```text
[nav 44]
[ stage 55% ][ deck 45% ]   ← 左图右控制
[ tab bar 49 + safe ]       ← 保留，图标 + 标签
```

deck 在右侧成为一列，测试片条水平滚动；如果高度不足，deck 内部滚动，但 CTA 始终固定在右下。等到它落地，再解除竖屏锁。

### 4.4 尺寸与安全区

- 以 390 × 844（iPhone 12/13/14）为基准；验证 375 × 667（SE）、393 × 852、430 × 932。
- 顶部用系统 safe area；底部 tab bar 自己吃掉 home indicator 的 34 pt，内容不再额外垫。
- 键盘弹出时：sheet 上移；主屏不被键盘挤压（所有输入都在 sheet 里）。
- 状态栏图标亮度跟随当前 stage：暗房显影/印相和 viewer 用 light，亮色页面用 dark；Android edge-to-edge，关闭对比度强制。

---

## 5. 视觉语言

### 5.1 颜色

沿用 `KalloColors` 的两套值；手机只增加「bar / stage / paper」三个使用角色，不新增品牌色。

| 角色 | Light | Dark | 用途 |
|---|---|---|---|
| `ground` | `#F2F2F7` | `#000000` | 页面/分组背景 |
| `stage` | 照片垫 `#0B0A09` | 同左 | 原片、显影台的黑卡纸 |
| `card` | `#FFFFFF` | `#1C1C1E` | 材料卡、deck、sheet、settings 组 |
| `fill` | `#ECECF0` | `#2C2C2E` | 控件底、搜索框、segmented 轨 |
| `hairline` | `#D6D6DB` | `#38383A` | 0.5 pt 分隔线 |
| `ink` | `#1D1D1F` | `#F5F5F7` | 主文字 |
| `inkMuted` | `#6E6E73` | `#AEAEB2` | 次要文字（正文最小用它） |
| `inkFaint` | `#8E8E93` | `#8E8E93` | 仅装饰/非关键；白底对比 3.26:1，不用于必读 |
| `accent` | `#C2410C` | `#FF9F0A` | 唯一强调：主按钮、选中、时间指针 |
| `accentSoft` | `#FBE9DE` | `#3A2A12` | 选中行/选中 chip 的底 |
| `paper` | `#FFFCF7` | `#F7F2E9` | 相纸，永远是暖白 |
| `film` | `#0B0A09` | 同左 | 胶片 rebate |

- **bar**：`card` 86% + `BackdropFilter(blur 18, saturate 160%)`，底部 0.5 pt hairline。不投阴影。
- **stage**：原片放黑卡纸；显影/印相放相纸，相纸有物体阴影；页面本身是中性 ground。照片和纸是房间里的物体，可以投影；面板和导航是平面，不投影。
- **accent 只做三件事**：主 CTA、选中态、时间指针。底栏选中也是它。不要用橙色画边框、标题、图标背景。
- **暗色不是纯黑一片**：nav/tab 用 86% 黑玻璃，deck 用 `#1C1C1E`；相纸在暗处仍是暖白。

### 5.2 字体

仍用 **Inter**（已随包，goldens 用它），不引入 SF Pro，也不引入新字体。手机使用一套独立的、封闭的 compact 字号；桌面 `KalloType` 不动。

| 角色 | 字号/行高 | 字重 | 用途 |
|---|---|---|---|
| `largeTitle` | 32 / 38 | 600，-0.8 | 晾片架、观景台、设置 |
| `title` | 22 / 28 | 600，-0.4 | sheet 标题、空状态标题 |
| `headline` | 17 / 22 | 600，-0.2 | CTA、列表主行、按钮 |
| `body` | 17 / 24 | 400 | 正文、说明段 |
| `callout` | 15 / 20 | 400/500 | 材料名、控制值 |
| `subhead` | 14 / 19 | 400 | 次级信息、行副标题 |
| `footnote` | 13 / 18 | 400 | 必要说明（最小正文） |
| `caption` | 11 / 14 | 500 | tab 标签、缩略图时间（非必读） |
| `plate` | 32 / 36 | 600，tabular | 显影时钟 |
| `data` | 15 / 20 | 400，tabular | 温度、EV、CC、像素 |
| `micro` | 9.5 / 12 | 600，+1.1 大写 | 胶片边缘、极小的元数据 |

规则：

- 只有 **section header** 和 **胶片边缘** 用大写 + 字距；按钮、行标题、控制标签用句首大写（中文不用大写）。
- 所有数字（时间、EV、温度、CC、像素、张数）用 tabular，值变化时布局不跳。
- 支持 Dynamic Type 到 1.3×；`largeTitle` 可以缩到 1.15×，避免撑破 nav；正文必须重排，不截断。
- 中英文混排时，中文行高按 1.5 倍给足；英文更松，不要为了英文把中文挤成两行。

### 5.3 间距、圆角、控件高度

| 项 | 值 | 说明 |
|---|---|---|
| 间距 | 4 / 8 / 12 / 16 / 20 / 24 / 32 | 不再加 6、10、14 这类散值 |
| 屏幕边距 | 16 | 卡片、CTA、内容一致 |
| 卡片圆角 | 16 | 材料卡、deck、settings 组 |
| 控件圆角 | 10 | segmented、chip、搜索框 |
| 动作圆角 | 14 | 50 pt CTA |
| sheet 圆角 | 28 | 顶部两角 |
| 胶囊 | 999 | 温度 pill、标签 |
| nav | 52 | 含 34 pt segmented |
| tab bar | 49 + safe | iOS 标准 |
| CTA | 46–50 | 全宽，距 deck 底 12；显影/印相可用 46 |
| 行 | 56 | 材料/胶片行；最小 44 |
| 控制 | 44 × 44 | 步进器、图标按钮、关闭 |
| 缩略图 | 44–58 | 试片条、时间条 |
| 分段 | 32 | 三等分，点击区 44 |

### 5.4 图标

- 房间/步骤的标记沿用现有 `_DarkroomMark`、`_RackMark`、`_GalleryMark`，放大到 24 pt，描边 1.6，圆头。
- 系统符号（chevron、gear、xmark、search、sun、back、share、check、info）用同一套 24 网格、1.6 描边、圆头手绘；不引入 Material Icons，也不依赖 SF Symbols。
- 图标永远配文字（tab 除外），不靠猜。

### 5.5 材质与深度

- **导航/tab**：玻璃 + hairline；没有阴影。
- **deck**：card 填充 + 0.5 hairline；没有阴影。它是控制面，不是浮起的卡片。
- **相纸**：允许 `paper` 的物体阴影（已有的 `KalloShadowBox` 纸阴影），因为它是在房间里的纸，不是布局层级。
- **晾片架卡片**：纸 + 轻物体阴影 + 线 + 夹子；允许，因为它是挂在空中的纸。
- **胶片框**：黑 rebate、齿孔、边缘字；观景台/晾片架保留。
- **segmented 选中**：`card` 填充 + 0.5 hairline，不用投影；暗色用 `fillStrong`。

### 5.6 动效与触感

| 事件 | 动效 | 触感 |
|---|---|---|
| 步骤切换 | 分段滑块 160 ms `enter` | selection |
| 打开 sheet | 240 ms 上滑 + scrim 32% | light |
| 关闭 sheet | 160 ms 下滑 | light |
| 选胶片/相纸 | 选中行 90 ms 底色 | selection |
| 拖动时间 | 指针跟手；刻度处轻微吸附 | selection（每 0.5 min 不震，刻度/整数才震） |
| 显影完成 | 新试片从底部弹入，120 ms 淡入 | success |
| 印相完成 | CTA → 顶部 toast「Printed」+ View | success |
| 错误 | 行内红色文字，不弹窗 | warning |
| 灯开关 | 240 ms 光量变化 | light |

- 减少动态：`MediaQuery.disableAnimations` 时去掉 sheet 位移和试片弹入，只保留交叉淡入。
- 不用循环动画装饰；进度用 2 pt 细线或 CTA 内文字，不用全屏 spinner。

---

## 6. 逐屏设计

### 6.1 Select：照片是这一页

```text
status 47
nav 52    KALLO      [Select|Develop|Print]      ⚙
stage     ┌──────────────────────────────┐
          │                              │ 320
          │        original              │
          │        (contain)             │
          └──────────────────────────────┘
          IMG_2048.HEIC          4032 × 3024
          MATERIALS
          ┌──────────────────────────────┐
          │ ▣ PORTRA 400              ›  │ 64
          │   Kodak · C-41               │
          ├──────────────────────────────┤
          │ ▤ CRYSTAL ARCHIVE PEARL   ›  │ 64
          │   Fujifilm · RA-4            │
          └──────────────────────────────┘
          ● Metered · 0.0 EV · spectral
CTA 50    [            Continue            ]
tab 49+34 [ Darkroom ] [ Rack ] [ Gallery ]
```

- 照片放在**黑卡纸**上（`KalloFilm.rebate`），`contain`，不裁切、不拉满。黑卡纸让原片从页面里出来，也给肖像/横幅一个稳定的框。
- 左上角小胶囊 `ORIGINAL`；右下角 `Change` 胶囊（32 pt，点击区 44）；不把「换一张」做成标题栏里的橙色小字。
- 照片下是文件名与像素；再下是 `MATERIALS` section header。
- 材料只有两行，不是货架：胶片、相纸。行高 64，左侧 35 pt 图标，标题 15/600，副标题 12/400，右侧 chevron；点行开全高 picker。
- 曝光是事实，不是控制：`● Metered · 0.0 EV · spectral` 一行 11 pt；不可点。
- **CTA 固定在 tab bar 上方**，不随材料滚动：`Continue` 50 pt，radius 14；无照片时换成 `Choose a Photograph`。
- 没有照片时，整个 stage 是空状态：76 pt 圆角图标、22 pt 标题「Start with a photograph」、13 pt 说明、CTA，底部一句「Your original is never modified.」。不要出现第二次「选一张照片」。
- 有照片以后，材料卡出现；如果当前 strip 已有试片，换照片/胶片/相纸前先确认。
- **反转型胶片**：相纸行变灰并显示「This film is its own picture」；Continue 仍可去显影，Print 步骤显示「没有印相」。
- 没有模型/目录未加载：材料行显示「Film list unavailable」，CTA 禁用并给一句原因；不假装有材料。

**胶片/相纸 picker（sheet）**

```text
          ╭──────────────────────────────╮
          │            Film          ✕   │
          │  🔍 Search 24 films          │
          │  [ All | Negative | Reversal | Mono ]
          │  KODAK                       │
          │  ┌──────────────────────────┐│
          │  │ PORTRA 400             ✓ ││ 56
          │  │ Colour negative · C-41   ││
          │  ├──────────────────────────┤│
          │  │ PORTRA 800               ││
          │  └──────────────────────────┘│
          │  FUJIFILM …                  │
          │  A different film starts a   │
          │  new strip.                  │
          ╰──────────────────────────────╯
```

- `.large` 高度约 90%，顶部 28 pt 圆角，grabber 5 × 36；scrim 32%。
- 标题 17/600 居中；右上 32 pt 圆底 `✕`；搜索框 36 pt；四段 filter 32 pt。
- 行 56 pt，按 maker 分组（`KODAK` / `FUJIFILM` / `ILFORD`），maker 是 section header，不重复在每一行前面。
- 行主标题是产品名（`PORTRA 400`），副标题是化学与工艺（`Colour negative · C-41`）；选中的行用 `accentSoft` 底 + 右侧对勾，不是橙色 chip。
- 点一行立即应用并关闭；没有「Done」二段确认。若已有试片，先弹 `Start a new strip?` 确认。
- 搜索为空、无结果、目录未加载都有行内空状态。
- 相纸 picker 同一骨架；先按当前胶片可用相纸过滤；反转型显示说明而不是空列表。

### 6.2 Develop：一张纸、一条试片、一个时间

```text
status 47
nav 52    [Select|Develop|Print]      ⚙
stage     ┌──────────────────┐
          │    developed      │  (纸)
          │    test print     │
          └──────────────────┘
          PORTRA 400 · CRYSTAL        Test print
deck 236  ╭────────────────────────────────╮
          │ TEST STRIP  2 prints   New strip│
          │ [6:00] [12:00] [15:00]          │
          │ 12:00                  20.0 °C  │
          │ ├──────●───────────────────────┤│
          │ [        Develop 12:00        ] │
          ╰────────────────────────────────╯
tab 49+34
```

- **照片就是试片**：当前时间对应的 1200 px 试片，放在暖白相纸上；纸有边、有物体阴影。点纸可以进入全屏预览（隐藏 chrome，双指缩放），这样主屏即使纸只有 250 pt 宽，也能看细节。
- 纸下只有一行材料名（12 pt muted）+ `Test print`；不要重复温度，温度在 deck 里。
- **deck 是仪表盘**：
  - 第一行是试片条：`TEST STRIP` 9.5 大写 + 张数；右侧 `New strip`（13 橙，破坏性确认）。缩略图 44 × 44，下面时间 9 pt；选中 1.5 pt 橙框。
  - 第二行是时钟 32/600 tabular + 右侧温度 pill（28 pt，点击区 44）。点温度开 `.medium` sheet：大号数值、−/+ 44、滑杆、说明「Changing temperature starts a new strip」；设置后若已有试片先确认。
  - 第三行是 46 pt 的时间尺：3/6/9/12/15 五个刻度；拖动跟手；数值在 0.5 min 量化；刻度/整数吸附带 selection 触感。
  - 最后是 44–50 pt 的 `Develop 12:00`。已有该时间的试片时文案变 `Re-develop 12:00`，旁边出现「Remove this print」文本按钮（或长按缩略图 → context menu）。
- **没有试片**：deck 收起试片条，只留一行「A test print fixes the exposure.」+ `Develop first print`；纸的位置显示原片，上面一枚 `NOT DEVELOPED` 胶囊，而不是空白纸。
- **渲染中**：保留上一张图；CTA 文字变 `Developing…` 并在按钮内显示 2 pt 进度；禁用时间尺，避免连点。不要用全屏 spinner。
- **Details**：stage 右上 32 pt `i` 打开 `.large` sheet，放胶片曲线、相纸曲线、Gamma/Dmax、材料全名；桌面 inspector 的密度都在这里，不占主屏。
- **换温度/胶片/相纸**：都是新 strip 的语义；有试片时确认。确认文案写清「3 test prints will be cleared; the photograph stays.」

### 6.3 Print：四个值，一张成品

```text
status 47
nav 52    [Select|Develop|Print]      ⚙
stage     ┌──────────────────┐
          │   finished print  │
          └──────────────────┘
          12:00 · +0.0 EV · Y0 M0 C0 · KG2
deck 192  ╭────────────────────────────────╮
          │ TIME 12:00      EXPOSURE +0.0  │
          │ BALANCE Y0M0C0  GLASS KG2      │
          │ [            Print            ] │
          ╰────────────────────────────────╯
```

- 成品是主体，比显影页更大；下方一行 11–12 pt 的状态串（tabular），让人一眼确认当前组合。
- deck 是 **2 × 2 的控制摘要**（192 高），不是四个 stepper 堆叠：
  - `TIME 12:00`、`EXPOSURE +0.0 EV`、`BALANCE Y0 M0 C0`、`GLASS KG2`。
  - 每格 54 高，标签 9 pt 大写，值 14.5/600，右下 chevron；点击区 54。
  - 点任意一格打开对应 sheet，**主屏的成品仍然可见**：
    - Time：当前 strip 的试片列表（缩略图 + 时间），选一个。
    - Exposure：`.medium` sheet，大号 −/+ 44 pt，步进 0.1 EV，范围 ±2；拖动时实时更新。
    - Balance：Y/M/C 三行，每行 −/+ 44 pt，步进 5；顶部一个 Reset。
    - Glass：`None / KG1 / KG2 / KG3 / KG5` 列表，44 行，附一句说明。
- `Print` 打开印相选项 sheet：尺寸（Original / 6000 / 4000 px）与格式（PNG/JPEG/TIFF），每行 56，底部 `Print`。选项 sheet 里显示预计像素和文件类型。
- 印相中：CTA `Printing…`，禁用控制；成功后顶部 toast `Printed` + `View`，点 View 去晾片架；失败在 CTA 上方一行红字，不弹窗。
- 没有试片：整页空状态 + `Go to Develop`；不要让 Print 分段可点却空空如也。
- 反转型：没有 Print；步骤条里的 Print 显示不可用并说明。
- Details：与显影共用 sheet，显示当前设置下的相纸曲线。

### 6.4 Drying rack：两列纸

```text
status 47
nav 98    Drying rack                     ⚙
          4 prints · newest first
content   ┌─────────┐  ┌─────────┐
          │ 01 15:00│  │ 01 13:30│   两列
          │ paper   │  │ paper   │
          └─────────┘  └─────────┘
          ┌─────────┐  ┌─────────┐
          │ 01 12:00│  │ 01 10:30│
          └─────────┘  └─────────┘
tab
```

- 大标题 32/600，副标题「4 prints · newest first」；右上齿轮。
- 2 列，边距 16，列距 12；每张纸宽约 171，按原图比例，绝不裁成正方形。
- 卡片 = 纸 + 6 pt 白边 + 0.5 hairline + 物体阴影 + 顶部一个 9 × 13 夹子 + 一条 1 pt 线；线是房间的，不是分割线。
- 图下 10 pt：`01 · 15:00`（tabular）+ 胶片短名；不显示无意义的「1 of 1」。
- 正在显影的 job 在顶部一张 `Developing 15:00…` 卡片，2 pt 进度；不阻塞列表。
- 空状态：线 + 夹子图标、`Nothing on the rack`、`Make a print in the darkroom. It will hang here while it dries.`、`Open the Darkroom`。
- 点一张 → 全屏 viewer：黑底、顶部 44 的返回/标题/导出、图片 `contain`、双指缩放、双击 1:1、下滑关闭；底部材料/时间/温度/日期；无 tab bar。
- 桌面现有的 `Rack` 几何（138 pt 线、28 pt 边距、260 最大宽）留作桌面；手机用新的网格。

### 6.5 Gallery：一面墙

```text
status 47
nav 98    Gallery                        ☀
          4 prints · one lamp
content   ┌─────────┐  ┌─────────┐
          │ film 01 │  │ film 02 │   两列 35 mm
          │         │  │         │
          └─────────┘  └─────────┘
          ┌─────────┐  ┌─────────┐
          │ film 03 │  │ film 04 │
          └─────────┘  └─────────┘
tab
```

- 大标题 + 副标题；右上 **一个太阳图标** 开关灯，不是「Loupe」「Light」两个文字 pill。手机上删掉 Loupe 开关。
- 2 列胶片框，边距 16，列距 12；框宽约 171，黑 rebate 9 pt，两侧齿孔 4 pt，边缘字 4.5 pt 只做纹理，不要求读。
- 一列可以长短错落（竖构图更高）；不做统一正方形，胶片就是胶片。
- 1 张时：单张居中，最大宽 420；2 张以上：2 列。空墙：一根线 + 空框图标、`An empty wall`、`Prints you make will hang here.`、`Make a Print`。
- 点一张 → 全屏 35 mm viewer：胶片框 fit，图片在 gate 内双指放大（1:1 上限），顶部返回/标题/导出，底部像素 + 缩放百分比；没有鼠标 hover 的玻璃，触摸用 pinch + double-tap。
- 灯：一个开关改变墙的 `light` 和纸的亮度；关灯时墙黑、标签退到 10%，窗框和返回仍在。动效 240 ms。
- 排序仍是 newest first；进入 gallery 时如果列表为空，显示空状态，不显示一块空墙。

### 6.6 Settings：整页，不是抽屉

```text
status 47
nav 48    Settings                    Done
content   APPEARANCE
          ┌──────────────────────────┐
          │ Interface [System|Light|Dark] │
          └──────────────────────────┘
          LANGUAGE
          ┌──────────────────────────┐
          │ Follow the system      ✓ │
          │ English                  │
          │ 中文                     │
          └──────────────────────────┘
          LIBRARY
          ┌──────────────────────────┐
          │ Location      Kallo album ›│
          │ Import images            ›│
          │ Repair markers  Up to date│
          └──────────────────────────┘
          COLOUR
          ┌──────────────────────────┐
          │ Spectral path        [on] │
          └──────────────────────────┘
          ABOUT
          ┌──────────────────────────┐
          │ ▣ Kallo 0.1.0           › │
          └──────────────────────────┘
```

- 从任意房间的齿轮推入，整页覆盖；顶部 48 nav：标题 17/600 居中，右侧 `Done` 16/500 橙色。
- `grouped background` + 12–16 圆角 card；section header 11 大写；行 44，主字 15，副字 11–13；分隔线 inset 14。
- 语言用 checkmark 行，不用 segmented；外观用 30 pt segmented 放在行右侧；Colour path 用 47 × 28 原生 switch。
- 手机上的 Library 不再出现「选择文件夹」；显示系统位置（iOS `Kallo` album / Android `Pictures/Kallo`），导入、修复状态，以及 iOS 部分授权时的说明。
- 页脚说明只在需要时出现：spectral 路径改变会改新 strip，不动已有 strip；手机上不能选文件夹。
- 底部留 24 pt，不贴 home indicator；内容可滚动，不嵌套 sheet 的滚动。

---

## 7. 组件规格（实现时按这个做）

| 组件 | 规格 |
|---|---|
| `MobileNavBar` | 52 高；seg 34 高、3 等分、轨道 `fill`、选中 `card` + 0.5 hairline；齿轮 44 × 44；左右 16；玻璃 + hairline |
| `MobileTabBar` | 49 + safe；3 等分；图标 24、标签 10.5；选中 accent；顶部 hairline；无阴影 |
| `MobileStageTabs` | 3 段；点击区≥44；`Semantics(selected:)`；步骤切换 160 ms |
| `MobileCTA` | 50 高、radius 14、accent、onAccent、17/600；禁用 fill；最小宽 200 |
| `InstrumentDeck` | 左右 12、底 12、高 192–236、radius 16、card、hairline；内部 10–14 padding；CTA 贴底 |
| `TestStrip` | 横滑；缩略图 44–58；选中 1.5–2 pt accent 框；长按 context menu；无滚动条 |
| `TimeRuler` | 46–54 高；track 1 pt；刻度 8 pt；knob 16–28；触控高度≥44；0.5 min 量化；刻度 selection |
| `AdjustmentCell` | 54 高；label 9 大写；value 14.5/600；chevron 14；点击开 sheet |
| `MobileSheet` | top 28 圆角；grabber 5 × 36；scrim 32%；medium/large detent；下拉关闭；键盘避让；`PopScope` |
| `PickerRow` | 56 高；标题 15/600；副题 11.5；选中 accentSoft + check；分隔 inset 14 |
| `SettingsGroup` | 12–16 圆角；行 44；header 11 大写；footer 10.5–13；switch/seg 用原生语义 |
| `EmptyState` | 图标 76 圆角底；标题 22；正文 13；CTA 50；最多两行说明 |
| `Toast` | 底部 tab 上方 12；胶囊 card；17/500；4 s 自动消失；带一个动作 |
| `PrintCard`（rack） | 纸白、6 pt 边、0.5 hairline、物体阴影、夹子、线；图不裁切 |
| `FilmFrame`（gallery） | 沿用现有 35 mm 几何；手机上缩小到 171 宽；边缘字只做纹理 |
| `Viewer` | 全屏、黑；顶部 44；双指缩放、双击 1:1、下滑关闭；底部元数据；无 tab bar |

---

## 8. 交互与状态

### 8.1 破坏性确认

| 动作 | 条件 | 确认 |
|---|---|---|
| 换照片 | 有试片 | `Replace the photograph?` · `N test prints will be cleared. The film and paper stay.` |
| 换胶片 | 有试片 | `Start a new strip with PORTRA 800?` · `N test prints will be cleared.` |
| 换相纸 | 有试片 | 同上，指名相纸 |
| 换温度 | 有试片 | `Change to 24.0 °C?` · `Temperature belongs to the strip; N test prints will be cleared.` |
| New strip | 有试片 | 同上；保留照片/材料/温度 |
| Remove print | 选中试片 | 长按 → context menu；或行内文本按钮；直接移除，可再做一张 |
| Repair markers | 有可修复项 | 直接执行，完成后 toast |

确认用 iOS action sheet 风格：标题 + 一句说明 + 红色 destructive + Cancel；不用 Alert 大段文字。

### 8.2 返回

- Android 返回键：sheet → 关；viewer/settings → 关；Print → Develop → Select；再返回退出。
- iOS：sheet 下拉；viewer/settings 边缘右滑；步骤不拦截边缘手势（避免和系统返回冲突）。
- 关闭 sheet 时恢复触发它的控件焦点/滚动位置。

### 8.3 加载、错误、空

| 场景 | 处理 |
|---|---|
| 照片解码中 | 黑卡纸上 2 pt 进度线；不显示「请稍候」大段文字 |
| 照片解码失败 | 卡纸内一行错误 + `Choose another` |
| 目录未加载 | 材料行 skeleton；CTA 禁用；一行原因 |
| 显影预览渲染 | 保留旧图；纸角 2 pt 进度；CTA 内文案变化 |
| 显影失败 | CTA 上方一行红字；保留当前试片；可重试 |
| 印相中 | CTA `Printing…`；控制禁用；toast 成功 |
| 印相失败 | 行内红字 + 重试；不丢当前设置 |
| 无试片 | 空状态 + 去显影 |
| 晾片架空 | 空状态 + 去暗房 |
| 观景台空 | 空墙 + 去印相 |
| 库权限受限 | settings/library 行给出解释；不假装有全部照片 |
| 无网络 | 无网络依赖；只有 GitHub 链接失败时交给系统 |

### 8.4 无障碍

- 所有可点元素 ≥ 44 × 44；缩略图 44 时用 8 pt 外边距扩展命中。
- 自定义 slider 提供 `Semantics(slider, value)` 和 `increase/decrease` 动作；时间读数用 `darkroomClock`。
- 步骤 segmented 提供 `selected`；材料行提供「Film, PORTRA 400, Colour negative」。
- 对比度：正文用 `inkMuted` 以上；`inkFaint` 只用于装饰。accent 白底 5.18:1，onAccent 5.18:1；暗色 10.22:1。
- Dynamic Type 1.3× 下 deck 可滚动，CTA 不被挤走；不允许文字截断成「…」表达关键值。
- VoiceOver 顺序：stage 主体 → deck 控制 → CTA → tab bar。
- 减少动态：sheet 淡入、试片不弹入；不做视差。

### 8.5 语言与文案

- 中文 tab：`暗房 / 晾片 / 观景`；英文 `Darkroom / Rack / Gallery`。
- 按钮用动词：`Continue`、`Develop`、`Print`、`Choose a Photograph`、`Open the Darkroom`。
- 破坏性按钮用具体名词：`Start a New Strip`，不是 `OK`。
- 技术词保留：`C-41`、`RA-4`、`EV`、`CC`、`KG2`、`Gamma`、`D-max`、`sRGB`；数字不翻译。
- 英文句首大写，中文不加空格；film 名保持厂商写法。

---

## 9. 实现映射

### 9.1 新增/修改

```text
app/lib/
  design/
    mobile.dart             ← KalloLayout、compact 字号/间距/圆角/高度
    strings.dart            ← 手机标签与空状态文案（中英）
  views/mobile/
    mobile_picker.dart      ← 胶片/相纸搜索式 picker
    mobile_settings.dart    ← grouped Settings 整页
  widgets/mobile/
    mobile_chrome.dart      ← darkroom bar、room header、三格 tab bar
    mobile_controls.dart    ← 按钮、段控、开关、行、分组、空状态
    mobile_icon.dart        ← 24 网格手绘图标，无 Material
    mobile_sheet.dart       ← sheet、confirm、choice、全屏 viewer
  views/
    studio.dart             ← 只加 compact 分支；桌面路径原样
    select_stage.dart       ← compact 分支：原片 + 材料两行 + picker
    develop_stage.dart      ← compact 分支：纸 + 试片条 + 时钟/尺/CTA
    print_stage.dart        ← compact 分支：2×2 控制 + 印相选项
    rack.dart / gallery.dart ← compact 网格、空状态、viewer 回调
  main.dart                 ← 手机竖屏锁定；不改回调 API
```

- `Studio`：`_compact` 改为 `KalloLayout.isCompact(context)`；compact 直接返回 `MobileStudio`，**不再进入现有 sidebar/StudioTopBar/StageTabs 路径**。桌面仍走原来的 `_shell`。
- 手机 stage 使用现有 `TestStrip`、`Print`、`Catalogue`、`ui.Image` 数据；不复制模型逻辑，不改 `main.dart` 的回调签名。
- 选取 sheet 由 `MobileStudio` 用 `Overlay` + `AnimationController` 实现；不用 Material `showModalBottomSheet`（会引入 Material 语义/主题）。
- 现有 `KalloShadowBox` 的 paper/sheet 资产继续用于相纸和 sheet；deck/nav 不用。
- `Rack` / `Gallery`：桌面实现不动；手机新建 `rack_view` / `gallery_view`，复用 `Print`、`PrintThumbnailCache`、`FilmFrameMetrics`、`PrintViewer` 的缩放/预览核心（把纯图片逻辑抽出来，不复制解码逻辑）。
- `SettingsDrawer`：桌面保留；手机新 `settings_view`，复用 `ExportSetting`、`Settings`、`AppInfo`。
- 手机状态栏：`AnnotatedRegion<SystemUiOverlayStyle>`；Android `SystemChrome.setEnabledSystemUIMode(edgeToEdge)` 已有配置检查。
- 性能：`BackdropFilter` 只用在 52 pt nav 和 83 pt tab bar，不给整页/整张照片加 blur；晾片架和观景台继续走 `PrintThumbnailCache`（512 缩略图 + viewer 的 preview/detail 两级），不因两列网格而多解码原图；sheet 动画只改 transform/opacity，避免整页重排。

### 9.2 分阶段

| 阶段 | 内容 | 完成标准 |
|---|---|---|
| **1. 壳与 token** | 断点、`MobileStudio`、nav/tab/step/CTA/sheet、44 pt 基准 | 390 × 844 上三个空 tab 可切换；iPhone 横向不再出现桌面双栏；桌面 goldens 不变 |
| **2. Select** | 黑卡纸原片、材料两行、picker sheet、空状态、破坏性确认 | 一屏内看到照片、材料、CTA；无 24 个 chip；换材料有确认 |
| **3. Develop** | 试片主体、deck、时间尺、试片条、温度/Details sheet | 一屏内看到纸、时间、试片、CTA；拖动不卡；曲线不占主屏 |
| **4. Print** | 2×2 控制、四个 sheet、印相选项、成功 toast | 四个值都能改且图片实时更新；Print 不需要滚面板 |
| **5. Rack / Gallery / Viewer** | 两列网格、空状态、灯、pinch viewer、删 hover loupe | 一屏至少两张纸/两帧；viewer 可缩放、可返回 |
| **6. Settings / 横屏 / 无障碍** | grouped settings、横屏工作台、Dynamic Type、VoiceOver、haptics | 1.3× 不溢出；横屏不崩；tab/sheet 返回正确 |

### 9.3 测试

- 新增 `app/test/mobile/` widget tests：
  - 390 × 844、375 × 667、430 × 932 三种尺寸；light/dark；
  - 每个可点元素 ≥ 44（遍历 semantics/rect）；
  - 文本缩放 1.3 不 overflow；
  - Android back 层级；
  - 换胶片/相纸/温度有试片时出确认；
  - 空状态 CTA 能到下一步；
  - sheet 下拉/点 scrim 关闭。
- 新增手机 goldens：`test/goldens/macos/mobile/{select,develop,print,rack,gallery}.png`，使用合成的 test card，不引入真人照片。沿用现有 `studio-goldens` opt-in。
- 集成测试：iPhone/Android 用 **合成图** 走 选片 → 胶片 → 相纸 → 显影 3/6/9 → 印相 → 晾片架 → 观景台 → 设置；不把个人照片带进仓库。
- 桌面：现有 12 张 macOS goldens、widget tests 全绿；CI 7 项全绿。

### 9.4 不做什么

- 不改模型的数学、数据文件、XMP、catalog；PhotoKit/MediaStore 只在 Android 权限时机上调整。
- 不改桌面布局、桌面 sidebars、桌面 goldens。
- 不引入 `MaterialApp` / `Material` / `CupertinoApp` / `CupertinoPageScaffold`；不引入新字体。
- 不为了「像 iOS」而把 safelight 橙换成系统蓝；Kallo 的强调色就是 safelight。
- 不把手机做成桌面工作室的响应式缩小版；手机是独立壳。
- 不在这一版做 iPad 专门布局；medium 先保证不崩、可读、单列。

---

## 10. 验收清单

- [ ] 390 × 844 下，Select/Develop/Print 的主体区至少占内容高度 50%；照片/纸本身 ≥ 280 pt（Select ≥ 300 pt）；CTA 首屏可见，不需要滚动。
- [ ] 没有任何可点元素 < 44 × 44；正文 ≥ 15，必要说明 ≥ 13。
- [ ] 顶栏只有一套步骤分段；底栏只有三个房间；没有房间名胶囊。
- [ ] iPhone 横向（844 × 390）不出现桌面 sidebar/inspector；至少保持单列可操作。
- [ ] 选胶片/相纸是 56 pt 行 + 搜索 + 化学分组，不是 24 个 chip。
- [ ] 换胶片/相纸/温度/照片，在有试片时先确认，并说明会清掉几张。
- [ ] 显影页的主屏只有纸、时间尺、试片条、CTA；曲线在 Details sheet。
- [ ] 印相页四个值一眼可见；点任意值开 sheet，图片仍可见；Print 开选项 sheet。
- [ ] 晾片架/观景台手机是 2 列；一张时观景台单张居中；空状态有 CTA。
- [ ] 手机没有 Loupe 开关；viewer 支持 pinch、双击 1:1、下滑关闭。
- [ ] 设置是整页 grouped list，不是横向 tab 轨 + 抽屉。
- [ ] 1.3× 字号不溢出；VoiceOver 能读步骤/材料/时间/CC/灯。
- [ ] 桌面 12 张 goldens 不变；CI 全绿。

---

## 11. 已拍板

1. **底栏 3 个房间 + 齿轮**，设置不是房间。
2. **观景台 2 列胶片**；一张时仍按单张居中。
3. **换胶片/相纸/温度/照片时，有试片先确认**；文案说明会清掉几张。桌面保持原行为，是否同步由另一次改动决定。

一个实现层面的决定也一并记下：Android Adreno 730 把单个 storage buffer binding 截在 128 MiB，12 MP 成品是 195 MiB，所以旧实现会在 `create_bind_group` 报 wgpu validation error、退回 CPU。现在 GPU 后端把大于 binding 上限的帧按水平 band 渲染，band 上下带够垂直 effect 的 guard 行，body 行与整帧渲染逐位相同（Rust 有对照测试）；`FfiModel.develop` 的 CPU 重试仍在，作为驱动异常的兜底。预览会话（`PreviewBench`）失败时，显影/印相页仍退回一次性的 CPU 渲染。

Android 照片权限也改成按需：启动只读状态、不弹窗；第一次点「选择照片」时先用自己的 sheet 解释「权限买到的是看到其他应用放进 `Pictures/Kallo` 的照片，不是选片本身」，同意后才进系统对话框；「暂不」仍然打开系统选择器。设置页保留「照片访问」行，永久拒绝时走系统设置。

---

## 12. 参考

- 现有设计规则：`app/README.md`（无 Material、无布局阴影、一个强调色、封闭的间距/圆角/字号、胶片是几何）。
- 现有桌面 goldens：`app/test/goldens/macos/`。
- 现有紧凑分支：`app/lib/views/studio.dart`、`select_stage.dart`、`develop_stage.dart`、`print_stage.dart`、`gallery.dart`、`rack.dart`、`drawer.dart`。
- 本方案视觉稿：[board-1.png](board-1.png)、[board-2.png](board-2.png)、[board-3.png](board-3.png)、[mockups.html](mockups.html)。

> 视觉稿是方向稿：390 × 844、Inter、真实字号与触控尺寸。落地时以第 5 节的封闭 token 为准；桌面不动。当前实现已通过 `flutter analyze`、完整 widget 测试和 12 张桌面 goldens；手机测试在 `app/test/mobile_test.dart`。
