# Japanese (ja) style guide

## Register

- Buttons, titles, labels and headings: noun phrases or Apple's dictionary-form verbs, no です/ます: 追加, 編集, 保存, 削除, キャンセル, カードを追加, すべてのカードを削除, 書き出す, 読み込む.
- Messages, hints and permission prompts: です/ます. Errors end ません/ませんでした. VoiceOver hints describe the result: カードを保存します. Announcements are past tense: %@を削除しました, 明るさブーストをオンにしました.
- No exclamation marks, no しましょう, no katakana marketing words.

## Apple terms

設定, ロック画面, 通知, カメラ, 位置情報, 位置情報サービス (the phone setting only), マップ, 編集, 完了, キャンセル, 削除, 書き出す (Export), 読み込む (Import), 読み込み中 (Loading), ペースト, クリップボード, オン/オフ, OK.

## Glossary

- card: カード; loyalty card: ポイントカード; membership card: 会員カード. Counter 枚: %lld枚のカード.
- barcode: バーコード (every format); QR Code: QRコード; barcode type: バーコードの種類.
- code: コード (never 番号 or パスワード).
- scan with the camera: スキャン; the shop's scanner reading the screen: 読み取る.
- location (titles), place (sentences): 場所. "Here" in the list: 現在地. "At %@": %@にいます.
- Brightness Boost: 明るさブースト, everywhere.
- postcode: 郵便番号; radius: 半径 (半径%@, number after).
- colour: カラー; colour names in katakana as Apple's accent colours: ブルー, グラファイト, ティール.

## Typography

- Full-width punctuation: 。、：（）. Colon with no space: 作成者：%@.
- Quotation marks 「」, also around the Settings app in sentences: 「設定」で….
- No spaces between Japanese and Latin text or placeholders: %@を追加しました, Webブラウザ.
- Keep separators that sit between run-time values as they are: %1$@ · %2$@, %1$@ (%2$@).
- Permission prompts: one sentence, 〜ために…を使用します。, with a final 。.

## Pitfalls

- Japanese has only the `other` plural, which must also read for 1: never すべて or 全 next to %lld.
- Reorder positional placeholders when Japanese needs it: %2$@から%1$@.
- Never write units; distances arrive in the placeholder.
- Keep Card Barcodes, JSON, Westway, barcode format names and Apple product names in Latin script.
- Use 作成日時 when the value includes a time.
