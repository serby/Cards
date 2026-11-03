# Simplified Chinese (zh-Hans) style guide

## Register

- Address the user with 你, as Apple's zh-Hans iOS does ("你的位置", "你在 %@"). Never 您.
- Plain everyday Mainland Chinese, no exclamation marks. Prefer everyday words to technical ones (准备好, not 就绪).
- Buttons are verb + noun ("添加卡片"); hints say what happens. Do not repeat 你的 within a sentence.

## Apple terms

设置, 锁定屏幕, 定位服务, 通知, 相机, 编辑, 完成, 取消, 删除, 全部删除, 存储 (Save), 好 (OK), 导出, 导入, 剪贴板, 粘贴, 正在载入, 正在搜索, 大头针, 打开/关闭 for on/off states. Quote app and screen names: 在“设置”中.

## Glossary

- card: 卡片, counted with 张 ("3 张卡片", "这张卡片"); loyalty or membership card in prose: 会员卡.
- barcode: 条形码, for every format; QR Code: 二维码; other format names stay in English.
- code: 卡号, everywhere (labels, placeholders, hints, announcements). Never 代码 or 号码.
- barcode type: 条形码类型. scan: 扫描.
- location (titles, buttons): 位置; place (sentences): 地点. Pinned location: 标记的位置.
- Brightness Boost: 亮度增强; announcements 亮度增强已打开/已关闭.
- postcode: 邮政编码; radius: 半径 ("半径 %@").
- Colours: 红色, 橙色, 黄色, 绿色, 深青色 (Teal), 蓝色, 靛蓝色, 紫色, 粉色, 棕色, 石墨色, 默认.

## Patterns

- Being at a place: "你在 %@"; arrival notification "你已到达 %@。"
- Distance: "距 %2$@ %1$@". Announcements start with 已: "已添加 %@", "已删除 %@".
- Errors: 无法…; not found: 未找到…; empty list: 暂无….

## Typography

- Full-width punctuation in Chinese text: ，。：？“”. Quotes are “ ” (U+201C/U+201D), with no space inside or around them.
- One half-width space between Chinese and Latin letters, digits or any placeholder ("导出为 JSON", "创建于 %@", "%lld 张卡片"); none next to full-width punctuation ("卡号：%@", "%1$@，半径 %2$@").
- Half-width brackets for Latin-only content: "%1$@ (%2$@)".
- Sentences (prompts, footers, messages) end with 。; labels, buttons and hints do not.
- Never write units.

## Plurals

zh-Hans needs only "other", which also covers 0 and 1. Avoid 全部/所有 next to the number ("全部 1 张" is wrong): write "删除 %lld 张卡片".
