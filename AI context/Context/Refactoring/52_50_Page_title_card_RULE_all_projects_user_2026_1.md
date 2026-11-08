Part of [Refactoring.md](../Refactoring.md) (split 2026-11-06).

## 50. Page title = card (⚠️ RULE, all projects, user 2026-11-05)

The page title in the header is a **new card** (`cardVisual`), not a textbox: value = `'Calendar'[Dates Selected Short]`
(selected date range, He / En), label = `[Page Title …]` measure (He / En by the language switcher) shown **above** the
value. Formatting = ClientF `Sales Channels` (`ChannelMix\cardVisual3`, the example): label Calibri 22 bold `#025687`,
`Heading2`, `matchValueAlignment`; value Calibri 14 centred; fill `[Light]` off, no border / outline / divider / shadow,
padding 0, card title off (its text = the same measure), visual header off. Centred on the old textbox, header height
(1280 page: y 0, height 60). Script `ClientC\Sales New\Refactoring\Step50_PageTitleCard.py` (copies the example card,
adds both measures); all pages: `Step50_PageTitleCards_All.py` (He = the textbox text, En = `headers_en` of
`ReportMap_config.json`; empty header textboxes without a background are deleted). ClientC `Sales NEW` 2026-11-05: 41
pages (40 + `ניתוח עולם המכירות` (Sales analysis)), 11 empty header textboxes deleted; backup `PageTitleCards_2026-11-05_212809`.
