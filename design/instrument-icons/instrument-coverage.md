# 乐器图标覆盖说明

素材目录：`design/instrument-icons/`。当前收录 **31** 件常见乐器，覆盖 `Instruments.json` 中 54 / 54 件乐器（含复用同一图标的相近乐器）。

图标已接入 `Assets.xcassets`（imageset 名 `instrument_<乐器 ID>`），并在 `Instruments.json` 中填写了对应乐器的 `image` 字段。未修改任何 Swift 代码或 `Localizations.json`。

## 收录的图标

| 文件 | 乐器 | English | 族 | 1x / 2x / 3x | 可复用于 |
| --- | --- | --- | --- | --- | --- |
| [guitar](raster/guitar.png) | 吉他 | Guitar | 吉他 | [1x](png/1x/guitar.png) / [2x](png/2x/guitar.png) / [3x](png/3x/guitar.png) | twelveStringGuitar、tenorGuitar |
| [bass](raster/bass.png) | 贝斯 | Bass | 贝斯 | [1x](png/1x/bass.png) / [2x](png/2x/bass.png) / [3x](png/3x/bass.png) | - |
| [ukulele](raster/ukulele.png) | 尤克里里 | Ukulele | 尤克里里 | [1x](png/1x/ukulele.png) / [2x](png/2x/ukulele.png) / [3x](png/3x/ukulele.png) | - |
| [banjo](raster/banjo.png) | 班卓琴 | Banjo | 班卓 | [1x](png/1x/banjo.png) / [2x](png/2x/banjo.png) / [3x](png/3x/banjo.png) | - |
| [mandolin](raster/mandolin.png) | 曼陀林 | Mandolin | 曼陀林 | [1x](png/1x/mandolin.png) / [2x](png/2x/mandolin.png) / [3x](png/3x/mandolin.png) | mandola、mandocello |
| [resonator-guitar](raster/resonator-guitar.png) | 多布罗琴 | Dobro | 吉他 | [1x](png/1x/resonator-guitar.png) / [2x](png/2x/resonator-guitar.png) / [3x](png/3x/resonator-guitar.png) | - |
| [violin](raster/violin.png) | 小提琴 | Violin | 西方弓弦 | [1x](png/1x/violin.png) / [2x](png/2x/violin.png) / [3x](png/3x/violin.png) | hardangerFiddle |
| [viola](raster/viola.png) | 中提琴 | Viola | 西方弓弦 | [1x](png/1x/viola.png) / [2x](png/2x/viola.png) / [3x](png/3x/viola.png) | - |
| [cello](raster/cello.png) | 大提琴 | Cello | 西方弓弦 | [1x](png/1x/cello.png) / [2x](png/2x/cello.png) / [3x](png/3x/cello.png) | - |
| [double-bass](raster/double-bass.png) | 低音提琴 | Double Bass | 西方弓弦 | [1x](png/1x/double-bass.png) / [2x](png/2x/double-bass.png) / [3x](png/3x/double-bass.png) | - |
| [erhu](raster/erhu.png) | 二胡 | Erhu | 中国弓弦 | [1x](png/1x/erhu.png) / [2x](png/2x/erhu.png) / [3x](png/3x/erhu.png) | gaohu、zhonghu、banhu、jinghu |
| [morin-khuur](raster/morin-khuur.png) | 马头琴 | Morin Khuur | 中国弓弦 | [1x](png/1x/morin-khuur.png) / [2x](png/2x/morin-khuur.png) / [3x](png/3x/morin-khuur.png) | - |
| [guzheng](raster/guzheng.png) | 古筝 | Guzheng | 中国弹拨 | [1x](png/1x/guzheng.png) / [2x](png/2x/guzheng.png) / [3x](png/3x/guzheng.png) | qanun、swarmandal |
| [guqin](raster/guqin.png) | 古琴 | Guqin | 中国弹拨 | [1x](png/1x/guqin.png) / [2x](png/2x/guqin.png) / [3x](png/3x/guqin.png) | - |
| [pipa](raster/pipa.png) | 琵琶 | Pipa | 中国弹拨 | [1x](png/1x/pipa.png) / [2x](png/2x/pipa.png) / [3x](png/3x/pipa.png) | liuqin、sanxian、biwa |
| [yangqin](raster/yangqin.png) | 扬琴 | Yangqin | 中国弹拨 | [1x](png/1x/yangqin.png) / [2x](png/2x/yangqin.png) / [3x](png/3x/yangqin.png) | - |
| [ruan](raster/ruan.png) | 阮 | Ruan | 中国弹拨 | [1x](png/1x/ruan.png) / [2x](png/2x/ruan.png) / [3x](png/3x/ruan.png) | yueqin |
| [oud](raster/oud.png) | 乌德琴 | Oud | 中东西亚 | [1x](png/1x/oud.png) / [2x](png/2x/oud.png) / [3x](png/3x/oud.png) | bouzouki、domra |
| [balalaika](raster/balalaika.png) | 巴拉莱卡琴 | Balalaika | 中东西亚 | [1x](png/1x/balalaika.png) / [2x](png/2x/balalaika.png) / [3x](png/3x/balalaika.png) | - |
| [sitar](raster/sitar.png) | 锡塔尔琴 | Sitar | 南亚 | [1x](png/1x/sitar.png) / [2x](png/2x/sitar.png) / [3x](png/3x/sitar.png) | tanpura、sarod、veena |
| [shamisen](raster/shamisen.png) | 三味线 | Shamisen | 日韩 | [1x](png/1x/shamisen.png) / [2x](png/2x/shamisen.png) / [3x](png/3x/shamisen.png) | - |
| [koto](raster/koto.png) | 日本筝 | Koto | 日韩 | [1x](png/1x/koto.png) / [2x](png/2x/koto.png) / [3x](png/3x/koto.png) | zither |
| [gayageum](raster/gayageum.png) | 伽倻琴 | Gayageum | 日韩 | [1x](png/1x/gayageum.png) / [2x](png/2x/gayageum.png) / [3x](png/3x/gayageum.png) | geomungo |
| [kora](raster/kora.png) | 科拉琴 | Kora | 其他传统 | [1x](png/1x/kora.png) / [2x](png/2x/kora.png) / [3x](png/3x/kora.png) | ngoni |
| [nyckelharpa](raster/nyckelharpa.png) | 尼克尔哈帕琴 | Nyckelharpa | 中东西亚 | [1x](png/1x/nyckelharpa.png) / [2x](png/2x/nyckelharpa.png) / [3x](png/3x/nyckelharpa.png) | - |
| [ektara](raster/ektara.png) | 埃克塔拉琴 | Ektara | 南亚 | [1x](png/1x/ektara.png) / [2x](png/2x/ektara.png) / [3x](png/3x/ektara.png) | - |
| [dotara](raster/dotara.png) | 多塔拉琴 | Dotara | 南亚 | [1x](png/1x/dotara.png) / [2x](png/2x/dotara.png) / [3x](png/3x/dotara.png) | - |
| [sarangi](raster/sarangi.png) | 萨兰吉琴 | Sarangi | 南亚 | [1x](png/1x/sarangi.png) / [2x](png/2x/sarangi.png) / [3x](png/3x/sarangi.png) | - |
| [kantele](raster/kantele.png) | 坎特勒琴 | Kantele | 其他传统 | [1x](png/1x/kantele.png) / [2x](png/2x/kantele.png) / [3x](png/3x/kantele.png) | - |
| [gusli](raster/gusli.png) | 古斯里琴 | Gusli | 其他传统 | [1x](png/1x/gusli.png) / [2x](png/2x/gusli.png) / [3x](png/3x/gusli.png) | - |
| [bandura](raster/bandura.png) | 班杜拉琴 | Bandura | 其他传统 | [1x](png/1x/bandura.png) / [2x](png/2x/bandura.png) / [3x](png/3x/bandura.png) | - |

## 全部乐器清单与覆盖状态

按 `Instruments.json` 中的族顺序与乐器顺序排列。

| 族 | 乐器 ID | 中文名 | English | 状态 | 图标 |
| --- | --- | --- | --- | --- | --- |
| 吉他 | `guitar` | 吉他 | Guitar | 专属图标 | [guitar](tiles/guitar.png) |
| 吉他 | `twelveStringGuitar` | 十二弦吉他 | 12-String Guitar | 复用 | guitar（吉他） |
| 吉他 | `tenorGuitar` | 四弦吉他 | Tenor Guitar | 复用 | guitar（吉他） |
| 吉他 | `dobro` | 多布罗琴 | Dobro | 专属图标 | [resonator-guitar](tiles/resonator-guitar.png) |
| 贝斯 | `bass` | 贝斯 | Bass | 专属图标 | [bass](tiles/bass.png) |
| 尤克里里 | `ukulele` | 尤克里里 | Ukulele | 专属图标 | [ukulele](tiles/ukulele.png) |
| 班卓 | `banjo` | 班卓琴 | Banjo | 专属图标 | [banjo](tiles/banjo.png) |
| 曼陀林 | `mandolin` | 曼陀林 | Mandolin | 专属图标 | [mandolin](tiles/mandolin.png) |
| 曼陀林 | `mandola` | 曼陀拉琴 | Mandola | 复用 | mandolin（曼陀林） |
| 曼陀林 | `mandocello` | 曼陀琴 | Mandocello | 复用 | mandolin（曼陀林） |
| 西方弓弦 | `violin` | 小提琴 | Violin | 专属图标 | [violin](tiles/violin.png) |
| 西方弓弦 | `viola` | 中提琴 | Viola | 专属图标 | [viola](tiles/viola.png) |
| 西方弓弦 | `cello` | 大提琴 | Cello | 专属图标 | [cello](tiles/cello.png) |
| 西方弓弦 | `doubleBass` | 低音提琴 | Double Bass | 专属图标 | [double-bass](tiles/double-bass.png) |
| 中国弓弦 | `erhu` | 二胡 | Erhu | 专属图标 | [erhu](tiles/erhu.png) |
| 中国弓弦 | `gaohu` | 高胡 | Gaohu | 复用 | erhu（二胡） |
| 中国弓弦 | `zhonghu` | 中胡 | Zhonghu | 复用 | erhu（二胡） |
| 中国弓弦 | `banhu` | 板胡 | Banhu | 复用 | erhu（二胡） |
| 中国弓弦 | `jinghu` | 京胡 | Jinghu | 复用 | erhu（二胡） |
| 中国弓弦 | `morinKhuur` | 马头琴 | Morin Khuur | 专属图标 | [morin-khuur](tiles/morin-khuur.png) |
| 中国弹拨 | `guzheng` | 古筝 | Guzheng | 专属图标 | [guzheng](tiles/guzheng.png) |
| 中国弹拨 | `guqin` | 古琴 | Guqin | 专属图标 | [guqin](tiles/guqin.png) |
| 中国弹拨 | `pipa` | 琵琶 | Pipa | 专属图标 | [pipa](tiles/pipa.png) |
| 中国弹拨 | `sanxian` | 三弦 | Sanxian | 复用 | pipa（琵琶） |
| 中国弹拨 | `liuqin` | 柳琴 | Liuqin | 复用 | pipa（琵琶） |
| 中国弹拨 | `ruan` | 阮 | Ruan | 专属图标 | [ruan](tiles/ruan.png) |
| 中国弹拨 | `yueqin` | 月琴 | Yueqin | 复用 | ruan（阮） |
| 中国弹拨 | `yangqin` | 扬琴 | Yangqin | 专属图标 | [yangqin](tiles/yangqin.png) |
| 南亚 | `sitar` | 锡塔尔琴 | Sitar | 专属图标 | [sitar](tiles/sitar.png) |
| 南亚 | `tanpura` | 坦布拉琴 | Tanpura | 复用 | sitar（锡塔尔琴） |
| 南亚 | `sarod` | 萨罗德琴 | Sarod | 复用 | sitar（锡塔尔琴） |
| 南亚 | `veena` | 维纳琴 | Veena | 复用 | sitar（锡塔尔琴） |
| 南亚 | `swarmandal` | 斯瓦尔曼达琴 | Swarmandal | 复用 | guzheng（古筝） |
| 南亚 | `ektara` | 埃克塔拉琴 | Ektara | 专属图标 | [ektara](tiles/ektara.png) |
| 南亚 | `dotara` | 多塔拉琴 | Dotara | 专属图标 | [dotara](tiles/dotara.png) |
| 南亚 | `sarangi` | 萨兰吉琴 | Sarangi | 专属图标 | [sarangi](tiles/sarangi.png) |
| 日韩 | `shamisen` | 三味线 | Shamisen | 专属图标 | [shamisen](tiles/shamisen.png) |
| 日韩 | `koto` | 日本筝 | Koto | 专属图标 | [koto](tiles/koto.png) |
| 日韩 | `biwa` | 日本琵琶 | Biwa | 复用 | pipa（琵琶） |
| 日韩 | `gayageum` | 伽倻琴 | Gayageum | 专属图标 | [gayageum](tiles/gayageum.png) |
| 日韩 | `geomungo` | 玄琴 | Geomungo | 复用 | gayageum（伽倻琴） |
| 中东西亚 | `oud` | 乌德琴 | Oud | 专属图标 | [oud](tiles/oud.png) |
| 中东西亚 | `qanun` | 坎侬琴 | Qanun | 复用 | guzheng（古筝） |
| 中东西亚 | `bouzouki` | 布祖基琴 | Bouzouki | 复用 | oud（乌德琴） |
| 中东西亚 | `balalaika` | 巴拉莱卡琴 | Balalaika | 专属图标 | [balalaika](tiles/balalaika.png) |
| 中东西亚 | `domra` | 多姆拉琴 | Domra | 复用 | oud（乌德琴） |
| 中东西亚 | `zither` | 齐特琴 | Zither | 复用 | koto（日本筝） |
| 中东西亚 | `hardangerFiddle` | 哈当厄尔小提琴 | Hardanger fiddle | 复用 | violin（小提琴） |
| 中东西亚 | `nyckelharpa` | 尼克尔哈帕琴 | Nyckelharpa | 专属图标 | [nyckelharpa](tiles/nyckelharpa.png) |
| 其他传统 | `kora` | 科拉琴 | Kora | 专属图标 | [kora](tiles/kora.png) |
| 其他传统 | `ngoni` | 恩戈尼琴 | Ngoni | 复用 | kora（科拉琴） |
| 其他传统 | `kantele` | 坎特勒琴 | Kantele | 专属图标 | [kantele](tiles/kantele.png) |
| 其他传统 | `gusli` | 古斯里琴 | Gusli | 专属图标 | [gusli](tiles/gusli.png) |
| 其他传统 | `bandura` | 班杜拉琴 | Bandura | 专属图标 | [bandura](tiles/bandura.png) |

## 风格与尺寸

- 画布：640 x 1024（0.625 宽高比，贴近现有 18 x 29 图标槽位），透明背景。
- 输出：1x 320 x 512、2x 640 x 1024、3x 960 x 1536，31 件乐器尺寸完全一致。
- 附加：`tiles/` 为 1024 x 1024 圆角彩色底图标，按乐器族识别色生成，仅用于预览或对外展示，不参与 App 内显示。
- 风格：暖木色写实插画，统一正面视角、统一光源；已去除背景与水印，无文字、无阴影。
- 细节密度按 36 x 36 显示尺寸控制；18 x 29 时古筝、日本筝、伽倻琴、古琴等长条乐器会退化为竖向轮廓，属于该尺寸的物理限制。

## 文件结构

```
design/instrument-icons/
  raster/                 透明背景 640 x 1024 母版（App 实际使用）
  svg/                    早期脚本绘制的矢量备份（31 个）
  png/1x/  png/2x/  png/3x/
  tiles/                  1024 x 1024 彩色圆角底图标
  tools/import_raster_icons.py 去除水印与背景，生成 raster 母版
  tools/build_assets.py   由 raster（或 SVG）生成 PNG 与 tile
  tools/install_assets.py 写入 Assets.xcassets 与 Instruments.json
  tools/make_coverage.py  生成本文档
  tools/preview_small.py  生成真实尺寸预览
  manifest.json           乐器 ID、族色、文件与复用关系
  contact-sheet.png       透明底总览
  contact-sheet-tiles.png 彩色底总览
  preview-actual-size-4x.png 18 x 29 与 36 x 36 实际尺寸预览（4 倍放大）
```

## 重新生成与接入

```bash
/opt/miniconda3/bin/python tools/import_raster_icons.py --source /path/to/源图目录
/opt/miniconda3/bin/python tools/build_assets.py
/opt/miniconda3/bin/python tools/install_assets.py
/opt/miniconda3/bin/python tools/preview_small.py
/opt/miniconda3/bin/python tools/make_coverage.py
```

`build_assets.py` 优先读取 `raster/<文件名>.png`；该文件不存在时才回退到 `svg/<文件名>.svg` 并用 `rsvg-convert` 渲染。

依赖：`Pillow`、`numpy`、`scipy`；SVG 回退方案另需 `rsvg-convert`。

## 版权

App 内当前使用的图标由用户提供的 AI 生成素材制作，已去除右下角水印并转为透明背景；素材来源与商用授权由提供方确认。`svg/` 为早期脚本绘制的备用版本，未再参与 App 构建。

## 接入状态

1. `Assets.xcassets` 中已创建 31 个 imageset，命名规则 `instrument_<乐器 ID>`，例如 `instrument_erhu`，每个包含 1x / 2x / 3x 三档 PNG。
2. `Instruments.json` 中已有 54 件乐器填写 `image` 字段并指向对应 imageset。
3. 图片缺失时现有代码会自动回退到 `glyph`，后续新增乐器仍可逐件接入。
