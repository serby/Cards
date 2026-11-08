# Arabic (ar)

**Register.** Modern Standard Arabic as in Apple's Arabic iOS. Address the user in the masculine singular, as Apple does: أنت، اكتب، امسح. Buttons and menu items are verbal nouns (إضافة، حفظ، حذف، تحرير، استيراد، بحث). Titles are noun phrases with no title case. VoiceOver hints use the present tense, third person (يفتح البطاقة للتحرير، يحفظ البطاقة). Announcements use تم/تمت plus a verbal noun, matching its gender (تمت إضافة، تم حذف، تم نقل).

**Apple terms.** الإعدادات، شاشة القفل، خدمات الموقع، الإشعارات، الكاميرا، تحرير، تم (Done)، إلغاء، حذف، مشاركة، تصدير، استيراد، لصق، الحافظة، حسنًا (OK, never موافق)، تشغيل/إيقاف، جارٍ التحميل، رمز QR، الرمز البريدي.

**Glossary.** card بطاقة (loyalty card بطاقة ولاء); barcode الرمز الشريطي (every format); code الرمز; barcode type نوع الرمز الشريطي; scan مسح … ضوئيًا; location موقع in titles and buttons, place مكان in sentences; map pin دبوس; Brightness Boost تعزيز السطوع; radius نصف القطر; colour اللون. Colours: أحمر، برتقالي، أصفر، أخضر، أزرق مخضر، أزرق، نيلي، أرجواني، وردي، بني، جرافيت، افتراضي.

**Punctuation.** Use the Arabic comma ، semicolon ؛ and question mark ؟. Quote with « » in logical order: «%@». Full sentences, permission prompts included, end with a full stop. Keep placeholders in logical order and add no direction marks. Give a distance as على بُعد %1$@ من %2$@, because "X من Y" can read as "X of Y".

**Plurals.** one and two always mean exactly 1 and 2, so write the number as a word and leave out %lld: بطاقة واحدة, and the dual بطاقتين (بطاقتان when it is the subject). Every other form keeps %lld. zero, many (11–99) and other (100+, 101, 102): singular, as in %lld بطاقة. few (3–10): plural, as in %lld بطاقات. Never use the plural outside few. Zero keeps %lld and the whole sentence, never a negative لم … أي, even where the comment says the count is never 0. In many, a masculine noun takes the accusative with tanween: %lld مكانًا، %lld رمزًا شريطيًا.

**Pitfalls.**
- مسح on its own means erase or clear on iOS (مسح كل المحتوى). Always write ضوئيًا with scanning.
- مثبّت means pinned to the top, not dropped on a map.
- In "Scanned %1$@ code", %1$@ is a localised format name that may already be رمز QR, so don't put رمز in front of it.
- A title that asks a question is هل تريد …؟ (هل تريد إضافة البطاقة؟), never a verbal noun with ؟.
- A setting or screen named in a sentence goes in «»; a Settings path with > is not quoted.
- مكان is only a saved place, never "where" in general: the Maps menu picks an app, التطبيق.
- Upload to iCloud is تحميل إلى iCloud, always with إلى, because Apple uses تنزيل for download.
- What's New labels are nouns: جديد، تحسين، إصلاح.
- No two colour names may be synonyms, or VoiceOver users cannot tell them apart: Pink is وردي, Rose وردي فاتح.
- A key that is both an icon name and a picker heading takes the article, as the headings do (الصيدلية، الحيوانات الأليفة).
- Leave Card Barcodes, JSON, iPhone, iCloud, VoiceOver and the barcode format names in Latin script.
