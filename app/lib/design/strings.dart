import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../lab/edge_print.dart';
import '../lab/roll.dart';
import '../lab/stock.dart';

/// The words that are not the film's.
///
/// The film's own vocabulary never translates: `EI`, `C-41`, `GOLD 200`, a
/// temperature, a time. Everything a person reads as a label does — which is
/// most of this file. The English build is the Chinese build with fewer words
/// in it, so switching moves no layout.
class KalloStrings {
  const KalloStrings(this.zh);

  /// Whether the human layer is Chinese.
  final bool zh;

  static KalloStrings of(BuildContext context) =>
      Localizations.of<KalloStrings>(context, KalloStrings)!;

  static const LocalizationsDelegate<KalloStrings> delegate =
      _KalloStringsDelegate();

  static const List<Locale> supported = <Locale>[Locale('en'), Locale('zh')];

  // -- the places -----------------------------------------------------------

  String placeLabel(String name) => switch (name) {
    'shelf' => zh ? '架子' : 'Shelf',
    'table' => zh ? '台面' : 'Table',
    'workbench' => zh ? '工作台' : 'Workbench',
    'binder' => zh ? '活页夹' : 'Binder',
    'rack' => zh ? '晾片架' : 'Drying rack',
    _ => zh ? '观景台' : 'Gallery',
  };

  String get library => zh ? '资料库' : 'Library';

  // -- the studio -----------------------------------------------------------

  /// The two rooms, and the rack between them. The darkroom is where the work
  /// is made; the gallery is where it is looked at; the rack is where the paper
  /// goes when it comes out.
  String get darkroom => zh ? '暗房' : 'Darkroom';
  String get rack => zh ? '晾片架' : 'Drying rack';
  String get galleryRoom => zh ? '观景台' : 'Gallery';

  /// The short names the phone's tab bar has room for. The rooms are the same;
  /// only the label is shortened so three of them fit under a thumb.
  String get rackTab => zh ? '晾片' : 'Rack';
  String get galleryTab => zh ? '观景' : 'Gallery';

  /// The three steps of the darkroom, in the order the work goes.
  String get selectStep => zh ? '选片' : 'Select';
  String get developStep => zh ? '显影' : 'Develop';
  String get printStep => zh ? '印相' : 'Print';

  String get settings => zh ? '设置' : 'Settings';
  String get showSidebar => zh ? '显示侧边栏' : 'Show sidebar';
  String get hideSidebar => zh ? '隐藏侧边栏' : 'Hide sidebar';
  String get showInspector => zh ? '显示面板' : 'Show inspector';
  String get hideInspector => zh ? '隐藏面板' : 'Hide inspector';
  // The window's own three, where the app draws the frame. A screen reader
  // reads them, so they say what they do and not what they look like.
  String get minimizeWindow => zh ? '最小化' : 'Minimize';
  String get maximizeWindow => zh ? '最大化' : 'Maximize';
  String get restoreWindow => zh ? '还原' : 'Restore';
  String get closeWindow => zh ? '关闭窗口' : 'Close window';
  String get noPhotographChosen => zh ? '还没选片' : 'nothing chosen';
  String get choosePhotoNote => zh
      ? '选一张照片。胶片和相纸随后决定。'
      : 'Choose a photograph. The film and paper come after.';
  String get originalNote => zh
      ? '照片还没有进显影液。先看它，再选胶片。'
      : 'The photograph before the developer. Look first, then choose a film.';
  String get theOriginal => zh ? '原片' : 'ORIGINAL';
  String get changePhoto => zh ? '换一张' : 'Change';
  String get materials => zh ? '材料' : 'MATERIALS';
  String get change => zh ? '更换' : 'Change';
  String get details => zh ? '详情' : 'Details';
  String get goDevelop => zh ? '去显影' : 'To the developer';
  String get metered => zh ? '自动测光' : 'Metered';
  String get exposure => zh ? '曝光' : 'EXPOSURE';

  /// The strip, and the one exposure every print on it shares.
  String get testStrip => zh ? '试片条' : 'TEST STRIP';
  String get testPrint => zh ? '试片' : 'Test print';
  String get testStripHint =>
      zh ? '先冲一张试片，确定相纸曝光。' : 'A test print fixes the exposure.';
  String get developFirst => zh ? '先冲一张' : 'Develop first print';
  String get noTestPrintShort => zh ? '还没有试片' : 'No test prints yet';
  String get testStripNote => zh
      ? '每显影一次生成一张；所有试片共用首张的相纸曝光。'
      : 'One print per development, all on the first print\'s paper exposure.';
  String get noTestPrints =>
      zh ? '还没有试片。选好时间，按显影。' : 'No prints yet. Choose a time and develop.';
  String get newStrip => zh ? '另起一条' : 'New strip';
  String get newStripQuestion => zh ? '另起一条试片？' : 'Start a new strip?';
  String get changePhotoQuestion => zh ? '换一张照片？' : 'Replace the photograph?';
  String get changeFilmQuestion => zh ? '换胶片？' : 'Change the film?';
  String get changePaperQuestion => zh ? '换相纸？' : 'Change the paper?';
  String get changeTemperatureQuestion =>
      zh ? '换温度？' : 'Change the temperature?';
  String clearsPrints(int count) => zh
      ? '这会清掉 $count 张试片。'
      : '$count test print${count == 1 ? '' : 's'} will be cleared.';
  String get keepsPhoto =>
      zh ? '照片和材料保留。' : 'The photograph and materials stay.';
  String get keepsPhotoAndFilm =>
      zh ? '照片和胶片保留。' : 'The photograph and film stay.';
  String get keepsPhotoAndPaper =>
      zh ? '照片和相纸保留。' : 'The photograph and paper stay.';
  String get newStripAction => zh ? '另起一条' : 'Start a New Strip';
  String get changeAction => zh ? '更换' : 'Change';
  String get removeAction => zh ? '移除' : 'Remove';
  String stripCount(int count) =>
      zh ? '$count 张' : '$count print${count == 1 ? '' : 's'}';
  String get firstPrint => zh ? '首张' : 'First print';
  String get sameExposure => zh ? '同曝光' : 'One exposure';
  String get firstPrintWaiting => zh ? '首张待定' : 'the first print decides';
  String exposureOf(String clock) =>
      zh ? '同曝光 · $clock' : 'one exposure · $clock';
  String get removePrint => zh ? '移除这张' : 'Remove this print';
  String get materialsNote =>
      zh ? '换胶片或相纸，会另起一条试片。' : 'A different film or paper starts a new strip.';
  String get temperatureNote => zh
      ? '温度属于这条试片。换温度会另起一条，照片和材料保留。'
      : 'Temperature belongs to the strip. Changing it starts a new strip; the photograph and materials stay.';

  /// The instrument panel's curves.
  String get filmCurve => zh ? '胶片' : 'FILM';
  String get paperCurve => zh ? '相纸' : 'PAPER';
  String get printCurve => zh ? '印相' : 'PRINT';
  String get printExposure => zh ? '印相曝光' : 'PRINT EXPOSURE';
  String get filters => zh ? '滤色片' : 'FILTERS';
  String get heatGlass => zh ? '隔热玻璃' : 'HEAT GLASS';
  String get noGlass => zh ? '无' : 'none';
  String get reset => zh ? '归零' : 'Reset';
  String get developing => zh ? '显影中…' : 'Developing…';
  String get redevelop => zh ? '重冲' : 'Re-develop';
  String get printAction => zh ? '印相' : 'Print';
  String get size => zh ? '尺寸' : 'SIZE';
  String get originalSize => zh ? '原尺寸' : 'Original';
  String get noUpscale => zh ? '只缩不放' : 'Never upscales';
  String get format => zh ? '格式' : 'FORMAT';

  /// The edge a print can carry. A printing choice, not a viewing one: the
  /// template is printed into the print, not kept as a second file.
  String get border => zh ? '边框' : 'BORDER';

  /// What a screen reader says about one edge. The picker draws pictures and
  /// no words at all, so these names are spoken, never set.
  String borderName(BorderTemplate template) => switch (template) {
    BorderTemplate.none => zh ? '无边框' : 'No edge',
    BorderTemplate.warm => zh ? '留边·暖' : 'Edge · warm',
    BorderTemplate.neutral => zh ? '留边·中性' : 'Edge · neutral',
    BorderTemplate.whiteAmber =>
      zh ? '留边·白孔·琥珀字' : 'Edge · white holes · amber print',
    BorderTemplate.white =>
      zh ? '留边·白孔·白字' : 'Edge · white holes · white print',
    BorderTemplate.whiteBlank =>
      zh ? '留边·白孔·无字' : 'Edge · white holes · no print',
  };

  String get cancel => zh ? '取消' : 'Cancel';
  String get done => zh ? '完成' : 'Done';
  String get view => zh ? '查看' : 'View';
  String get printedToast => zh ? '已印好' : 'Printed';
  String get openDarkroom => zh ? '回到暗房' : 'Open the Darkroom';
  String get makePrint => zh ? '去印一张' : 'Make a Print';
  String get emptyGalleryTitle => zh ? '墙上还没有东西' : 'An empty wall';
  String get emptyGalleryNote =>
      zh ? '印出来的照片会挂在这里。' : 'Prints you make will hang here.';
  String get export => zh ? '导出' : 'Export';
  String get lossyNote => zh ? 'JPEG · 有损 · 文件更小' : 'JPEG · lossy · smaller';
  String get losslessNote => zh ? '无损 · 文件更大' : 'Lossless · larger';
  String get printNote => zh
      ? '成品会为这张底片重新平衡，不沿用试片上的曝光。'
      : 'The finished print is balanced for this negative, not for the strip\'s exposure.';
  String get chooseFirstPrint => zh
      ? '先冲一张试片，再印成品。'
      : 'Develop a test print first; the finished print follows.';
  String get printQueued =>
      zh ? '已印。去晾片架看看。' : 'Printed. Look at the drying rack.';
  String get goRack => zh ? '去晾片架' : 'To the drying rack';

  /// What a roll is called on the pages that name it.
  ///
  /// The photograph, because that is what the roll is — there is one, so it
  /// does not need a number, and a name is what it had before it was film. A
  /// roll the model drew has no photograph: it is the strip that proves the
  /// sheet can be read at all, and it says so.
  String rollName(Roll roll) => roll.name ?? (zh ? '模型样片' : 'Model strip');

  String frames(int count) =>
      zh ? '$count 格' : '$count frame${count == 1 ? '' : 's'}';

  // -- the toolbar and the status bar ---------------------------------------

  String statusBar(int frame, String clock, String temp) => zh
      ? '第 $frame 格   ·   $clock   ·   $temp'
      : 'Frame $frame   ·   $clock   ·   $temp';

  // -- the inspector --------------------------------------------------------

  String get frame => zh ? '格' : 'FRAME';

  String ofFrames(int total) => zh ? '共 $total 格' : 'of $total';

  String get time => zh ? '时间' : 'Time';
  String get temperature => zh ? '温度' : 'Temperature';
  String get balance => zh ? '色彩平衡' : 'Balance';
  String get glass => zh ? '隔热玻璃' : 'Heat glass';
  String get gamma => zh ? '伽马' : 'Gamma';
  String get dMax => zh ? '最大密度' : 'D max';
  String get tone => zh ? '影调' : 'TONE';
  String get develop => zh ? '显影' : 'Develop';

  /// The inspector's one action: the frame, on the bench, where it is one frame
  /// and not one of forty. It says what it does, not what a button on a table
  /// is expected to say.
  String get enlarge => zh ? '放大' : 'Enlarge';

  /// The glass on the table: a proof is read through one.
  String get loupe => zh ? '放大镜' : 'Loupe';

  // -- the shelf ------------------------------------------------------------

  String get newRoll => zh ? '新的一卷' : 'A new roll';

  String get newRollNote => zh
      ? '一张照片显影五次，得到一卷。同一格、五个时间。'
      : 'One photograph developed five times makes a roll: one frame at five times.';

  String get photograph => zh ? '照片' : 'PHOTOGRAPH';
  String get choosePhoto => zh ? '选择照片…' : 'Choose a photograph…';
  String get startWithPhoto => zh ? '从一张照片开始' : 'Start with a photograph';
  String get noPhotograph => zh ? '还没选' : 'nothing chosen';
  String get film => zh ? '胶片' : 'FILM';
  String get searchFilms => zh ? '搜索胶片' : 'Search films';
  String get searchPapers => zh ? '搜索相纸' : 'Search papers';
  String get filterAll => zh ? '全部' : 'All';
  String get filterNegative => zh ? '负片' : 'Negative';
  String get filterReversal => zh ? '反转' : 'Reversal';
  String get filterMono => zh ? '黑白' : 'Mono';
  String get noResults => zh ? '没有匹配的项' : 'No matches';
  String get developments => zh ? '显影时间' : 'DEVELOPMENTS';

  String developingOf(int done, int total) =>
      zh ? '显影 $done / $total' : 'developing $done of $total';

  String get noModel => zh
      ? '这台机器上找不到模型（kalo）。没有它，架上只能放着胶片，显不了影。'
      : 'No model on this machine (kalo). Without it the shelf can hold film, but nothing can be developed.';

  String get onTheTable => zh ? '在台面上' : 'on the table';
  String get openRoll => zh ? '打开' : 'Open';

  String get theShelf => zh ? '架上' : 'THE SHELF';

  /// What is on the shelf, counted. The papers are left out when there are
  /// none, which is what a shelf behind a model that does not carry them is.
  String shelfCount(int films, int papers) {
    final String film = zh ? '$films 支胶片' : '$films films';
    if (papers == 0) {
      return film;
    }
    return zh ? '$film · $papers 张相纸' : '$film · $papers papers';
  }

  /// Said when the model did not answer and the shelf holds its one film.
  String get shelfAlone => zh
      ? '模型没有响应。架上只保留内置胶片。'
      : 'The model did not respond. The shelf keeps its built-in film.';

  /// A group of boxes on the shelf, and the chemistry they share.
  String processName(FilmProcess process) => switch (process) {
    FilmProcess.negative => zh ? '彩色负片' : 'COLOUR NEGATIVE',
    FilmProcess.reversal => zh ? '彩色反转片' : 'COLOUR REVERSAL',
    FilmProcess.monochrome => zh ? '黑白' : 'MONOCHROME',
  };

  /// What the chemistry means for the stages a roll goes through. The model's
  /// own sentence, in the app's words.
  String processNote(FilmProcess process) => switch (process) {
    FilmProcess.negative =>
      zh ? '负片 —— 显影、印相、扫描' : 'negative — developed, printed, scanned',
    FilmProcess.reversal =>
      zh ? '反转片 —— 胶片自己就是照片，没有印相' : 'reversal — the film is the picture',
    FilmProcess.monochrome =>
      zh ? '黑白 —— 一个记录，没有染料' : 'monochrome — one record, no dyes',
  };

  // -- the workbench --------------------------------------------------------

  String get printOut => zh ? '印' : 'Print';

  String get colourPaper => zh ? '彩色相纸' : 'COLOUR PAPER';
  String get silverPaper => zh ? '黑白相纸' : 'SILVER PAPER';

  /// Said where the papers would be, for a film whose print stage is skipped.
  String get noPaper => zh
      ? '反转片自己就是照片，没有印相，也就不用选相纸。'
      : 'A reversal is its own picture: no print, so there is no paper to choose.';

  /// Said where the print button would be, for a film that has no print stage.
  String get noPrintStage => zh
      ? '反转片自己就是照片 —— 这一卷没有印相。'
      : 'A reversal is its own picture — there is no print to make here.';
  String get paper => zh ? '相纸' : 'PAPER';

  /// The bench's lamp: the frame as the wall will hang it. A proof, not a
  /// print — nothing is made, and nothing leaves the bench.
  String get proof => zh ? '打样' : 'Proof';
  String get printedOut => zh ? '印好了' : 'printed';
  String get printing => zh ? '正在印…' : 'Printing…';
  String get onTheRack => zh ? '已进晾片架' : 'on the rack';

  // -- the drying rack ------------------------------------------------------

  String printCount(int count) =>
      zh ? '$count 张' : '$count print${count == 1 ? '' : 's'}';
  String get rackEmpty => zh ? '晾片架是空的' : 'Nothing on the rack';
  String get rackEmptyNote =>
      zh ? '在印相步骤印一张，成品会挂到这里。' : 'Make a print in the darkroom; it hangs here.';

  // -- the binder -----------------------------------------------------------

  String get binderNote => zh
      ? '这一卷的来历，以及模型量到的数。'
      : 'Where this roll came from, and the numbers the model measured.';

  String get theFilm => zh ? '胶片' : 'THE FILM';
  String get thePaper => zh ? '相纸' : 'THE PAPER';
  String get measuredAndBorrowed => zh ? '量到的和借来的' : 'MEASURED AND BORROWED';
  String get reference => zh ? '参考显影' : 'Reference';
  String get source => zh ? '出处' : 'Source';

  /// Where in the sheet, and when it was read.
  String page(String page) => zh ? '第 $page 页' : 'page $page';
  String readOn(String date) => zh ? '取于 $date' : 'read $date';

  /// What a `[measured]` line admits to. The four words the catalogue's
  /// vocabulary has; an empty claim is a sentence the four cannot carry, and it
  /// is shown as it stands.
  String claim(String claim) => switch (claim) {
    'measured' => zh ? '量到' : 'measured',
    'borrowed' => zh ? '借来' : 'borrowed',
    'placeholder' => zh ? '占位' : 'placeholder',
    'none' => zh ? '没有' : 'none',
    _ => '',
  };

  /// A field of a stock's record. Technical, so it translates only where the
  /// Chinese has a word of its own for it.
  String field(String field) => switch (field) {
    'curves' => zh ? '曲线' : 'curves',
    'layers' => zh ? '感光层' : 'layers',
    'dyes' => zh ? '染料' : 'dyes',
    'mask' => zh ? '遮罩' : 'mask',
    'grain' => zh ? '颗粒' : 'grain',
    'cl_layer' => zh ? '抑制层' : 'CL layer',
    'white' => zh ? '白' : 'white',
    _ => field,
  };

  String get theRoll => zh ? '这一卷' : 'THE ROLL';
  String get theLadder => zh ? '显影梯度' : 'THE LADDER';
  String get theCurves => zh ? '曲线' : 'THE CURVES';
  String get theFiles => zh ? '文件' : 'THE FILES';
  String get rollFolder => zh ? '卷' : 'Roll';
  String get printsFolder => zh ? '印相' : 'Prints';

  String get noCurve => zh
      ? '这一卷没有附带密度数据，所以没有曲线可画。'
      : 'This roll came without density data, so there are no curves to draw.';

  // -- the gallery ----------------------------------------------------------

  /// The switch on the wall. Not the appearance's light: the room's.
  String get roomLight => zh ? '灯' : 'Light';

  /// Back to the wall, from a print looked at closely.
  String get back => zh ? '返回墙上' : 'Back to the wall';

  /// What a person is looking at: the file's pixels, and how much of them.
  String magnification(String size, String percent) =>
      zh ? '$size 像素   ·   $percent' : '$size pixels   ·   $percent';

  /// The one scale worth naming: one image pixel on one device pixel.
  String get actualPixels => zh ? '1:1' : '1:1';

  // -- the drawer -----------------------------------------------------------

  String get close => zh ? '关闭' : 'CLOSE';

  String get tabLanguage => zh ? '语言' : 'LANGUAGE';
  String get tabAppearance => zh ? '外观' : 'APPEARANCE';
  String get tabPrints => zh ? '印相' : 'PRINTS';
  String get tabColour => zh ? '色彩' : 'COLOUR';
  String get tabRenderer => zh ? '渲染' : 'RENDERING';
  String get tabAbout => zh ? '关于' : 'ABOUT';

  String get language => zh ? '语言' : 'Language';
  String get followsDevice =>
      zh ? '默认跟随系统。' : 'Uses the system setting by default.';
  String get interfaceLanguage => zh ? '界面语言' : 'Interface language';
  String get system => zh ? '跟随系统' : 'System';
  String deviceLine(String tag) => zh ? '设备：$tag' : 'device: $tag';

  String get appearance => zh ? '外观' : 'Appearance';
  String get interface => zh ? '界面' : 'Interface';
  String get appearanceLabel => zh ? '界面外观' : 'Appearance';
  String get light => zh ? '浅色' : 'Light';
  String get dark => zh ? '深色' : 'Dark';
  String systemLine(String value) => zh ? '系统：$value' : 'system: $value';
  // -- prints ---------------------------------------------------------------

  String get prints => zh ? '印相' : 'Prints';

  String get printsNote => zh
      ? '每张印相都是一张图片；文件带着记录，目录保留索引。'
      : 'Every print is a picture; the file carries its record, and the catalog keeps the index.';

  String get folder => zh ? '文件夹' : 'Folder';
  String get choose => zh ? '选择…' : 'Choose…';
  String get importImages => zh ? '导入图片…' : 'Import images…';

  String get importingImages => zh ? '正在导入图片' : 'Importing pictures';

  String importProgress(int done, int total) =>
      zh ? '已完成 $done / $total' : '$done of $total';

  String get cancelling => zh ? '正在停止…' : 'Stopping…';

  String get movePrintsTitle => zh ? '移动 Kallo 印相？' : 'Move Kallo prints?';

  String movePrintsNote(int count, String destination) => zh
      ? '把 $count 张带标记的印相移动到 $destination？其它图片留在原处。'
      : 'Move $count marked prints to $destination? Other images stay where they are.';

  String get movePrintsAction => zh ? '移动印相' : 'Move prints';

  String get useNewFolderAction => zh ? '只切换文件夹' : 'Use new folder only';

  String catalogIssues(int missing, int repairable) {
    final List<String> parts = <String>[
      if (missing > 0) zh ? '$missing 张印相找不到文件' : '$missing prints are missing',
      if (repairable > 0)
        zh ? '$repairable 张印相的标记需要修复' : '$repairable markers need repair',
    ];
    return parts.join(' · ');
  }

  String get repairMarkers => zh ? '修复标记' : 'Repair markers';
  String get useDefault => zh ? '用回默认位置' : 'Use the default';
  String get noFolder => zh ? '这台设备上还没有位置' : 'No folder on this device yet';

  /// Said where the platform does not let an app pick, which is every phone.
  String get fixedFolder => zh
      ? '手机不能选择文件夹。这里是系统给的位置：在「文件」里打开它，放进去的图片会出现在观景台。'
      : 'Phones cannot choose a folder. This is the system location: open it in Files, and the pictures you put there appear on the wall.';

  /// Said when the app can import and save but the platform has not granted
  /// access to the whole folder, so pictures from Files stay invisible.
  String get fixedFolderLimited => zh
      ? '手机不能选择文件夹。照片访问目前只允许了部分图片；要在观景台看到「文件」里放进来的图片，请允许访问全部照片。'
      : 'Phones cannot choose a folder. Photo access covers selected pictures only; to see pictures you put in this folder in Files, allow access to all photos.';

  /// The system photo permission, asked only when a photograph is chosen.
  ///
  /// Saving a print does not need this permission, and neither does the system
  /// picker. The explanation says what it actually buys: seeing pictures other
  /// apps put in the same folder, and a complete list rather than the app's own
  /// files.
  String get photoAccess => zh ? '照片访问' : 'Photo access';
  String get photoAccessAllowed => zh ? '已允许' : 'Allowed';
  String get photoAccessLimited => zh ? '部分照片' : 'Selected photos';
  String get photoAccessDenied => zh ? '未允许' : 'Not allowed';
  String get photoAccessTitle =>
      zh ? '允许 Kallo 访问照片？' : 'Let Kallo see your photos?';

  String get photoAccessNote => zh
      ? 'Kallo 把印好的照片放在系统相册的 Kallo 文件夹。允许访问后，它也能看到其他应用放进这个文件夹的照片；不允许也可以从系统选择照片。'
      : 'Kallo keeps its prints in the Kallo folder of your photo library. Access lets it see pictures other apps put in that folder too; without it you can still choose a photograph through the system picker.';

  String get photoAccessAllow => zh ? '允许访问' : 'Allow access';
  String get photoAccessNotNow => zh ? '暂不' : 'Not now';

  String get photoAccessBlockedTitle => zh ? '照片访问已关闭' : 'Photo access is off';

  String get photoAccessBlockedNote => zh
      ? '系统已经不会再询问，要更改请打开设置。现在仍然可以从系统选择照片。'
      : 'The system will not ask again. Change it in Settings. You can still choose a photograph through the system picker.';

  String get openSettings => zh ? '打开设置' : 'Open Settings';

  // -- rendering ------------------------------------------------------------

  String get rendering => zh ? '渲染' : 'Rendering';
  String get graphics => zh ? '显卡' : 'Graphics';
  String get processor => zh ? '处理器' : 'Processor';
  String get engine => zh ? '引擎' : 'Engine';
  String get rendererGpu => 'GPU';
  String get rendererCpu => 'CPU';
  String get detecting => zh ? '检测中…' : 'Detecting…';
  String get noGpu => zh ? '不可用' : 'Not available';

  /// Said when the machine has no adapter, so the switch is not a lie.
  String get noGpuNote => zh
      ? '这台设备没有可用的 GPU，渲染会留在 CPU。'
      : 'This device has no usable GPU, so rendering stays on the CPU.';

  /// Said under the switch, in the engine's own terms.
  String get rendererGpuNote => zh
      ? 'GPU 更快。驱动拒绝某一帧时，这一张会自动用 CPU 完成。'
      : 'Faster. If a driver rejects a frame, that print is finished on the CPU.';

  String get rendererCpuNote => zh
      ? '只用 CPU：更慢，但每台设备的结果相同，也不碰显卡驱动。'
      : 'CPU only: slower, the same picture on every machine, and it never touches the graphics driver.';

  String cores(int count) => zh ? '$count 核' : '$count cores';

  /// The processor line: its name when the system gives one, the count always.
  String processorValue(String? name, int count) =>
      name == null || name.isEmpty ? cores(count) : '$name · ${cores(count)}';

  // -- colour ---------------------------------------------------------------

  String get colour => zh ? '色彩' : 'Colour';
  String get path => zh ? '路径' : 'PATH';
  String get scalarPath => zh ? '逐通道' : 'Per channel';
  String get spectralPath => zh ? '光谱' : 'Spectral';

  /// What choosing the spectral path does, and what it changes.
  String get spectralNote => zh
      ? '71 个波长走完曝光、印相和扫描，而不是每通道一个数。图像会变淡：染料串色是真实的，不是滤镜。'
      : 'Seventy-one wavelengths through exposure, print and scan instead of one number per channel. The image goes quieter: dye crosstalk is real, not a filter.';
  String get colourNote => zh
      ? '模型只输出 sRGB，显示由系统管理。宽色域取决于显示器。'
      : 'The model writes sRGB; the system manages the display. Wide gamut depends on the screen.';

  String appVersion(String version) => zh ? '版本 $version' : 'Version $version';
  String get openRepository =>
      zh ? '在 GitHub 上打开项目' : 'Open the project on GitHub';

  String get applyAtOnce => zh ? '更改会立即生效。' : 'Changes apply immediately.';
}

class _KalloStringsDelegate extends LocalizationsDelegate<KalloStrings> {
  const _KalloStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';

  @override
  Future<KalloStrings> load(Locale locale) => SynchronousFuture<KalloStrings>(
    KalloStrings(locale.languageCode == 'zh'),
  );

  @override
  bool shouldReload(_KalloStringsDelegate old) => false;
}
