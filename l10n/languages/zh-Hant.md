# Traditional Chinese (zh-Hant) style guide

Write for Taiwan, as Apple's zh-TW iOS reads. Do not mix in Hong Kong or mainland usage.

## Register

- Address the user as 你, never 您.
- Plain, friendly, short. 請 only in instructions (請在下方輸入代碼). No exclamation marks.
- Titles and buttons are bare verbs or nouns: 加入卡片, 全部刪除, 儲存. VoiceOver hints state the result: 儲存卡片.

## Apple terms

設定 (「設定」 when sending the user there), 鎖定畫面, 定位服務, 通知, 相機, 取用 (允許取用相機), 編輯, 完成, 取消, 刪除, 儲存, 好 (OK), 打開 (open), 開啟 / 關閉 (on / off), 尋找, 載入中, 剪貼板, 大頭針, 郵遞區號, 螢幕, 資料, 產生, 檢視. Import and export are Apple's 輸入 and 輸出 (輸出為 JSON), never 匯入 / 匯出.

## Glossary

- card 卡片, measure word 張 (3 張卡片); loyalty and membership cards 集點卡和會員卡.
- barcode 條碼, every format; barcode type 條碼類型.
- code 代碼; barcode number 條碼號碼.
- scan 掃描.
- Location in titles 位置 (加入位置); place in sentences 地點.
- radius 半徑.
- Brightness Boost 亮度增強 everywhere; announcements 亮度增強已開啟 / 已關閉.
- Colours as Apple names them: 橙色, 藍綠色 (Teal), 靛藍色, 粉紅色, 石墨色, 預設.
- Card Barcodes, JSON, QR Code and barcode format names stay in Latin script.

## Typography

- Full-width punctuation: ，。：「」. Quote user input in 「」.
- A half-width space between Chinese and Latin text, digits or a placeholder (半徑 %@, 已刪除 %@). No space beside full-width punctuation (卡片代碼：%@).
- Half-width brackets in version and build: %1$@ (%2$@).
- Full sentences, permission prompts included, end with 。.

## Pitfalls

- zh-Hant has only `other`, which must also read for 1: no 全部 or 都 before a count.
- No mainland words: 數據, 文件, 攝像頭, 屏幕, 默認, 保存, 加載, 生成.
- 正確的 means "correct"; "the right barcode" is 對應的條碼.
- Never write units; distances arrive through the placeholder.
