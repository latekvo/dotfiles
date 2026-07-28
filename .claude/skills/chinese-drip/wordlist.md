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
track added 2026-07-21 · level-4 flattened out of the tables 2026-07-28.

## Progress legend
- **0** brand new — full inline gloss `汉字 (pīnyīn, "meaning")` on FIRST use per message.
- **1** shaky — bare in the text, then a footer reminder at the end of the message.
- **2** getting there — mostly bare, occasional light support.
- **3** almost — no gloss; occasionally TEST recall ("你还记得 X 吗?") instead of telling.
- **4** learned — bare forever, no explanation; lives in the flat list, not the table.

Words move both ways: promote on correct/comfortable use, demote the moment one slips.
A demotion out of level 4 pulls the word back into the table (rebuild its row).

---

## Learned (level 4) — bare, forever

**Words:** 你好 · 好 · 谢谢 · 我 · 你 · 是 · 不

**Bricks (字):** 你 · 好 · 女 · 子 · 我 · 是 · 不

## Words

| 汉字 | pīnyīn | meaning | lvl | parts (character breakdown) |
|------|--------|---------|:---:|------|
| 完成 | wánchéng | done / complete | 1 | 完 finish + 成 accomplish; reused 2026-07-28 (malware investigation wrap-up) |
| 代码 | dàimǎ | code | 0 | 代 substitute + 码 code; 码 = 石 stone + 马 mǎ (phonetic) |
| 报错 | bàocuò | (throws) an error | 0 | 报 report + 错 wrong; 错 = 钅 metal + 昔 (phonetic) |
| 文件 | wénjiàn | file / document | 1 | 文 writing/art + 件 item ← the user's own example; reused 2026-07-27 (the temporary test harness file) → lvl 1, footer reminder next |
| 提交 | tíjiāo | commit (also "submit / hand in") | 0 | 提 raise/carry + 交 hand over; introduced 2026-07-28 on the dotfiles commit of this very change |
| 发布 | fābù | release / publish | 1 | 发 send out + 布 spread/announce; introduced 2026-07-23 on the argent release walkthrough; reused 2026-07-24 in the 0.17.0 E2E report → lvl 1; reused 2026-07-28 (MCP Registry publish doc — topic-perfect fit) |

## Characters (字) — the atoms

The reusable bricks still being taught. Once a brick is known, stop decomposing the words
it's in and move it to the flat **Bricks** list above; when it recurs in a NEW word, name
the payoff ("你 already know 码 from 代码"). Radicals and common phonetics are bricks too.
**R** = the character often acts as a radical (meaning cue); **P** = often acts as a
phonetic (sound cue).

| 字 | pīnyīn | meaning | tags | appears in / notes |
|----|--------|---------|:----:|------|
| 文 | wén | writing / language / art | | 文件; a base for 文字, 中文, 论文 |
| 件 | jiàn | item / piece | | 文件; measure word for matters/things |
| 完 | wán | complete / finish | | 完成 = 宀 roof + 元 primary |
| 成 | chéng | become / accomplish | | 完成 (contains 戈 halberd) |
| 代 | dài | substitute / represent / generation | | 代码; also 现代 "modern", 时代 "era" |
| 码 | mǎ | code / number | | 代码 = 石+马; recurs in 号码, 密码 |
| 石 | shí | stone | R | radical in 码 |
| 马 | mǎ | horse | P | **key phonetic:** 码 mǎ, 妈 mā (mother), 吗 ma (question) |
| 报 | bào | report / announce | | 报错; also 报告 "report", 报名 "sign up" |
| 错 | cuò | wrong / mistaken | | 报错 = 钅+昔; recurs in 错误, 没错 |
| 钅 | jīn | metal / gold | R | radical (金) — signals metal words |
| 发 | fā | send out / emit / issue | | 发布; also 发现 "discover", 开发 "develop" |
| 布 | bù | cloth → spread / announce | | 发布; also 宣布 "declare" |
| 提 | tí | raise / lift / carry | | 提交; also 提出 "put forward", 提高 "raise" |
| 交 | jiāo | hand over / exchange | | 提交; also 交流 "exchange", 交付 "deliver" |

## Pipeline (introduce a couple at a time; all enter at level 0)

分支 fēnzhī branch (分 divide + 支 branch) ·
修复 xiūfù fix (修 repair + 复 restore) · 功能 gōngnéng feature (功 merit + 能 ability) ·
调试 tiáoshì debug (调 adjust + 试 try/test) · 部署 bùshǔ deploy · 合并 hébìng merge (合 join + 并 combine) ·
测试 cèshì test (测 measure + 试 try) · 运行 yùnxíng run (运 move + 行 go) · 需要 xūyào need ·
检查 jiǎnchá check (检 inspect + 查 examine) · 问题 wèntí problem/question (问 ask + 题 topic) ·
现在 xiànzài now · 已经 yǐjīng already · 函数 hánshù function · 变量 biànliàng variable (变 change + 量 quantity)
