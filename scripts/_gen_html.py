#!/usr/bin/env python3
"""Generate benefit-report HTML from collected JSON data."""
import json, sys, html as H

output_path = sys.argv[1]
timestamp = sys.argv[2]

def sj(s, fb):
    try: return json.loads(s)
    except: return fb

doctor    = sj(sys.argv[3],  {"status":"error"})
ledger    = sj(sys.argv[4],  {"total":0,"qa":{},"go_rate":0})
snapshots = sj(sys.argv[5],  [])
matcher   = sj(sys.argv[6],  {"passed":False,"cases":"0"})
docsync   = sj(sys.argv[7],  {"clean":False})
tests     = sj(sys.argv[8],  {"passed":False})
facts     = sj(sys.argv[9],  {"markers":0,"all_fresh":False})
git_hist  = sj(sys.argv[10], [])
git_num   = sj(sys.argv[11], [])
owners    = sj(sys.argv[12], [])

e = lambda s: H.escape(str(s))

# Status display mapping
STATUS_DISPLAY = {
    "ready": "READY", "ready-with-warnings": "WARNINGS",
    "not-ready": "NOT READY", "error": "ERROR",
}

# --- derived ---
sf = sum(1 for s in snapshots if s.get("status") in ("fresh","updated-in-worktree"))
ss = sum(1 for s in snapshots if s.get("status")=="stale")
sm = sum(1 for s in snapshots if s.get("status")=="missing")
st = len(snapshots)
sp = round(sf/st*100) if st else 0

lt = ledger.get("total",0)
lgo = ledger.get("qa",{}).get("GO",0)
lno = ledger.get("qa",{}).get("NO-GO",0)
lpa = ledger.get("qa",{}).get("PARTIAL",0)
lgr = ledger.get("go_rate",0)
lis = ledger.get("issues",0)
lrd = ledger.get("role_distribution",{})

mp = matcher.get("passed",False)
mc = matcher.get("cases","0 cases")
tp = tests.get("passed",False)
dc = docsync.get("clean",False)
fm = facts.get("markers",0)
ff = facts.get("all_fresh",False)
fs = facts.get("stale",0)

tc = len(git_num)
ta = sum(c.get("added",0) for c in git_num)
td = sum(c.get("deleted",0) for c in git_num)

# scores
sc = []
ds = doctor.get("status","error")
sc.append(("安装健康 Install", 20 if ds in ("ready","ready-with-warnings") else 0, 20))
sc.append(("角色匹配 Matcher", 20 if mp else 0, 20))
sc.append(("知识新鲜 Knowledge", round(sf/st*20) if st else 0, 20))
sc.append(("文档门禁 Doc-Sync", 20 if dc else 0, 20))
sc.append(("测试套件 Tests", 20 if tp else 0, 20))
tot_sc = sum(x[1] for x in sc)

# snapshot table
snap_html = ""
for s in snapshots:
    r = s.get("role","?")
    sta = s.get("status","?")
    sd = (s.get("snapshot_commit") or {}).get("date","—")
    cd = (s.get("code_commit") or {}).get("date","—")
    cls = {"fresh":"badge-ok","stale":"badge-warn","missing":"badge-err"}.get(sta,"badge-info")
    snap_html += f'<tr><td><code>{e(r)}</code></td><td><span class="badge {cls}">{e(sta.upper())}</span></td><td>{e(sd)}</td><td>{e(cd)}</td></tr>\n'

# commit timeline
com_html = ""
mx_a = max((c.get("added",0) for c in git_num), default=1) or 1
for c in git_num:
    a,d = c.get("added",0), c.get("deleted",0)
    pa,pd = round(a/mx_a*100), round(d/mx_a*100)
    com_html += f'<div class="cr"><span class="cd">{e(c.get("date",""))}</span><div class="cb"><div class="ba" style="width:{pa}%">+{a}</div><div class="bd" style="width:{pd}%">-{d}</div></div><span class="cm">{e(c.get("subject","")[:68])}</span></div>\n'

# owner table
own_html = ""
for o in owners:
    cs = o.get("code",[])
    cstr = ", ".join(e(c) for c in cs[:3])
    if len(cs)>3: cstr += f" +{len(cs)-3}"
    kr = len(o.get("knowledge_roles",[]))
    own_html += f'<tr><td><code>{e(o.get("id","?"))}</code></td><td>{e(o.get("label",""))}</td><td>{e(o.get("kind",""))}</td><td><code>{cstr}</code></td><td>{kr}</td></tr>\n'

# role dist
rd_html = ""
if lrd:
    mx_r = max(lrd.values()) or 1
    for r,n in sorted(lrd.items(), key=lambda x:-x[1]):
        rd_html += f'<div class="dr"><code>{e(r)}</code><div class="db" style="width:{round(n/mx_r*100)}%">{n}</div></div>\n'

# score bars
sc_html = ""
for lb,v,mx in sc:
    p = round(v/mx*100) if mx else 0
    cl = "--c-success" if p>=80 else "--c-warning" if p>=40 else "--c-danger"
    sc_html += f'<div class="sr"><span class="sl">{e(lb)}</span><div class="st"><div class="sf" style="width:{p}%;background:var({cl})"></div></div><span class="sv">{v}/{mx}</span></div>\n'

# problems
pr_html = "".join(f"<li>{e(p)}</li>" for p in doctor.get("problems",[]))

# status pill helper
def pill(ok, yes="PASS", no="FAIL"):
    c = "badge-ok" if ok else "badge-err"
    return f'<span class="badge {c}">{yes if ok else no}</span>'


# --- Write HTML ---
with open(output_path, "w", encoding="utf-8") as f:
    f.write(f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Governance Benefit Report</title>
<style>
:root {{
  --c-bg: #F1F5F9; --c-surface: #FFFFFF; --c-text: #1E293B;
  --c-muted: #64748B; --c-border: #CBD5E1;
  --c-primary: #0F766E; --c-primary-light: #CCFBF1;
  --c-success: #059669; --c-success-bg: #D1FAE5;
  --c-warning: #D97706; --c-warning-bg: #FEF3C7;
  --c-danger: #DC2626; --c-danger-bg: #FEE2E2;
  --c-info: #0284C7; --c-info-bg: #E0F2FE;
  --c-add: #059669; --c-del: #DC2626;
  --radius: 6px; --mono: ui-monospace, SFMono-Regular, Menlo, monospace;
}}
@media(prefers-color-scheme:dark) {{
  :root:not([data-theme="light"]) {{
    --c-bg: #0F172A; --c-surface: #1E293B; --c-text: #E2E8F0;
    --c-muted: #94A3B8; --c-border: #334155;
    --c-primary: #2DD4BF; --c-primary-light: #134E4A;
    --c-success: #34D399; --c-success-bg: #064E3B;
    --c-warning: #FBBF24; --c-warning-bg: #78350F;
    --c-danger: #F87171; --c-danger-bg: #7F1D1D;
    --c-info: #38BDF8; --c-info-bg: #0C4A6E;
    --c-add: #34D399; --c-del: #F87171;
  }}
}}
:root[data-theme="dark"] {{
  --c-bg: #0F172A; --c-surface: #1E293B; --c-text: #E2E8F0;
  --c-muted: #94A3B8; --c-border: #334155;
  --c-primary: #2DD4BF; --c-primary-light: #134E4A;
  --c-success: #34D399; --c-success-bg: #064E3B;
  --c-warning: #FBBF24; --c-warning-bg: #78350F;
  --c-danger: #F87171; --c-danger-bg: #7F1D1D;
  --c-info: #38BDF8; --c-info-bg: #0C4A6E;
  --c-add: #34D399; --c-del: #F87171;
}}
*,*::before,*::after {{ box-sizing:border-box; margin:0; padding:0; }}
body {{
  font-family: system-ui, -apple-system, sans-serif;
  background: var(--c-bg); color: var(--c-text);
  line-height: 1.5; padding: 24px; max-width: 1100px; margin: 0 auto;
}}
h1 {{ font-size: 1.5rem; font-weight: 700; color: var(--c-primary); margin-bottom: 4px; }}
.subtitle {{ font-size: .8rem; color: var(--c-muted); margin-bottom: 20px; font-family: var(--mono); }}
h2 {{ font-size: 1.05rem; font-weight: 600; margin: 24px 0 10px; padding-bottom: 6px;
  border-bottom: 2px solid var(--c-primary); display: inline-block; }}
h3 {{ font-size: .9rem; font-weight: 600; margin: 12px 0 6px; color: var(--c-muted); }}

/* Stat tiles */
.tiles {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; margin-bottom: 20px; }}
.tile {{ background: var(--c-surface); border: 1px solid var(--c-border); border-radius: var(--radius);
  padding: 12px; text-align: center; }}
.tile-val {{ font-size: 1.6rem; font-weight: 700; font-family: var(--mono);
  font-variant-numeric: tabular-nums; }}
.tile-label {{ font-size: .7rem; color: var(--c-muted); text-transform: uppercase; letter-spacing: .05em; margin-top: 2px; }}

/* Badges */
.badge {{ display: inline-block; padding: 1px 8px; border-radius: 3px;
  font-size: .7rem; font-weight: 600; font-family: var(--mono); text-transform: uppercase; letter-spacing: .03em; }}
.badge-ok {{ background: var(--c-success-bg); color: var(--c-success); }}
.badge-warn {{ background: var(--c-warning-bg); color: var(--c-warning); }}
.badge-err {{ background: var(--c-danger-bg); color: var(--c-danger); }}
.badge-info {{ background: var(--c-info-bg); color: var(--c-info); }}

/* Sections */
.section {{ background: var(--c-surface); border: 1px solid var(--c-border);
  border-radius: var(--radius); padding: 16px; margin-bottom: 14px; }}
.section h2 {{ margin-top: 0; }}

/* Tables */
table {{ width: 100%; border-collapse: collapse; font-size: .82rem; }}
th {{ text-align: left; padding: 6px 8px; border-bottom: 2px solid var(--c-border);
  font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; color: var(--c-muted); }}
td {{ padding: 5px 8px; border-bottom: 1px solid var(--c-border); font-family: var(--mono); font-size: .78rem; }}
tr:last-child td {{ border-bottom: none; }}

/* Commit rows */
.cr {{ display: grid; grid-template-columns: 80px 1fr 1fr; gap: 6px; align-items: center;
  padding: 3px 0; font-size: .75rem; border-bottom: 1px solid var(--c-border); }}
.cr:last-child {{ border-bottom: none; }}
.cd {{ font-family: var(--mono); color: var(--c-muted); font-variant-numeric: tabular-nums; }}
.cb {{ display: flex; gap: 2px; }}
.ba {{ background: var(--c-success-bg); color: var(--c-add); padding: 1px 4px;
  border-radius: 2px; font-family: var(--mono); font-size: .65rem; min-width: 28px;
  font-variant-numeric: tabular-nums; }}
.bd {{ background: var(--c-danger-bg); color: var(--c-del); padding: 1px 4px;
  border-radius: 2px; font-family: var(--mono); font-size: .65rem; min-width: 28px;
  font-variant-numeric: tabular-nums; }}
.cm {{ color: var(--c-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }}

/* Score bars */
.sr {{ display: grid; grid-template-columns: 200px 1fr 50px; gap: 8px; align-items: center;
  padding: 4px 0; font-size: .8rem; }}
.sl {{ font-size: .75rem; }}
.st {{ height: 14px; background: var(--c-border); border-radius: 7px; overflow: hidden; }}
.sf {{ height: 100%; border-radius: 7px; transition: width .5s; }}
.sv {{ font-family: var(--mono); font-size: .75rem; text-align: right; font-variant-numeric: tabular-nums; }}

/* Distribution bars */
.dr {{ display: grid; grid-template-columns: 180px 1fr; gap: 8px; align-items: center; padding: 3px 0; }}
.db {{ background: var(--c-primary-light); color: var(--c-primary); padding: 2px 8px;
  border-radius: 3px; font-family: var(--mono); font-size: .72rem; font-variant-numeric: tabular-nums; }}

/* Benefit list */
.benefit {{ padding: 8px 12px; margin: 4px 0; border-left: 3px solid var(--c-primary);
  background: var(--c-primary-light); border-radius: 0 var(--radius) var(--radius) 0; font-size: .82rem; }}
.benefit strong {{ color: var(--c-primary); }}

/* Problems */
.problems {{ list-style: none; }}
.problems li {{ padding: 4px 8px; margin: 3px 0; background: var(--c-warning-bg);
  color: var(--c-warning); border-radius: 3px; font-size: .78rem; font-family: var(--mono); }}
.problems li::before {{ content: "⚠ "; }}

/* Two-col grid */
.grid2 {{ display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }}
@media(max-width:700px) {{ .grid2 {{ grid-template-columns: 1fr; }} .sr {{ grid-template-columns: 1fr 1fr 50px; }} }}

/* Overflow */
.scroll-x {{ overflow-x: auto; }}
</style>
</head>
<body>

<h1>🏛️ Role Governance — Benefit Report 收益验证报告</h1>
<div class="subtitle">Generated 生成于 {e(timestamp)}</div>

<!-- Score Overview -->
<div class="section">
<h2>📊 Governance Score 治理评分</h2>
<div style="display:flex;align-items:center;gap:20px;margin:12px 0">
  <div class="tile-val" style="font-size:2.4rem;color:{"var(--c-success)" if tot_sc>=80 else "var(--c-warning)" if tot_sc>=60 else "var(--c-danger)"}">{tot_sc}<span style="font-size:1rem;color:var(--c-muted)">/{sum(x[2] for x in sc)}</span></div>
  <div style="flex:1">{sc_html}</div>
</div>
</div>

<!-- Stat Tiles -->
<div class="tiles">
  <div class="tile">
    <div class="tile-val" style="color:{"var(--c-success)" if ds in ("ready","ready-with-warnings") else "var(--c-danger)"}; font-size:1.2rem">{e(STATUS_DISPLAY.get(ds, ds.upper()))}</div>
    <div class="tile-label">安装状态 Install</div>
  </div>
  <div class="tile">
    <div class="tile-val" style="color:{"var(--c-success)" if lgr>60 else "var(--c-warning)" if lgr>0 else "var(--c-muted)"}">{lgr}%</div>
    <div class="tile-label">GO 率 GO Rate</div>
  </div>
  <div class="tile">
    <div class="tile-val" style="color:{"var(--c-success)" if mp else "var(--c-danger)"}">{mc}</div>
    <div class="tile-label">匹配测试 Matcher</div>
  </div>
  <div class="tile">
    <div class="tile-val" style="color:{"var(--c-success)" if sp>=80 else "var(--c-warning)" if sp>=40 else "var(--c-danger)"}">{sf}/{st}</div>
    <div class="tile-label">新鲜快照 Fresh Snaps</div>
  </div>
  <div class="tile">
    <div class="tile-val">{pill(dc,"CLEAN","DIRTY")}</div>
    <div class="tile-label">文档门禁 Doc-Sync</div>
  </div>
  <div class="tile">
    <div class="tile-val">{pill(tp)}</div>
    <div class="tile-label">测试 Tests</div>
  </div>
  <div class="tile">
    <div class="tile-val" style="color:{"var(--c-success)" if ff else "var(--c-warning)"}">{fm}</div>
    <div class="tile-label">外部事实 Ext Facts</div>
  </div>
</div>

<div class="grid2">

<!-- Knowledge Health -->
<div class="section">
<h2>🧠 Knowledge Health 知识健康</h2>
<p style="font-size:.78rem;color:var(--c-muted);margin-bottom:8px">
  {sf} fresh · {ss} stale · {sm} missing — {sp}% 新鲜率</p>
<div class="scroll-x">
<table>
<tr><th>Role 角色</th><th>Status 状态</th><th>Snapshot 快照</th><th>Code 代码</th></tr>
{snap_html}
</table>
</div>
</div>

<!-- Quality Ledger -->
<div class="section">
<h2>📋 Quality Ledger 质量账本</h2>
<p style="font-size:.78rem;color:var(--c-muted);margin-bottom:8px">
  {lt} entries · GO={lgo} NO-GO={lno} PARTIAL={lpa} · {lis} issues</p>
{f'<h3>Role Distribution 角色分布</h3>{rd_html}' if rd_html else '<p style="font-size:.78rem;color:var(--c-muted)">No ledger data yet</p>'}
</div>

</div><!-- grid2 -->

<!-- Doc-Sync Gate -->
<div class="section">
<h2>🔒 Doc-Sync Gate 文档同步门禁</h2>
<p style="font-size:.82rem;margin-bottom:8px">
  Gate status: {pill(dc,"CLEAN — no violations","DIRTY — violations detected")}
</p>
{f'<h3>Protected Owners 保护的所有者</h3><div class="scroll-x"><table><tr><th>ID</th><th>Label</th><th>Kind</th><th>Code Globs</th><th>Roles</th></tr>{own_html}</table></div>' if own_html else ''}
{f'<h3>Problems 问题</h3><ul class="problems">{pr_html}</ul>' if pr_html else ''}
</div>

<!-- Commit Timeline -->
<div class="section">
<h2>📈 Project Evolution 项目演进</h2>
<p style="font-size:.78rem;color:var(--c-muted);margin-bottom:8px">
  {tc} commits · +{ta} / -{td} lines</p>
<div class="scroll-x">
{com_html}
</div>
</div>

<!-- Benefit Summary -->
<div class="section">
<h2>✅ Benefit Summary 收益总结</h2>
<div class="benefit"><strong>防止未文档化变更 Prevents undocumented changes</strong> — doc-sync gate blocks code commits that lack matching documentation updates. Currently: {pill(dc,"ACTIVE","INACTIVE")}</div>
<div class="benefit"><strong>确定性角色路由 Deterministic role routing</strong> — 3-tier matcher (T1→T2→T3) with {mc} validated, ensures billing/contract/incident signals always override surface-level phrasing. {pill(mp)}</div>
<div class="benefit"><strong>知识同步 Knowledge synchronization</strong> — {st} role snapshots tracked; stale snapshots are caught before work begins. {sf}/{st} fresh ({sp}%)</div>
<div class="benefit"><strong>质量证据 Quality evidence</strong> — append-only ledger records GO/NO-GO with {lt} entries. Evidence, not claims. GO rate: {lgr}%</div>
<div class="benefit"><strong>外部事实新鲜度 External fact freshness</strong> — {fm} markers tracked with 180-day expiry. {pill(ff,"ALL FRESH","STALE DETECTED")}</div>
<div class="benefit"><strong>自我验证 Self-validation</strong> — integrated test suite covers matcher (adversarial cases), ledger schema, and doc-sync integration. {pill(tp)}</div>
</div>

</body>
</html>''')

print(f"Dashboard written to {output_path}")
