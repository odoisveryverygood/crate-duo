# CRATE: distribution & marketing handoff

Owner of this doc: the **distribution/marketing agent**. Engineering is a separate agent with its own handoff
(`HANDOFF.md` at the repo root). You do not change app code. You own posts, videos, the waitlist site's copy,
outreach, analytics, and user research. Last updated 2026-09-29 (Tue) morning PT.

## 1. The goal

Steven (founder) is preparing for a **YC interview**. Everything you do serves three outcomes, in this order:

1. **Understand the user.** Who wants CRATE, why, and what they'd pay for. Real answers from real people.
2. **Traction YC respects.** Real usage (actives, retention, shares) beats waitlist size. Waitlist is a leading indicator only.
3. **Distribution that compounds.** Channels that keep working without Steven posting every day (sharing loops, press, App Store featuring).

The long-term thesis: **an instrument, not a generator.** Suno makes the song for you; CRATE lets you play it, from your own samples,
so you own it. The iPhone Duo is the wedge that gets attention, not the market.

## 2. The product, in one breath

CRATE is an AI sampler for iPhone Duo (Apple's foldable). Type a vibe ("french jazz piano sample"), get a playable beat in
~0.3 s from a sample library; play it by hand on 16 pads; the **hinge is an FX knob** (fold = build tension, snap open = drop);
the back screen shows a light show for whoever's watching. Won **1st place at the YC × Bitrig iPhone Duo hackathon** (Sat 2026-09-26).

- Tagline: **"your ai foldable sampler. type a vibe, get a beat."**
- Say "sampler", not "MPC" (too technical for most people).
- Never claim "the only"/"killer app"/unverifiable superlatives.

## 3. Hard facts & constraints (read before promising anything)

- **Nobody can use CRATE yet.** The iPhone Duo preorders Oct 16 and **ships Oct 23, 2026** ($1,999). CRATE currently runs
  only in the simulator on Steven's Mac. Every CTA today points to the **waitlist**.
- Engineering is working toward a **TestFlight beta for iPhone + iPad** (blockers: a shippable, licensed sample library;
  moving API keys to a server; iPad layout). Don't announce a beta date until engineering confirms it.
- Day-one Duo launch (Oct 23) is the big planned moment: App Store submission + Apple editorial pitch + press.

## 4. Assets (all in the repo unless noted)

| Asset | Path | Notes |
|---|---|---|
| Waitlist site | https://crateduo.vercel.app, source `site/` | Brat orange, real Bitrig Duo render. Deploy: `cd site && vercel deploy --prod` |
| 30 s brat cut (best general video) | `demo/twitter/v3/crate_brat_30.mp4` (also `~/Downloads/crate_x_brat_30_v2.mp4`) | Opens on hinge fold → drop in 3 s; orange/white alternating; app's real audio |
| Hinge-FX showcase, 24 s | `demo/twitter/v3/crate_fx.mp4` (also `~/Downloads/crate_x_fx.mp4`) | 5 effects (LP filter, beat repeat, half speed, bitcrush, dub echo); **not posted yet** |
| Original 1:17 demo (Steven's cut) | `~/Downloads/twitter final.mov` | The post that went to 58K |
| Other cuts | `demo/twitter/v2/crate_brat.mp4`, `crate_clean.mp4`; `demo/crate_demo_final*.mp4` (hackathon video) | |
| Poster 4:5 | `demo/poster/crate_poster.png` | "Your AI foldable sampler." (older white style) |
| Social/OG card | `site/og.png` | Orange, used for link previews |
| Trophy photos | `demo/twitter/replies/trophy_team.jpg`, `trophy_yc.jpg` | |
| Raw footage | `~/Downloads/{4,6,7}.mp4`, `crate twitter 2.mp4`; Bitrig hinge takes `demo/raw/fx_*.mov/.wav` | |
| Video tooling | `tools/video/build_tw3.py` (brat 30 s), `build_fx.py` (FX showcase), `bitrig_fx_take.py` (record Bitrig takes) | Keys Bitrig's backdrop to orange/white |

**Brat style guide** (used across video + site): background `#FF5300` alternating with white; text lowercase **Arial Narrow /
Archivo Narrow**, white on orange, orange on white; captions **sharp** (no blur; only the big "crate." wordmark is blurred);
square corners, no shadows, no polish. End card: "crate." + one line + `crateduo.vercel.app`.

## 5. Tracking (use it on every link)

Short links (redirect to the site with a source tag):

| Channel | Link |
|---|---|
| X | crateduo.vercel.app/x |
| 小红书 (Xiaohongshu) | crateduo.vercel.app/xhs |
| LinkedIn | crateduo.vercel.app/li |
| TechCrunch / press | crateduo.vercel.app/tc |
| YC | crateduo.vercel.app/yc |

Add more by editing `site/vercel.json` redirects (`/foo → /?r=foo`) and redeploying. Any `?r=<tag>` works without a redirect.

After signing up, visitors get a one-tap question: **make beats / sing / dj / play an instrument / just curious**.

Read the list (private Vercel Blob store):

```
cd ~/crate-build/site && node waitlist-export.mjs          # table + totals by source, role, work-email domains
cd ~/crate-build/site && node waitlist-export.mjs --csv    # email,signed_up,country,source,role,email_type,company_domain
```

Never publish or share individual emails. Aggregate numbers only.

## 6. What has happened so far

| When (PT) | What | Result |
|---|---|---|
| Sun 9/27 ~midnight | First X post (deleted, 40 views) | Reposted |
| Mon 9/28 8:30 am | **X post #1** (Steven's 1:17 video), "We won 1st place at the @ycombinator × @bitrig hackathon 🏆 …" + replies: waitlist+poster, trophy photos | **58K impressions, 275 likes, 122 bookmarks, 37 replies, 29 reposts, 263 profile visits, 29 new follows, 11K media views** |
| Mon 9/28 8:30 am | LinkedIn post (scheduled by Steven) | 99 impressions in first 8 min; no later numbers pulled |
| Mon 9/28 | Replies from Bitrig (official), Julian Schiavo, Thomas Karatzas (judge: "honored to have voted this first place"), others | Steven replied to all |
| Mon 9/28 pm | Reply on Sarah Perez (TechCrunch) Duo-Man post linking our post; **pitch email sent to sarahp@techcrunch.com** (short version, 30 s cut attached) | No reply yet as of this writing |
| Tue 9/29 9:47 am | **X post #2**: quote of #1, "iPhone Duo is now your DJ deck / Fold it to build, snap open to drop" + 30 s brat cut | **511 impressions, 12 likes, 7.6% engagement, 125 media views, 4 profile visits, 0 follows** |
| Waitlist | 28 signups by Tue 9:45 am, 7 countries (US, AU, SG, HK, TW, KR, CH); 6 work-email domains incl. bitrig.com, nstudio.io | Source/role tracking only started Tue 9/29, earlier rows are "unknown" |

## 7. What we learned (the important part)

**Post #1 vs post #2**

- #1 broke out: **97.7% of impressions were non-followers.** #2 stayed home: **26.8% followers**, 511 impressions.
- #2's *engagement rate* was higher (7.6% vs 2.0%). People who saw it liked it. The problem was **distribution, not the video.**
- Why #2 didn't travel:
  1. **No news.** #1 had a hook with social proof ("We won 1st place at YC"). #2 said "iPhone Duo is now your DJ deck", a claim with no event.
  2. **Quote of own post** reads as a repeat to the same graph; X showed it mostly to followers who'd seen #1.
  3. **Low early velocity.** It needs a burst of likes/replies in the first 30 min to get pushed to non-followers. It didn't get one.
- Rule going forward: **every post needs new news or a new "wow"** (a result, a number, a person, a surprising use), not a restatement.

**Video behavior**

- Avg watch time on #1 was **~9–10 s** of 1:17, completion ~2%. People leave fast; the best moment must be in the **first 2 s**.
  The 30 s brat cut fixes this (hinge drop at 3 s). Keep future videos ≤30 s, strongest moment first.
- Media views ≈ 19–24% of impressions: the preview frame matters. Make frame 1 the most striking visual.

**Audience reality check**

- X audience for #1: **91% male, 66% aged 25–44, 86% iOS, 56% US**. That's the **tech/Apple crowd**, not musicians.
- Waitlist: mostly personal emails; a few builders/studios (bitrig.com, nstudio.io); at least one likely musician (a violinist).
- Hypothesis to test: interest so far is **"cool Duo demo"** curiosity, not "musicians who need this." The one-tap role question
  and interviews will tell us. This matters more for YC than raw signups.
- 小红书 is the opposite audience (Steven's ~7K followers, mostly women in their 20s, following him for singing). That's a
  test of the "anyone can make music" thesis.

**Conversion**

- 58K impressions → 263 profile visits → ~28 signups. Profile/link click is the choke point (link lives in a reply/profile).
  Put the short link in the **first reply**, pin the post to the profile, keep the profile bio link = crateduo.vercel.app/x.

## 8. Plan (now → Duo launch Oct 23)

**This week (9/29 – 10/5): understand the user**
- [ ] **10 user interviews, 15 min each.** Pick across roles once answers come in (make beats / sing / curious) + 1–2 builders.
      Questions: how do you make music today? what's annoying? what did you think CRATE does? would you pay, and how much? would you
      buy a Duo? Log notes in `docs/interviews/` (one file per person, no emails in filenames).
- [ ] **Email the 28 pre-tracking signups** one line asking what they do with music (reply = data + starts a conversation).
- [ ] **小红书 post #1**: the 30 s brat cut (square is fine; vertical 3:4 better), copy below. **No external links** (XHS throttles
      them): CTA "评论区扣1", then DM the **/xhs** link.
- [ ] Follow up Sarah Perez **once**, around Thu/Fri, only with something new (a number, a beta, a new video).

**Next week (10/6 – 10/12): make sharing the growth loop**
- [ ] Spec for engineering: "share your beat" = 15 s vertical video export with the brat end card + "made with crate".
      This is the real UGC plan. **Do not pay UGC creators** until people can install the app and we know which hook converts.
- [ ] Founder-led content: Steven makes a beat in CRATE in 30 s and **sings over it** (XHS + TikTok/Reels). Strongest asset he has.
- [ ] X post #3: the **FX showcase** as a standalone post with news ("5 effects, one hinge") or pinned to a milestone.

**Launch window (10/13 – 10/23)**
- [ ] Apple App Store editorial pitch ("built for iPhone Duo", day-one) once engineering has a submission date.
- [ ] Press list: Sarah Perez (TechCrunch), MacRumors, 9to5Mac, The Verge (Duo coverage), music-tech (MusicRadar, CDM, Attack).
- [ ] Launch-day post with real beta user quotes/numbers. Line up 10+ people to engage in the first 30 min.

**YC interview narrative (keep updated with real numbers)**
> Built in a weekend, 1st place at the YC × Bitrig hackathon. First post 58K views, 29 follows, N waitlist signups from M countries.
> We shipped to TestFlight on <date>; N people made M beats; X% came back on day 7. The surprise: <what interviews showed>.
> The Duo was the wedge; the insight is instrument-not-generator, which works on every phone.

**小红书 post #1 copy (ready to use, Steven approved the direction on 9/29):**

> 标题：我做了个能折叠的AI乐器，拿了YC第一🏆
>
> 上周末在旧金山 YC 的 iPhone 折叠屏黑客松
> 4 个小时，从零做了一个 AI 乐器 CRATE
> 最后拿了第一名🥇
>
> 输入一句「法式爵士钢琴」
> 0.3 秒就给你一段 beat 🎹
> 下面那块屏可以直接用手指打鼓
> 最好玩的是：把手机折起来 = 蓄力
> 啪一下打开 = 音乐 drop 🔥
>
> 想第一批试用的姐妹 评论区扣「1」
> 我会私信你内测链接 💌
>
> #AI #音乐制作 #黑客松 #YC #折叠屏 #iPhone #创业 #独立开发 #做音乐 #beat

## 9. Channel rules (learned the hard way)

- **X**: no hashtags. Link in the first reply, not the main post. Post Tue–Thu ~8:30–10:30 am PT. Line up early engagers.
  Replies: one line, human, never paragraphs (see Steven's preference). Every post needs new news.
- **小红书**: video > image for the product; 图文 carousels work for the story (trophy, behind the scenes). Evening 8–10 pm China time
  or Steven's audience peak. No outside links; comment → DM.
- **LinkedIn**: link in the first comment, story format, one media type per post (can't mix video + images).
- **Press**: short, specific pitch; attach the 30 s video; one follow-up max.

## 10. Guardrails

- **Never post, reply, DM, or email on Steven's behalf without his explicit OK for that specific message.** Draft first.
- Don't share individual waitlist emails anywhere public; don't add people to lists they didn't sign up for.
- No fabricated metrics, quotes, or testimonials. Only numbers you can reproduce from X analytics or the export.
- API keys live in `~/duo-hack/.secrets/keys.env` (gitignored). Never print or commit them. The ElevenLabs key was pasted in chat
  on 9/26 and should be rotated.
- If you need an app change (tracking, share export, onboarding copy), write it up for the engineering agent. Don't edit app code.

## 11. What engineering needs from you / you need from engineering

| You need from engineering | They need from you |
|---|---|
| TestFlight date (iPhone + iPad) | Which user types to prioritize (from the role data + interviews) |
| "Share your beat" video export | Top 3 feature requests / confusions from interviews |
| In-app analytics (prompts, sessions, D2/D7 retention, shares) | Onboarding copy + App Store listing copy/screens |
| App Store submission date for Oct 23 | Press/launch timeline so builds land in time |

## 12. Open questions for Steven

- YC interview date? (Sets the deadline for the traction story.)
- Is he comfortable posting himself singing on CRATE beats (XHS + TikTok)? It's the highest-leverage content we have.
- Budget for a licensed sample library (engineering blocker) and, later, micro-creator tests?
