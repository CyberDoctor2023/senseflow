# 整体精简与解耦目标

用户授权：保存当前Git基线并进行整体代码精简、重构和解耦，保持当前产品体验。本轮不改视觉需求，不引入新的产品功能或云服务，不删除用户历史、工具配置、权限与草稿。

## 完成条件

1. 建立可回滚源码基线，排除构建产物与运行数据，不推送远端。
2. 明确生产路径职责和依赖；优先解决主线程重复计算、捕获导入/列表重复刷新、共享单例耦合，再清理过时路径。
3. 历史摘要/筛选、原件载入、媒体准备、持久化、窗口与引导进度分离。生产代码不识别测试样例。
4. 删除被替代生产路径，同步工程引用；归档历史文档保留可追溯入口。
5. 分阶段审查和提交，相关构建、文档会话风险、实际系统捕获与原生窗口验证通过。性能结论有同机测量，不把构建当性能证据。

## 执行阶段

- [x] G0：本地Git源码基线。无原有仓库，无配置提交身份，使用明确Codex本地作者，不改全局配置。
- [x] R1：审查生产职责/重复实现，记录实际风险与有界实施清单。
- [x] R2：历史列表筛选计算与加载/刷新生命周期；捕获导入并发与批量更新边界（risk-stage16、capture-stage7-full及下文生产职责地图）。
- [x] R3：媒体内容准备共用接口；窗口手势与进度监听、教程示例仓库解耦（document-stage7、tutorial-lifecycle-stage17及下文职责地图）。
- [x] R4a：归档35个历史一次性工程脚本，保留路径映射与内容；未删除风险验证。
- [x] R4b：后续生产配置与依赖审计（第九、十一、十二、十七批；保留明确记录的Swift5隔离诊断）。
- [ ] V：构建及实际行为/性能验证，修复回归，最终审查提交。

## 验证计划

已有DocumentWorkflowVerification覆盖原文、草稿和并发会话，Capture验证覆盖来源、去重、迁移与Quick Look。对列表筛选使用真实轻量摘要数据做同机前后测量；验证分页筛选完整性与切换竞态。各阶段完成后合并相关构建，不机械每函数加测试。禁止破坏当前运行开发版，构建完成验证后才安全更新。

## 已知审查入口

Swift生产源码约24620行；AIService 1389、DatabaseManager 986、OnboardingCoordinator 473行不是单凭行数判定删除依据。ClipboardListViewModel.items当前每次读取重新筛选并分析代码；SystemCaptureService依赖全局数据库且捕获刷新逐条通知；媒体详细数据加载在预览、粘贴和拖出重复。先审查调用图后落实。

## 第一批实施与证据

- 原件/缩略图/拖出 PNG 共用 `HistoryMediaLoader`；文件读取与解码离开主线程。移除预览、粘贴、拖出的重复实现。
- 引导进度、教程仓库、系统捕获订阅、文件准备分离；数据库依赖可注入。
- 元数据候选在结果通知时扫描一次，排队导入；复制多个捕获文件只通知历史一次。稳定性等待、来源标记、原件保护规则保持。
- 列表只在加载页或筛选改变时推导展示结果，界面读取不再反复执行代码识别。
- 35个旧工程迁移脚本移至 `scripts/archive/project-migrations/`；不是生产构建依赖。大小写不敏感文件系统中的 Tests/tests 是同一目录，不作为重复测试删除。

证据目录：`out/2026-10-08-project-refactor/`。Debug 构建通过，使用工程现有 xcodebuild 链；本会话无官方 Xcode bridge 工具。截图/录屏来源、去重、旧数据迁移备份、文件所有权、SQL筛选、原生Quick Look验证通过。列表相同200摘要/2000次读取的负向代码筛选热点：83.109967041s → 0.00058775s；不代表全应用滚动帧率。

文档验证未全通过：原文、草稿、百万字符、媒体、滚动等实际断言通过，但另一个可见卡片按压时已有预览是否保留的窗口事件断言出现不稳定失败，后续必须核验激活/事件与可见源卡片，不能宣称整套验证通过。旧触控板纵滑历史翻页用例改为横滑，以对齐最新上下滑呼出/呼入要求；边缘用例使用普通滚轮。暂不替换用户当前运行应用。

## 后续实施边界

R2/R3仍需完成列表刷新竞争、全量捕获通知边界、AI服务并发隔离及数据库职责拆分。当前仅为第一批，不代表整体重构已完成。下一轮先定位窗口事件失败，再继续生产职责拆分；不以删除断言消除失败。

## 第二批实施合同

目标：修复预览外部事件监听与卡片长按竞争；窗口层用卡片命中能力判定背景，避免依赖具体SwiftUI视图。AI身份登录从生成服务拆分；服务改为actor拥有生成工作，移除跨请求可变SDK客户端和纯转发适配层。内存请求记录采用数量/字节双界限，防止截图base64使长期内存无界增长。数据库原文/草稿持久化与工具CRUD分组，保留同一串行store队列和事务。

非目标：变更授权、发送真实付费AI请求、改商业化接口、改变玻璃/布局/滚轮曲线。完成条件：原文/草稿/预览切换完整验证，捕获回归；配置切换不能复用旧服务client；内存限制可验；同设备现有热点与构建无新告警。验证先把真实窗口失败定位并修复，不删断言。

## 第二批验证状态

Debug构建通过。隔离风险验证通过：40次并发工具保存、主键读取、诊断数量/字节限制、跨页代码筛选、固定内容、迟到查询竞争。原生窗口验证首个焦点断言未通过；CUA确认Mac锁屏，不能激活窗口，本次不作为产品焦点回归结论。保留断言，解锁后重新执行。用户运行版未替换。

## 第三批实施合同

历史写入通知在查询进行中不能丢失：合并为一个刷新任务，并在当前读完成后补读最新快照。通知接收不再为每次写入创建包装Task；保留搜索代际隔离、固定内容及空筛选跨页行为。使用延迟真实接口返回验证通知竞争，完成后与后续任务合并构建。

第三批证据：`out/2026-10-08-project-refactor/build-stage3.log`构建通过；`risk-stage3.log`通过并发保存、数量/字节界限、分页、固定、搜索代际和查询期间通知补读断言。AI未发真实请求；窗口焦点/外部点击/首次预览性能验收仍待解锁。待办：OCR逐张Task持有大图和大图在store队列读取；捕获通知边界；剩余组合层并发告警。整体目标尚未完成。

## 第四批实施合同

OCR积压改为一个后台消费者，SQLite原件作为工作来源，仅保留当前一张图片。新图片插入后由同一个store队列推进游标；大图文件读离开store队列，删除后不能写回失效记录。保留新记录OCR语义，不额外扫描历史，也不改变原图。验证连续图片及中途删除，不增加每函数测试。

隔离验证发现自定义数据库原先仍共用生产BlobFileManager目录。本批将数据库原件目录绑定到数据库所有者：默认生产路径不变，自定义数据库使用自身旁的blobs目录，清理不会波及另一个数据库。首轮OCR断言误读摘要（有意不带OCR全文），改为详情读取；不改摘要契约迁就验证。

第四批证据：`build-stage4.log`构建通过；`risk-stage4-final.log`验证连续外置TIFF识别、中途删除不能重建记录、两库相同原件在清理另一库后仍存在。首轮未修复隔离时生成的两个测试原件，经SHA256匹配与生产库零引用确认后，保存至`out/2026-10-08-project-refactor/verification-originals-before-isolation-fix/`，未删除用户引用的文件。OCR消费者结构有界，但未完成同机积压内存/响应时延的前后测量，不宣称全应用性能验收。后续仍需缩略图调度/捕获刷新审查及解锁后的窗口运行证据。

## 第五批实施合同

缩略图缓存达到限制时不应全清空：改为按最近使用逐项淘汰，保留活跃卡片，字节和数量上限均严格成立，单个超大缩略图不留存。保持同键请求共享、原件读取接口及视频缩略图行为。验证实际解码对象复用/冷项淘汰与超预算不缓存。后台解码并发与原生运行测量另外验收，不把缓存改进代替整体验收。

第五批证据：`build-stage5.log`构建通过；`risk-stage5.log`完整风险验证通过，真实缩略图对象身份确认热点复用、冷项独立重建、超预算只返回不留存。当前卡片使用LazyHStack，消失后SwiftUI任务取消，但共享解码任务仍可能继续；下一批需处理调度与取消，而不是简单删除原件或返回空图掩盖积压。捕获历史通知仍逐条发送，因每个文件有稳定性等待，尚无性能证据支持改变即时刷新体验，继续测量。

## 第六批实施合同

缩略图调度由loader actor统一所有权：最多两个解码任务，待处理只保留摘要与等待者；同键共享，最后一个等待者取消时撤销任务，旧任务完成不能清除新任务或写入缓存。取消任务尚未真正完成时仍占解码名额。验证共享等待者独立取消、排队取消不读原件、并发加载峰值与旧结果隔离；不修改预览动效。

第六批证据：`build-stage6-final.log`构建通过，`risk-stage6.log`完整隔离验证通过。实际详情仓库的可控异步边界证明：取消一个等待者不影响同键另一等待者；排队取消不读取原件；详情读取峰值2；已取消旧任务迟到不能删除同键新任务。媒体读取/解码提交前检查取消；正在执行的不可中断原生解码仍等实际返回再释放名额。

## 剩余验收清单（不是完成声明）

- 原生窗口、预览、手势、引导全流程，需确认锁屏解除后执行，保留原有断言。
- OCR积压与快速翻看缩略图的同设备前后响应及内存测量；已有列表热点测量仅覆盖筛选读路径。
- 捕获导入在新队列和媒体目录下重新回归，审查刷新频率的实际成本。
- 核对工程成员、死路径与组合层并发告警；只删除已证实无调用代码，不用unchecked Sendable掩盖所有权。
- 上述证据具备后才替换运行版并做整体完成审查。

## 第七批实施合同

全项目Swift调用检索确认ClipboardItem.getImage和两个generateUniqueId重载无调用。移除模型上的同步磁盘/解码旧入口，保留已统一的HistoryMediaLoader和存储去重逻辑。捕获验证重新链接当前模块，锁屏时只执行明确标注的存储/媒体/筛选范围，不宣称Quick Look可见流程通过。

桌面本轮已解锁，document-stage7.log全部原生断言通过，capture-stage7-full.log包括Quick Look通过。另发现运行旧开发版PID65990在12:50真实闪退：切换系统捕获设置时NSMetadataQuery拒绝单子项OR。独立启动查询复现NSInvalidArgumentException；仅设置predicate而不start不足以验证。将单类别直接用比较predicate，仅两类别组合OR；验证类别和是否导入旧记录的全部组合。此前运行版不替换，先修复此真实崩溃。

第七批证据：build-stage7-crash-fix.log构建通过；risk-stage7.log全部风险验证通过，包括6种启用类别/日期组合实际Spotlight启动、2种全部关闭不启动。捕获存储及Quick Look回归通过；文档完整原生流程通过（包括此前失败的另卡片按压）。文档同进程Debug暖启动对比与135万UTF16长文打开数据归档至document-metrics-stage7.json，截图document-preview-stage7.png；不宣称该数据是首次长按或Release p95。极端1600行合成滚轮峰值不是正常用户输入的视觉验收，保留待实际体验核对。

## 第八批测量合同

使用同一模块和隔离原件集合，将2115ab8中未限并发的缩略图加载器作为只存在于测量资产的基线，与当前加载器分别进程执行实际ImageIO读取/解码；记录wall time和进程峰值RSS。文件仓库不注入等待，不将模拟SQL或Mock延时作为性能证据。结果只说明此组件突发负载，不代表整机滚动帧率或首次长按延迟。随后核对UI、构建、数据安全、架构与交付证据缺口。

第八批缩略图实测：16张不同2400×1600 TIFF原件，360px缩略图，同一设备/模块/无优化编译，独立进程按before-after-after-before顺序，均checksum=1382400。峰值RSS旧288653312/288079872 bytes，新62521344/62603264 bytes（约275→60 MiB）。暖缓存整批旧43.193ms，新70.397/73.054ms；旧首次272.891ms受冷缓存影响，不用该值宣称新实现更快。并发限制换取突发内存降低，完整整批暖吞吐有所下降，不能声称全应用帧率提升。原始源码、源图、日志与结构化数据保存在out/2026-10-08-project-refactor/（BenchmarkThumbnails.swift、LegacyClipboardThumbnailLoader.swift、thumbnail-metrics.json）。

OCR测量使用55eb73c数据库代码（仅将BlobFileManager目录注入为隔离目录，不改OCR调度）、当前生产Vision与数据库代码，同一批16张真实文字TIFF，均全部识别。独立进程顺序before-after-after-before：RSS旧374423552/398262272 bytes，新181485568/173277184 bytes。暖启动旧1.783s，新1.694/1.916s；首次旧19.470s为离群启动样本，不归因为调度改进。原件入库耗时旧0.493/0.344s，新0.249/0.389s，样本不足以宣称普遍提速。证据源BenchmarkOCR.swift、LegacyDatabaseManager.swift及扩展、ocr-*.log。未接触生产数据库与原件目录。

## 第九批实施合同

组合层三个所有者（DependencyContainer、DependencyEnvironment、AppDependencies）明确MainActor，lazy依赖和启动单例由同一UI线程初始化与读取；现有调用入口仅SwiftUI/AppDelegate/异步快捷键协调器。可观察请求记录协议属于UI主线程，异步记录协议保持可跨执行器调用。不将数据库或原生适配器随意标成unchecked Sendable，不机械迁移整个项目到Swift 6。验证构建和实际启动初始化；删除记录器已过时的教学/未来扩展注释。

第九批证据：build-stage9.log构建通过，组合层与可观察记录协议相关隔离告警消失。既有数据库/原生适配器的Sendable诊断仍需按真实所有权审查，未用unchecked Sendable消音。此次提交保留测量原始数据与诚实的吞吐限制；运行版替换、实际启动与引导全流程仍为剩余验收，整体目标不标完成。

第九批实际启动：旧开发版正常Command-Q退出，进程确认终止后保存完整备份至out/2026-10-08-project-refactor/development-app-before-stage9/SenseFlow.app，并保留开发目录中的SenseFlow-pre-stage9.app。完整stage9构建复制到既有开发路径，去除实际存在的构建目录rpath并重新本地签名。新进程34697启动，CUA实际读出搜索、类别、固定及原有历史列表，没有新权限提示；不记录个人历史内容。随后窗口在焦点变化中不可见，CUA滚动/呼出未取得有效窗口证据，进程仍存活且无新增崩溃报告。启动加载通过，但不将这一观察当作滚轮/快捷键/引导全流程通过，后续继续核验。

## 第十批实施合同

全项目及验证源码检索确认NotificationService.hasPermission没有调用者，其同步等待UNUserNotificationCenter回调的信号量是被异步checkPermission替代的旧入口。删除这一阻塞路径，保留现有授权请求与异步状态读取。通知协议删除虚构实现者、未实现的视觉保证和教学样例，保留真实公共方法合同。检查调用引用和差异；与后续生产改动合并构建，不为删除无调用方法添加镜像测试。

教程会话仍在内部构造系统剪贴板写入器并直接调用全局窗口/自动粘贴。将这两个外部副作用放到实际组合入口FloatingWindowManager，会话构造显式接受writer和onPaste，现有生产行为不变；隔离原生教程验证因此可以不写用户剪贴板、不触发其他应用粘贴。完成条件是唯一生产构造点同步、相关构建通过及后续原生教程流程证据。

第十批构建证据：build-stage10.log通过；生产唯一教程构造点同步，通知同步查询在生产与Tests检索均无残留。本批没有增加教程专用生产分支。原生教程与系统快捷键验证尚未完成，构建不代替流程验收。

第十批引导进度证据：Tests/OnboardingProgressVerification.swift链接当前stage10生产模块，使用独立UserDefaults suite。onboarding-progress-stage10.log通过首次等待呼出、先左后右、单方向不前进、900ms阅读与600ms退场期间继续滑动取消切换、预览关闭前不接受分类完成、结束只回调一次、重建恢复及重启清空状态。未写实际剪贴板或生产设置；此验证覆盖进度与异步切换合同，不覆盖原生布局、系统快捷键和触控板视觉。

第十批原生生命周期证据：Tests/TutorialLifecycleVerification.swift在真实NSApplication.run事件循环中创建生产ClipboardTutorialSession，注入独立进度与隔离writer。tutorial-lifecycle-stage10.log通过提示显示/隐藏、示例列表加载、有效窗口尺寸、收起动画结束、再次呼出及关闭后不复活；写入和粘贴次数均为零。不宣称这证明了系统快捷键、实际长按、触控板或视觉排版。

## 当前生产职责地图与剩余审查

| 职责 | 当前唯一所有者 | 边界 |
| --- | --- | --- |
| 历史摘要、分页与刷新代际 | ClipboardListViewModel | 界面读取不再分析全文；一个刷新任务合并通知 |
| 原件读取、图片导出和解码 | HistoryMediaLoader | 文件与ImageIO工作离开UI/store执行器 |
| 缩略图缓存和排队 | ClipboardThumbnailLoader | 两个实际加载名额；LRU与等待者取消 |
| 文档事务和草稿版本 | SQLiteDocumentStore | 同一DatabaseManager队列/连接，无第二份数据库 |
| Spotlight订阅/候选队列 | SystemCaptureService | 顺序导入、代际取消；不按文件名猜来源 |
| 捕获稳定性/媒体准备 | SystemCaptureFileImporter | 原件内容和系统标记校验 |
| 教程进度/示例记录 | ClipboardOnboardingCoordinator / ClipboardTutorialRepository | 独立设置与示例库；原生会话共用产品界面 |
| 教程外部粘贴副作用 | FloatingWindowManager组合入口 | 显式传入writer与onPaste |
| AI身份/生成/诊断 | CodexAuthManager / AIService actor / InMemoryAPIRequestRecorder | 请求局部client；诊断数量和字节有界 |

工程成员已确认媒体、捕获、示例仓库及文档存储均在Sources。旧捕获目录bookmark仍由现有授权恢复路径使用，保留以免撤销已有访问；没有重新引入文件夹选择界面。SQLitePromptToolRepository末尾教学内容不属于运行合同；RepositoryError.notFound全项目无调用，删除这两项。剩余重点是原生交互体验证据、运行版同步和真实Sendable所有权诊断，不扩大为全项目Swift 6迁移。

第十一批：build-stage11.log合并构建通过。调用检索显示CarbonHotKeyAdapter与GlobalHotKeyAdapter均无构造者，前者不在target、后者仍编译且产生Sendable诊断；实际PromptToolCoordinator使用AppHotKeyCoordinator的PromptToolHotKeyHandling。删除两份重复适配器，HotKeyError保留在实际快捷键所有者文件，同步PBX引用。旧RegisterToolHotKey协议/用例尚有历史测试引用，本批不连带删除其断言或声称真实快捷键体验通过。

第十二批实施合同：全项目调用图确认RegisterToolHotKey与HotKeyRegistry只剩彼此及专用Mock/用例测试，没有产品构造点。删除旧协议、纯转发用例和只验证该废弃路径的测试/Mock，同步工程引用与ExecutePromptTool注释；由Git基线保留恢复能力。实际PromptToolCoordinator集成测试保留，不删真实快捷键错误传播与工具创建覆盖。现有隔离风险验证重新链接stage11模块，之后与本批清理合并构建；不以删除测试宣称它们通过。

第十二批构建build-stage12.log通过。重新链接stage11的risk-stage11.log在OCR消费者识别断言未通过，进程14844终止exit133（async main抛出Failure后Swift顶层fatal error）；此前Spotlight组合、工具并发、记录界限、分页与刷新竞争通过。本次不宣称风险整套通过，不修改断言掩盖失败；需诊断Vision完成时延/队列结果，原件和隔离数据库保存在risk-data-stage11供复核。

OCR诊断：只读隔离数据库确认403已识别、405尚无结果，404已删除；同一405原件独立ImageIO+VNRecognizeTextRequest成功，2400×800像素，17.386s、1个结果（vision-diagnostic-stage12.log）。这说明原件可识别，但尚不足证明原队列失败仅为系统时延。已据此启动同一风险二次观测，日志risk-stage11-repeat.log；不改60s断言、不改生产OCR代码，待比较实际结果。

二次观测同样失败，403有文本、405无结果。进程37004一秒采样显示等待主事件循环及store轮询，没有正在执行的Vision识别栈，不能认定持续系统识别耗时是原因。生产OCR catch原来静默返回nil，下一步补仅NSError domain/code的诊断（不含图像、识别文本、路径或密钥），以区别空结果、取消和实际系统错误；不增加自动重试或改变识别语言。

第十三批：build-stage13.log通过，risk-stage13.log捕获TextRecognition.CRImageReaderError code1并同样未通过。对比独立ImageIO解码成功与生产NSImage转换失败，改用ImageIO直接解码原始Data，不改变Vision语言/识别级别、不重试掩盖错误。删除无外部调用的NSImage/CGImage公开转发重载，保留核心识别私有入口。Apple Doc MCP选中Image I/O但symbol返回404，官方网页仅提供JS入口，记录检索限制；本次选择基于同原件实测，构建和原风险断言仍须验证。

第十四批：build-stage14.log通过，但原risk-stage14.log仍出现相同CRImageReaderError code1，说明改用ImageIO尚不能解决识别失败，前一轮解码路径假设未被证实。不宣称修复通过；ImageIO保留作为移除AppKit后台图像转换的统一原件解码路径，继续用独立连续两张Vision请求区分多请求状态与数据库消费行为。当前两个原生诊断进程保留可观测日志与句柄，不无证据重启。

第十五批诊断：独立连续ImageIO/Vision请求第一张15.048s成功，第二张0.032s报e5rtError（precompiled compute operation创建失败，13），无应用数据库/队列参与。官方VNRequest.setComputeDevice(_:for:)与supportedComputeStageDevices接口经Apple Doc MCP和当前SDK核实；隔离CPU设备选择实验同样第二张失败（vision-cpu-stage15.log），没有把此无效设备切换写入产品。继续独立autoreleasepool生命周期实验，保留原始识别要求。

第十六批实施合同：独立autoreleasepool实验仍第二张e5rtError；改用macOS15起的Swift RecognizeTextRequest对相同两张原件连续请求成功（14.803s、1.251s，各1个结果，vision-modern-stage16.log）。官方Apple Doc MCP确认其支持Data异步perform，工程最低macOS15.6满足可用性。替换旧VN请求及手动ImageIO转换，不保留双路径/fallback；语言、精度、取消检查、单消费者与隐私安全错误日志保持。完成条件为构建及原有OCR删除竞争完整风险验证通过，而不是仅独立实验通过。

第十六批证据：build-stage16.log构建通过；risk-stage16.log整套风险验证通过，含连续OCR跨删除、被删除记录不复活、Spotlight实际启动组合、工具并发、分页/刷新竞争、缓存取消与两库原件隔离。新Swift请求替换后本轮回归成立；不由此宣称所有设备的系统引擎问题已根治。运行开发版仍为stage9，尚需安全同步及最终原生交互证据核对。

第十七批验证合同：运行stage9进程34697仍在，但CUA绑定、快捷键均报noWindowsAvailable，不能据此安全正常退出；本批不强杀或覆盖其可执行文件。扩展既有原生教程生命周期验证，串起真实示例模型、延迟左右引导、原生预览/编辑/保存与分类，不新增生产专用开关。隔离writer与UserDefaults不变，验证事件来源明确区分产品命令和真实物理输入；剩余运行版本同步仍单独记录。

第十七批依赖合同：实际TracingService只使用HTTP exporter/API/SDK；全生产及Tests没有gRPC exporter和OpenTracing shim调用。当前解析的官方包manifest确认HTTP target独立，不依赖这两个product。移除工程直接链接的OpenTelemetryProtocolExporter（gRPC）及OpenTracingShim-experimental，保留实际HTTP跟踪和其传递依赖。完成条件是工程一致性、合并构建和可执行依赖核对；不宣称仅凭少两个product就得到运行帧率提升。现有三个非Sendable持有诊断属于已知Swift5边界，未用unchecked Sendable消音，不将本轮扩为全工程Swift6迁移。

第十七批证据：tutorial-lifecycle-stage17.log通过真实原生教程预览→编辑→保存新示例→关闭→分类→隐藏/恢复/关闭，保存回调刷新示例并保留原文，外部写入与粘贴均0；驱动来自产品命令，不冒充物理长按/触控板。build-stage17.log通过；otool确认新的dylib无OpenTracing动态依赖，工程不再引用两项闲置product。最低应用部署15.6、Swift5配置保持；测试target配置不机械同步为产品版本。

交付暂存：out/2026-10-08-project-refactor/delivery/SenseFlow.app由stage17完整构建复制，移除构建目录绝对rpath、本地签名并通过codesign --verify --deep --strict。尚未启动这份包，不能宣称运行验收；旧开发进程34697仍运行，CUA无法取得可操作窗口，未强杀、未覆盖旧应用、未改变真实数据。V仍未完成：正常退出/安全替换与实际主程序交互是最后待办，而非OCR回归（已通过）或依赖构建问题。

第十八批回归修复合同：已正常退出stage9进程并保存完整旧包SenseFlow-before-stage17.app；stage17启动PID39799、dylib SHA256与交付包一致，实际图片筛选与缩略图显示通过。用户报告禁止触控板纵向翻页后鼠标纵向滚轮也失效。现有代码把hasPreciseScrollingDeltas当作触控板身份，导致无手势phase的高精度鼠标滚轮被吞；Apple文档只保证此字段表示delta精度。改为仅消费具有原生gesture/momentum阶段的precise纵向事件，其余纵向滚轮映射横向：像素保留1:1、行单位按24pt。新增真实窗口派发的像素纵向与带phase纵向对照断言，保留既有普通滚轮/横向/回弹验证；构建与focused scroll验证后安全同步。

第十八批追加范围（用户即时指定）：经典/起伏保持设置中的两个独立选项，停止按滚动状态临时启用/回落起伏。起伏始终由鼠标位置与所选模式决定；删除每次滚动重建的waveSettleTask和其影子强度状态，同步设置说明。减少动态任务不作为无测量的性能结论；与滚轮分流合并构建及原生验证。

第十八批证据：build-stage18.log通过。scroll-stage18.log原生NSPanel派发通过普通纵向滚轮72pt、高精度横向17pt、无phase高精度纵向48pt、带phase纵向不移动历史、边缘回弹/末卡可达及分页追加。编译验证发现DocumentWorkflowVerification仍调用已移除CGImage OCR重载，改为实际PNG Data入口并保留空结果/失败断言；这是验证调用点同步，未重建生产旧入口。超大合成80×1600行输入的峰值不作为正常回弹视觉证明。

开发版39799正常Command-Q退出后，保存完整stage17至SenseFlow-before-stage18.app；stage18去绝对构建rpath、签名核验后安装并启动PID40704。CUA实际读出搜索/类别/原历史界面，无新授权请求；后续滚轮动作因用户正在改变应用状态被CUA拒绝，不伪称此物理输入已验收。用户可直接体验目前已启动的修复版，完整重构目标仍保留最终交互/证据审查。

第十九批诊断合同：用户实机仍不能滚动，stage18合成派发不足以覆盖实际输入；不宣布已修复。完整文档验证document-stage18-full.log在关闭后再次预览超时（178行），未通过且保留断言，可能受实际焦点/原生事件影响，尚无根因证据。为实际Debug窗口增加最多40次不含内容/路径的滚轮诊断，记录window派发、路由命中、delta/phase与offset，替换版后采集用户滚轮事件；定位后删除临时诊断，不靠增加无证据fallback覆盖问题。

第十九批实机证据：wheel-input-stage19.log在PID41430真实窗口记录Route hit=true、enabled=true、associated=true、router=true，用户滚轮含precise=true/phase=4，纵向delta持续13–19；因此stage18用phase判断设备仍会吞掉这条输入。CUA固定窗口后的普通scroll能使卡片移动，只证明其事件链正常，不能代表用户事件。利用已有选定触控板的双指接触信号区分真实触控板，保持纵向触控板惯性所属手势到结束；鼠标即便携带phase也正常映射。物理传感器不引入新权限/事件拦截；验证通过注入接触状态对照同一个phased事件，随后删除临时日志。

第十九批最终证据：build-stage19-final.log与scroll-stage19.log通过。相同phased precise事件在无物理接触时移动48pt，有双指接触时不移动，双指抬起后的纵向惯性仍不翻页；普通/高精度横向、回弹、末卡和分页均通过。传感器已有锁内只存Bool，停止/重新配置清空；无逐帧Task。临时Debug诊断代码全部删除，日志流正常停止。正常退出诊断版后保存完整旧包至SenseFlow-before-stage19-final.app，新版PID41916启动，CUA实际加载原历史和类别界面；还未获得用户此次实机滚轮确认，不把此前失败反馈抹掉。文档再次打开超时仍为独立待查项，整体目标不标完成。

第二十批验证证据：保留关闭后再次打开断言，增加仅失败时输出会话加载、窗口动画、可见性和错误状态的诊断，未修改生产预览逻辑、未延长等待。document-stage20.log完整原生回归通过：首次/再次打开、替换预览、编辑草稿恢复、滚动收起、背景点击、原文保护和OCR错误恢复。stage18超时未复现，不能由一次通过推断根因或宣称修复；保留历史失败记录。验证进程现已退出，未访问用户真实历史。用户物理滚轮确认和最终交付审查仍待完成，V保持未勾选。

用户实机确认：第二十批之后用户明确反馈“现在好了啊”，确认当前stage19-final运行版鼠标滚轮可以翻看卡片。该证据补足此前合成事件无法证明的实际输入行为；与触控板接触分流断言共同支持滚轮回归验收。整体最终审查与交付核对继续，不由此直接完成全目标。

第二十一批交互合同：用户确认起伏在进入背景时突然抬升，要求仅进入矩形边界才启动。现有ScrollView连续hover只记录X，在背景纵向留白也产生全强度波峰。改为由现有原生卡片命中通知激活波峰，离开卡片/进入间隙归零，仍用鼠标X定位邻卡起伏；强度变化沿用统一选中反馈缓动。经典/起伏仍独立，不修改滚轮路由、长按或预览。验证需构建和实际背景→卡片→间隙运行检查，不能仅凭代码完成。最终包已另存delivery-stage19-final，签名与当前运行dylib SHA256一致，旧delivery保留。

第二十一批证据：build-stage21.log通过，git diff --check通过。卡片现有NSTrackingArea边界通知控制hoveredCardID，离开事件仅清除自身ID，避免旧卡离开清除新卡；波峰强度按SelectionFeedback.duration缓动，无新增后台任务、SQL或解码。正常Command-Q退出旧进程后核对进程不存在，备份SenseFlow-before-stage21.app，再签名验证安装；新版PID46196启动并由CUA读到实际搜索/分类/历史窗口。首次CUA启动观察超时后只检查同一进程并重新绑定，没有重复启动。CUA现有接口没有纯鼠标移动/hover操作，尚不能提供实际背景→卡片→间隙轨迹的视觉验收；不将启动成功作为动效验收。整体目标保持active。

第二十二批故障合同：用户报告录屏长按只闪一下随后历史消失。现有SwiftUI quickLookURL已设置，但FloatingWindowManager只认可注册的历史/文档窗口，系统Quick Look接管key时可能被内部失焦自动隐藏。修复内部预览会话保持历史：同应用且Quick Look绑定非空时不自动隐藏；主动收起历史清空绑定，外部应用切换仍正常收起。不永久固定窗口、不拦截系统窗口。另document-stage21.log再次重现关闭后再打开失败，诊断source/loading/transition/visible均false，无加载错误；仍保留断言待定位，不宣称完整回归通过。

第二十二批构建/运行证据：build-stage22.log通过，旧版正常退出后保存SenseFlow-before-stage22.app，新包签名验证并启动PID48126。CUA选择真实录屏分类，索引及坐标右键长按后历史保持可见，但AX及截图未观察到Quick Look窗口，因此仅证明当前观察未发生历史消失，不证明录屏预览已验收；继续定位按压触发与呈现链。未修改用户录屏原件、未粘贴或触发播放。

第二十三批诊断证据：检查既有capture-stage7验证发现其使用普通titled NSWindow且主动激活，与生产borderless/nonactivating面板不一致。隔离VerifyCapturePanel.swift仅将窗口替换为生产KeyboardAcceptingPanel样式并去掉主动激活，使用当前模块及隔离示例原件，capture-panel-stage23.log通过系统QLPreviewPanel实际可见断言、文件原件/去重/筛选/缩略图校验。这排除“这种面板不能呈现Quick Look”的假设，但没有覆盖FloatingWindowManager自动隐藏和物理长按链；不修改生产逻辑伪造根因。下一步应对真实长按入口与quickLookURL时序进行有界诊断，最终回归仍未完成。

第二十四批诊断合同：为录屏长按真实链添加Debug有界日志（最多12次入口），只输出入口、详情类型、绑定状态与错误类别，不含内容/路径/ID。记录完成后删除诊断，不保留生产调试UI。与现有窗口自动隐藏判断一起核对，不根据CUA长按无变化直接猜根因。

第二十四批运行证据：build-stage24.log通过，正常退出stage22后保留SenseFlow-before-stage24.app，诊断版PID50350启动。CUA实际分类后索引右键保持1500ms，AX无变化且recording-stage24.log无入口日志，不能证明生产长按故障根因；请求用户物理长按补齐事件证据，不把自动化动作当作实机输入。另代码审查发现pointerLeft在加载候选尚未成为source时取消请求，此项可能关联再打开超时但尚无调用证据，不能直接删除取消保护。当前临时诊断代码未提交，定位后删除。

第二十五批取消合同：当前产品hover只反馈、长按阈值提交预览，pointerLeft仍会取消候选加载，属于旧hover预览生命周期残留。移除离开原卡对已接受长按请求的取消；离开只清hover身份。保留新意图、滚动、隐藏和关闭取消，防止旧请求覆盖新请求。现有文档再次打开回归重跑，并加入加载过程中离开原卡仍完成预览断言；不将此作为录屏Quick Look根因声明。

第二十五批证据：build-stage25.log与document-stage25.log完整原生回归通过。首次请求后立即pointerLeft仍成功呈现，关闭再次打开、替换、原文/草稿、连续滚动与OCR错误断言保持。仅一次通过不足以宣称间歇故障根因已证实。生产pointerLeft移除旧候选取消，所有显式取消入口保持；当前运行仍为stage24诊断版，stage25未部署，临时录屏诊断仍待删除。
