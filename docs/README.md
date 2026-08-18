# TTZip 工程文档中心 (Documentation Hub)

> 欢迎查阅 TTZip 工程技术文档库。本目录涵盖了从系统架构设计、底层 C/SIMD 基础设施、开源生态调研、UI/UX 设计系统到全矩阵性能基准与质量审计的完整技术资产。

---

## 目录索引结构

```
docs/
├── PERFORMANCE.md                                 # 【性能白皮书】物理单调时钟吞吐实测与竞品对决
├── competitor_benchmark_report.md                 # 1v1 竞品极限多线程对比分析
│
├── architecture/                                  # 1. 软件架构与工程规范
│   ├── system_overview.md                         # 软件全景架构设计规范 (Swift + C + Vendor)
│   ├── assembly_infrastructure_architecture.md    # 汇编与底层派发表架构 (8 大底层模式)
│   ├── architecture_improvement_plan.md           # 架构演进与全矩阵性能优化规划
│   ├── systemic_engineering_methodology.md        # 系统工程四大铁律与方法论
│   ├── libarchive_engineering_excellence.md       # C 桥接与 libarchive 优化规范
│   ├── libarchive_testing_oracle_philosophy.md    # 黄金预言机与测试哲学
│   ├── ai_orchestration_protocol_blueprint.md     # AI 自主协作与流水线协议
│   ├── craftsmanship_engineering_guide.md         # 匠艺工程准则与防腐层
│   ├── repository_organization_guide.md           # 仓库结构治理与工程规范
│   └── development_plan.md                        # 早期开发演进规划归档
│
├── research/                                      # 2. 技术调研与生态对标
│   ├── compression_acceleration_ecosystem.md      # 开源与工业界压缩加速全景调研 (双平台落地清单)
│   ├── apple_silicon_m5_max_isa_audit.md          # Apple Silicon M 系列指令集架构深度审计
│   ├── competitor_analysis.md                     # 竞品功能与架构对比分析
│   └── competitor_performance_analysis.md         # 竞品性能基准差距分析
│
├── design-system/                                 # 3. UI/UX 设计系统
│   └── ttzip_ui_design_system_specification.md    # 禅意金缮与 WSJ 报刊设计系统规范
│
├── audits/                                        # 4. 质量审查与性能审计
│   ├── comprehensive_systemic_audit_report.md     # 综合系统审计报告
│   ├── performance_sub_1000mbs_audit.md           # 低于 1000MB/s 场景性能归因与专项审计
│   ├── remediation_and_performance_impact.md      # 系统修复与性能影响深度评估
│   └── report_summary.md                          # 历史性能基准与回归总结
│
├── benchmarks/                                    # 5. 性能基准与自动化门禁
│   ├── peak_performance_matrix.json              # 46 项基准全格式历史最优门禁矩阵
│   ├── universal_pre_optimization_baseline.json   # 16 种格式基线性能数据
│   ├── latest_regression_audit.md                 # 自动化性能比对审计报告 (最新)
│   ├── zip_benchmark_matrix_full.json             # ZIP 全维度基准配置
│   ├── zip_benchmark_lagging_config.json          # 滞后场景配置与调优记录
│   └── benchmark_report_*.json/.md                # 历次自动化跑分数据归档
│
└── test_reports/                                  # 6. CI/CD 与自动化测试报告
    ├── feature_matrix_and_test_report.md          # 16 种格式特性矩阵与测试覆盖报告
    └── local_ci_report.json/.md                   # 本地 CI 自动化执行报告
```

---

## 各分类核心文档导览

### 1. 软件架构与工程规范 (`docs/architecture/`)
- **[系统全景架构设计 (`system_overview.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/architecture/system_overview.md)**：阐述 Swift 6 核心调度层、C 桥接中枢、硬件加速派发表与 100% In-Process C 静态绑定的分层架构。
- **[汇编与底层派发表架构 (`assembly_infrastructure_architecture.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/architecture/assembly_infrastructure_architecture.md)**：8 大底层模式规范，涵盖 `g_ttzip_dispatch` 只读函数指针表、SIMD 硬件加速与 Fast-Path 分发。
- **[系统工程四大铁律 (`systemic_engineering_methodology.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/architecture/systemic_engineering_methodology.md)**：流式第一性 (Stream-First)、纵深防御 (Invariant-First)、确定性确界 (Bounds-First) 与 真实预言机 (Oracle-First)。

### 2. 技术调研与生态对标 (`docs/research/`)
- **[开源压缩加速全景调研 (`compression_acceleration_ecosystem.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/research/compression_acceleration_ecosystem.md)**：系统性梳理 `libdeflate`、`fast-lzma2`、`zlib-ng`、`zstd` 等 20+ 个高性能开源库，深入分析 macOS/Windows 双平台收益、代码对口点与商业许可证合规边界。
- **[Apple Silicon 指令集审计 (`apple_silicon_m5_max_isa_audit.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/research/apple_silicon_m5_max_isa_audit.md)**：分析 ARM64 NEON、PMULL、CRC32、SVE2 及 Apple Silicon 微架构缓存特性对压缩吞吐的加持。

### 3. UI/UX 设计系统 (`docs/design-system/`)
- **[TTZip UI 设计系统规范 (`ttzip_ui_design_system_specification.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/design-system/ttzip_ui_design_system_specification.md)**：融合“侘寂禅意 (Wabi-Sabi)”、“金缮裂纹 (Kintsugi Gold)”与“WSJ 报刊排版”的 macOS 原生桌面界面设计语言规范。

### 4. 质量审查与性能审计 (`docs/audits/`)
- **[低于 1000MB/s 性能专项归因 (`performance_sub_1000mbs_audit.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/audits/performance_sub_1000mbs_audit.md)**：定位慢速格式（如 LRZIP、LZIP、Brotli）的瓶颈根因，并给出修复前后的物理跑分明细。
- **[系统修复与性能影响评估 (`remediation_and_performance_impact.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/audits/remediation_and_performance_impact.md)**：代码审计整改记录与端到端吞吐收益量化报告。

### 5. 性能基准与自动化门禁 (`docs/benchmarks/`)
- **[全格式最优门禁矩阵 (`peak_performance_matrix.json`)](file:///Users/kevintung/Documents/dev/TTZip/docs/benchmarks/peak_performance_matrix.json)**：固化全格式 46 项基准测试（覆盖 16 种格式、262 个细分维度）的历史最高纪录，作为 CI/CD 零性能倒退阻断门禁。
- **[最新自动化回归对比 (`latest_regression_audit.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/benchmarks/latest_regression_audit.md)**：通过 `python3 scripts/audit_performance_regression.py` 自动生成的最新吞吐对比报告。

### 6. 测试与 CI 报告 (`docs/test_reports/`)
- **[特性矩阵与测试报告 (`feature_matrix_and_test_report.md`)](file:///Users/kevintung/Documents/dev/TTZip/docs/test_reports/feature_matrix_and_test_report.md)**：归档支持的 16 种格式压缩、解压、穿透浏览与分卷测试覆盖率。
