# WFC 中文简介

<!-- badges: start -->
[![Project Status: WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![R >= 3.5.0](https://img.shields.io/badge/R-%3E%3D%203.5.0-blue.svg)](https://cran.r-project.org/)
<!-- badges: end -->

[English](README.md) | **简体中文**

`WFC` 是一个面向工作流的 R 包，用于调查数据的加权与迭代比例拟合（raking）。
它强调一条严谨的 **预检查 → 执行 → 诊断** 流水线，用于多来源调查校准；采用与数据结构
无关（schema-agnostic）的维度定义和规范化的目标对象，使 raking 与事后分层（post-stratification）
两个引擎共享一致的接口契约。

> 说明：本项目的代码、测试、英文文档与配置一律使用英文；本文件是仓库中唯一的中文说明文件。

## 为什么用 WFC

多数加权脚本会“悄无声息”地出错：某个类别在目标中缺失、某个单元格样本太少无法估计，
或修剪（trimming）后组内总量发生漂移。`WFC` 把这些失败模式变成一等公民、可复核的步骤。

- **先预检查，再校准。** `wf_precheck()` 在计算任何权重之前，比对样本与目标并报告不兼容之处。
- **一套目标契约，多种数据来源。** 可从外部总体数据、加权参考样本或手工边际表构建规范化的 `wf_target`。
- **可复核的类别合并。** 事先声明合并阶梯（collapse ladder），依据预检查结果得到建议的合并方案，
  并一致地应用到样本与目标上。
- **raking 与事后分层共用一个调度器。** 无论使用哪种方法，`wf_calibrate()` 都返回同样的 `wf_weights` 契约。
- **把诊断变成习惯。** `wf_diagnose()` 以权重与边际诊断为每条工作流收尾。

## 安装

从 GitHub 安装开发版：

```r
# install.packages("remotes")
remotes::install_github("makunxiang-cmd/WFC")
```

或从源码压缩包安装：

```r
install.packages("WFC_0.9.0.tar.gz", repos = NULL, type = "source")
```

## 工作流概览

```
声明维度 ──► 构建目标 ──► 预检查 ──► （合并类别）──► 校准 ──► 诊断
 wf_dims()   wf_target_*()  wf_precheck()  wf_suggest_    wf_rake() /   wf_diagnose()
                                           collapse()     wf_poststrat()
                                           wf_apply_      wf_calibrate()
                                           collapse()
```

## 快速上手

```r
library(WFC)

data(wfc_example)

dims <- wfc_example$dims
target <- wf_target_population(
  pop = wfc_example$population,
  key_map = c(gender = "gender", age = "age"),
  count = "count",
  dims = dims,
  by = "province"
)

precheck <- wf_precheck(wfc_example$sample, target, id = "id")
precheck

weights <- wf_rake(wfc_example$sample, target, id = "id")
wf_diagnose(weights, target = target)
```

## 事后分层（Post-stratification）

事后分层使用联合总体单元格，而非边际总量。构建目标时设置 `keep_joint = TRUE`，
声明一个可复核的合并阶梯，然后规划并执行单元格级校准。

```r
target_joint <- wf_target_population(
  pop = wfc_example$population,
  key_map = c(gender = "gender", age = "age"),
  count = "count",
  dims = dims,
  by = "province",
  keep_joint = TRUE
)

ladder <- wf_collapse_ladder(
  dims,
  level1 = list(age = c(young = "all", old = "all"))
)

plan <- wf_plan_poststrat(
  wfc_example$sample,
  target_joint,
  min_cell = 2,
  ladder = ladder
)
plan

post <- wf_poststrat(
  wfc_example$sample,
  target_joint,
  min_cell = 2,
  ladder = ladder,
  id = "id"
)
wf_diagnose(post)
```

## 基础 API（Foundation API）

手工边际表可直接转换为目标，并通过统一调度器进行校准。也可以在校准前把目标向参考目标收缩。

```r
manual <- data.frame(
  dimension = c("gender", "gender", "age", "age"),
  category = c("female", "male", "young", "old"),
  value = c(55, 45, 60, 40)
)

target_manual <- wf_target_manual(manual, dims)
weights_manual <- wf_calibrate(
  wfc_example$sample,
  target_manual,
  method = "raking",
  id = "id"
)
wf_diagnose(weights_manual)
```

## 函数速查

| 阶段 | 函数 | 用途 |
| --- | --- | --- |
| 维度 | `wf_dims()` | 声明校准维度及可选的合并阶梯。 |
| 目标 | `wf_target_population()` | 从外部总体数据构建规范化目标。 |
| 目标 | `wf_target_reference()` | 从加权参考样本构建目标。 |
| 目标 | `wf_target_manual()` | 从手工长格式边际表构建目标。 |
| 目标 | `wf_target_shrink()` | 将目标向参考目标收缩。 |
| 预检查 | `wf_precheck()` | 校准前检查样本与目标的兼容性。 |
| 合并 | `wf_collapse_ladder()` | 声明事后分层的合并阶梯。 |
| 合并 | `wf_suggest_collapse()` | 依据预检查结果给出合并建议。 |
| 合并 | `wf_apply_collapse()` | 将合并方案应用到样本与目标。 |
| 校准 | `wf_calibrate()` | 调度到具体校准方法（raking、事后分层、greg、logit）。 |
| 校准 | `wf_rake()` | 分组 raking（迭代比例拟合）。 |
| 校准 | `wf_plan_poststrat()` | 规划事后分层的单元格解析。 |
| 校准 | `wf_poststrat()` | 执行单元格级事后分层。 |
| 组合 | `wf_compose()` | 将多个加权阶段相乘为一个可审计结果。 |
| 融合 | `wf_blend()` | 在估计量层面融合线上与线下两个来源。 |
| 倾向 | `wf_target_propensity()` | 将线上样本与概率参考样本堆叠为成员模型规格。 |
| 倾向 | `wf_propensity()` | 产出逆倾向伪设计权重，附重叠与平衡诊断。 |
| 方差 | `wf_replicates()` | 生成重新校准的 bootstrap/jackknife/BRR 重复权重。 |
| 方差 | `wf_variance()` | 将重复权重与估计量组合为估计值、标准误与置信区间。 |
| 诊断 | `wf_diagnose()` | 诊断校准后的权重与边际。 |

所有导出函数均带有完整文档。在 R 中可用 `?wf_rake`、`help(package = "WFC")`
或 `example(wf_target_population)` 查看。

## 数据政策

`private-data/` 下的私有源电子表格和 RData 文件**不会提交**到仓库，也**不会**随 R 包发布。
所有示例与测试仅使用由 `data-raw/make-wfc-example.R` 生成的模拟数据集 `wfc_example`。

## 项目状态

0.x 阶段的原始设计范围已全部实现：raking、事后分层、手工目标与目标收缩、合并规划、
权重组合、双源融合、倾向得分校正、重复权重方差以及有界（GREG/logit）校准。
因 CRAN 上存在同名包，本包已于 0.9.0 从 `weightflow` 更名为 `WFC`。完整变更见
[`NEWS.md`](NEWS.md)。

设计文档位于 [`inst/design/`](inst/design/)（英文），其中
[`wfc_future_design.md`](inst/design/wfc_future_design.md) 为 0.10 → 1.0 的未来路线
（引导式工作流、生态桥接、生产基础设施、软校准等），对应的参考原型实现位于
[`inst/reference/`](inst/reference/)。

## 参与贡献

欢迎贡献。请先阅读 [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) 了解开发环境、
测试驱动流程与语言政策，并在提交 issue 或 pull request 前阅读
[行为准则](.github/CODE_OF_CONDUCT.md)。面向自动化 agent 的仓库约定见 [`AGENTS.md`](AGENTS.md)。

## 许可证

基于 [MIT 许可证](LICENSE.md) 发布。© 2026 makunxiang-cmd 与 WFC 贡献者。
