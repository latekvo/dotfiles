# Living wordlist — 词汇表 (cíhuìbiǎo)

Small, living record of the Chinese the user is **tracking** — the words being
deliberately reinforced. Each carries a **progress level (0-4)** that controls how much
you explain it. See `SKILL.md` for the method.

**Hard cap: ~10% of any reply is Chinese** (~3-8 items total, most paragraphs zero) — see
`SKILL.md`. English is the working language; this list feeds a light garnish, not a flood.
Most of that budget is *reuse of known words*, not new introductions. **Meta replies** —
about the experiment, the wordlist, or the language itself — widen to ~15% / ~6-12 items
and range further across the vocabulary; the tracked intake stays the same.

**Two dictionaries.** Words are compounds; **characters are the atoms** — the real
force-multiplier. Keep both tables honest: the Words table below, and the Characters (字)
table under it. When a word's characters are all known, stop breaking it out; when a known
character recurs in a new word, flag the payoff.

**Level 4 graduates out of the tables.** A learned word needs no gloss, no parts column,
no notes — only recognition. So the moment a word hits level 4, delete its table row and
append the hanzi to the flat **Learned** list; do the same for a character once every word
it was introduced in is learned. The tables stay small and carry only what still teaches.

Level: **A1** (has studied basics on and off; most content vocabulary is still new).
Tracked-word budget: **~2-4 new per session** (often 0-1 per reply), each entering at
level 0. Pass-through words are rare (each spends against the 10% cap).
Started 2026-07-20 · reset to A1 + progress levels 2026-07-20 · density raised then
**capped at ~10%** (too-heavy was blocking work) 2026-07-21 · character-decomposition
track added 2026-07-21 · level-4 flattened out of the tables 2026-07-28 · user-set re-level
2026-07-30 (完成 → 4 and out; every remaining word +1).

## Progress legend
- **0** brand new — full inline gloss `汉字 (pīnyīn, "meaning")` on FIRST use per message.
- **1** shaky — bare in the text, then a footer reminder at the end of the message.
- **2** getting there — mostly bare, occasional light support.
- **3** almost — no gloss; occasionally TEST recall ("你还记得 X 吗?") instead of telling.
- **4** learned — bare forever, no explanation; lives in the flat list, not the table.

Words move both ways: promote on correct/comfortable use, demote the moment one slips.
A demotion out of level 4 pulls the word back into the table (rebuild its row).

---

> **The tables below are generated.** `counter/state.json` is the source of truth and the
> `chinese-drip-counter` MCP server owns the bookkeeping — call `drip_status` to read levels,
> `drip_record` to log a reply and check it against the density band, `drip_level` to promote
> or demote, `drip_add` to commit a new tracked word. Every mutation rewrites this block, so
> what follows is a current mirror you can read directly, but edit through the tools instead
> of by hand or the next write will overwrite you.

<!-- BEGIN:generated (chinese-drip counter owns this block) -->

## Learned (level 4) — bare, forever

**Words:** 你好 · 好 · 谢谢 · 我 · 你 · 是 · 不 · 完成

**Bricks (字):** 你 · 好 · 女 · 子 · 我 · 是 · 不 · 完 · 成

## Words

| 汉字 | pīnyīn | meaning | lvl | parts (character breakdown) |
|------|--------|---------|:---:|------|
| 发布 | fābù | release / publish | 2 | 发 send out + 布 spread/announce; user-set → lvl 2 2026-07-30 |
| 提交 | tíjiāo | commit (also "submit / hand in") | 2 | 提 raise/carry + 交 hand over; user-set → lvl 2 2026-07-30 |
| 文件 | wénjiàn | file / document | 2 | 文 writing/art + 件 item ← the user's own example; user-set → lvl 2 2026-07-30 |
| 测试 | cèshì | test | 2 | 测 measure + 试 try/attempt; user-set → lvl 2 2026-07-30 |
| 代码 | dàimǎ | code | 1 | 代 substitute + 码 code; 码 = 石 stone + 马 mǎ (phonetic); user-set → lvl 1 2026-07-30, footer reminder next |
| 报错 | bàocuò | (throws) an error | 1 | 报 report + 错 wrong; 错 = 钅 metal + 昔 (phonetic); user-set → lvl 1 2026-07-30, footer reminder next |
| 修复 | xiūfù | fix / repair | 0 | 修 xiū "repair / cultivate" + 复 fù "return / restore / again"; introduced on the android-input select-all read-back fix, draft PR #821 |
| 分支 | fēnzhī | branch | 0 | 分 fēn "divide / split" + 支 zhī "branch / limb"; the surviving feat/screen-recording-server-side branch holding the lost feasibility doc |
| 合并 | hébìng | merge / combine | 0 | 合 hé "join / close / fit" + 并 bìng "combine / side by side"; Introduced on merging origin/main into the recording branch (PR 155). |
| 声音 | shēngyīn | sound | 0 | 声 shēng "sound / voice" + 音 yīn "sound / tone / music"; Introduced on the IEM research - diagnosing why sealing the WH-CH720N cups restores bass detail. |
| 好的 | hǎo de | OK / alright / got it | 0 | 好 hǎo "good" (already learned) + 的 de (particle); promoted after repeated pass-through use opening research answers |
| 检查 | jiǎnchá | check / inspect | 0 | 检 jiǎn "examine / inspect" + 查 chá "investigate / look into"; Introduced on the source audit of the token-economics model; reused when inspecting every rendered PDF page. |
| 运行 | yùnxíng | run (a program, a machine) | 0 | 运 yùn "transport / move" + 行 xíng "go / travel / operate"; introduced on running the newly installed xpra client on the mac |
| 部署 | bùshǔ | deploy | 0 | 部 bù "part / section / ministry" + 署 shǔ "arrange / assign / office"; Introduced on the Vercel deploy CI migration to app-control-bench. |
| 问题 | wèntí | problem / question | 0 | 问 wèn "ask" + 题 tí "topic / problem"; the puzzle-per-day vs puzzle-per-week cadence research |

## Characters (字) — the atoms

The reusable bricks still being taught. Once a brick is known, stop decomposing the
words it appears in and name the payoff instead ("你 already know 码 from 代码").
**R** = often acts as a radical (meaning cue); **P** = often acts as a phonetic (sound cue).

| 字 | pīnyīn | meaning | tags | appears in / notes |
|----|--------|---------|:----:|------|
| 文 | wén | writing / language / art |  | 文件; a base for 文字, 中文, 论文 |
| 件 | jiàn | item / piece |  | 文件; measure word for matters/things |
| 代 | dài | substitute / represent / generation |  | 代码; also 现代 "modern", 时代 "era" |
| 码 | mǎ | code / number |  | 代码 = 石+马; recurs in 号码, 密码 |
| 石 | shí | stone | R | radical in 码 |
| 马 | mǎ | horse | P | **key phonetic:** 码 mǎ, 妈 mā (mother), 吗 ma (question) |
| 报 | bào | report / announce |  | 报错; also 报告 "report", 报名 "sign up" |
| 错 | cuò | wrong / mistaken |  | 报错 = 钅+昔; recurs in 错误, 没错 |
| 钅 | jīn | metal / gold | R | radical (金) — signals metal words |
| 发 | fā | send out / emit / issue |  | 发布; also 发现 "discover", 开发 "develop" |
| 布 | bù | cloth → spread / announce |  | 发布; also 宣布 "declare" |
| 提 | tí | raise / lift / carry |  | 提交; also 提出 "put forward", 提高 "raise" |
| 交 | jiāo | hand over / exchange |  | 提交; also 交流 "exchange", 交付 "deliver" |
| 测 | cè | measure / survey |  | 测试; also 测量 "measure", 预测 "forecast" (氵 water radical) |
| 试 | shì | try / attempt / test |  | 测试; also 试试 "give it a try", 尝试 "attempt" |
| 分 | fēn | divide / split / minute |  | in 分支 branch; the top 八 is two strokes splitting apart over 刀 knife |
| 支 | zhī | branch / limb / support |  | in 分支 branch |
| 运 | yùn | transport / move / fortune |  | in 运行 run; 辶 the walking radical |
| 行 | xíng | go / walk / operate / OK |  | in 运行 run; also stands alone meaning "that works / OK" |
| 检 | jiǎn | examine / inspect | R | 木 wood radical + 佥; appears in 检查, 检验, 检测 |
| 查 | chá | investigate / look into / check |  | 木 wood over 旦 dawn; appears in 检查, 调查, 查看 |
| 部 | bù | part / section / ministry |  | the "section" in 部署; also 部分 bùfen "part" |
| 署 | shǔ | arrange / assign / (government) office |  | the "arrange" in 部署 — deploying = arranging the sections |
| 问 | wèn | ask | P | 口 mouth inside 门 mén 'door' (phonetic) - asking at the door |
| 题 | tí | topic / problem / title |  | the 题 in 问题 and in exam/puzzle questions |
| 的 | de | possessive / descriptive particle - the single most common character in Chinese |  | grammatical glue; turns 好 'good' into 好的 'alright' |
| 合 | hé | join / close / fit together |  | in 合并 merge; also 合作 cooperate |
| 并 | bìng | combine / side by side / and |  | in 合并 merge; also 并行 parallel (with 行 xíng, already a brick) |
| 修 | xiū | repair / mend / cultivate |  | the 修 of 修复; also 修改 xiūgǎi "revise" |
| 复 | fù | return / restore / again |  | the 复 of 修复; also 恢复 huīfù "recover", 重复 chóngfù "repeat" |
| 声 | shēng | sound / voice |  | also the 声 in 声调 shēngdiào 'tone (of a syllable)' |
| 音 | yīn | sound / tone / music |  | recurs in 音乐 yīnyuè 'music' and 拼音 pīnyīn - the 音 the user already reads in every gloss |

## Pipeline (introduce a couple at a time; all enter at level 0)

功能 gōngnéng feature (功 merit + 能 ability) · 调试 tiáoshì debug (调 adjust + 试 try/test) · 需要 xūyào need · 现在 xiànzài now · 已经 yǐjīng already · 函数 hánshù function · 变量 biànliàng variable (变 change + 量 quantity)

<!-- END:generated -->
