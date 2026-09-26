#!/usr/bin/env bash
#
# lib/vault-digest.sh — feature-ideation の vault を決定的に集計する
#
#   usage: vault-digest.sh [--vault PATH] [--today YYYY-MM-DD] [PROJECT_DIR]
#
# CONTRACT: このスクリプトは絶対に非 0 で終了しない。
#   skills/check/SKILL.md はこの出力をコンテキスト注入 (!`...`) で受け取る。
#   注入コマンドが失敗するとスキル起動ごと abort し、モデルが本文を一切見なくなるため。
#   よって同リポの他の lib/*.sh とは違い `set -euo pipefail` を使わない。意図的な逸脱。
#
# env (すべて任意):
#   FEATURE_IDEATION_VAULT       vault パスを明示
#   FEATURE_IDEATION_TODAY       YYYY-MM-DD。今日を固定 (テスト用)
#   FEATURE_IDEATION_STALE_DAYS  停滞とみなす日数。既定 90
#   FEATURE_IDEATION_MAX_ROWS    ROWS の出力上限。既定 40
#   FEATURE_IDEATION_XREF_PATHS  外部参照の走査パスを追加 (空白区切り)
#   FEATURE_IDEATION_NO_XREF=1   外部参照の走査を無効化
#   FEATURE_IDEATION_DEBUG=1     stderr を残す

[ -n "${FEATURE_IDEATION_DEBUG:-}" ] || exec 2>/dev/null

# macOS sort/uniq collate distinct CJK chars as equal under UTF-8 locales.
export LC_COLLATE=C

SCHEMA="fid-1"
STALE_DAYS="${FEATURE_IDEATION_STALE_DAYS:-90}"
MAX_ROWS="${FEATURE_IDEATION_MAX_ROWS:-40}"
STATUS="ok"

# ---------------------------------------------------------------- 引数 ------
VAULT_ARG=""
TODAY="${FEATURE_IDEATION_TODAY:-}"
PROJECT_DIR=""

sanitize() {
  # 置換されなかった場合のリテラル ($ARGUMENTS 等) を空扱いにする保険。
  case "$1" in
    '$ARGUMENTS'|'${ARGUMENTS}'|'$0'|'$1'|'$2') printf '' ;;
    *) printf '%s' "$1" | tr '\\' '/' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --vault) VAULT_ARG="$(sanitize "${2:-}")"; shift 2 ;;
    --today) TODAY="$(sanitize "${2:-}")"; shift 2 ;;
    --) shift ;;
    *) a="$(sanitize "$1")"
       if [ -z "$a" ]; then :
       elif [ -d "$a" ]; then PROJECT_DIR="$a"
       elif [ -z "$VAULT_ARG" ]; then VAULT_ARG="$a"
       fi
       shift ;;
  esac
done

[ -n "$TODAY" ] || TODAY="$(date +%Y-%m-%d 2>/dev/null)"
case "$TODAY" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) TODAY="1970-01-01"; STATUS="degraded" ;;
esac
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="."

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/fid-digest.XXXXXX" 2>/dev/null)" || TMPD=""
[ -n "$TMPD" ] || { TMPD="${TMPDIR:-/tmp}/fid-digest.$$"; mkdir -p "$TMPD" 2>/dev/null; }
trap 'rm -rf "$TMPD" 2>/dev/null' EXIT HUP INT TERM

# ------------------------------------------------------- awk 日付ライブラリ --
# 日付演算は date(1) を使わない。GNU の -d と BSD の -v が非互換なため、
# Howard Hinnant の days_from_civil / civil_from_days を awk で持つ。
AWKLIB='
function dfc(y,m,d,  era,yoe,doy,doe){
  y-=(m<=2); era=int((y>=0?y:y-399)/400); yoe=y-era*400;
  doy=int((153*(m+(m>2?-3:9))+2)/5)+d-1;
  doe=yoe*365+int(yoe/4)-int(yoe/100)+doy;
  return era*146097+doe-719468 }
function d2n(s,  a){
  if(s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return -999999;
  split(s,a,"-"); return dfc(a[1]+0,a[2]+0,a[3]+0) }
function civ(z,  era,doe,yoe,y,doy,mp,d,m){
  z+=719468; era=int((z>=0?z:z-146096)/146097); doe=z-era*146097;
  yoe=int((doe-int(doe/1460)+int(doe/36524)-int(doe/146096))/365);
  y=yoe+era*400; doy=doe-(365*yoe+int(yoe/4)-int(yoe/100));
  mp=int((5*doy+2)/153); d=doy-int((153*mp+2)/5)+1;
  m=mp+(mp<10?3:-9); y+=(m<=2); return sprintf("%04d-%02d-%02d",y,m,d) }
function trim(s){ gsub(/^[ \t]+|[ \t]+$/,"",s); return s }
function clean(s){
  gsub(/\r/,"",s); gsub(/\t/," ",s); gsub(/`/,"'"'"'",s);
  gsub(/\*\*/,"",s); return trim(s) }
function maxdate(s,  best,d){
  best="";
  while(match(s,/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)){
    d=substr(s,RSTART,10); if(d>best) best=d; s=substr(s,RSTART+10) }
  return best }
'

# ------------------------------------------------------------ vault 解決 ----
VAULT=""; RESOLVED_BY=""; CANDIDATES=""
try_vault() { [ -n "${1:-}" ] && [ -f "$1" ] && { VAULT="$1"; RESOLVED_BY="$2"; return 0; }; return 1; }

CANDIDATE_LIST="docs/feature-ideas.md documents/feature-ideas.md feature-ideas.md .dev/feature-ideas.md"

try_vault "$VAULT_ARG" "argument" ||
try_vault "$(sanitize "${FEATURE_IDEATION_VAULT:-}")" "env" || {
  for c in $CANDIDATE_LIST; do
    try_vault "$PROJECT_DIR/$c" "default-candidate" && break
  done
}
if [ -z "$VAULT" ]; then
  CANDIDATES="$(find "$PROJECT_DIR" -maxdepth 4 \
      \( -name .git -o -name node_modules -o -name target -o -name dist \
         -o -name vendor -o -name .venv \) -prune -o \
      -type f -name 'feature-idea*.md' -print 2>/dev/null | sort)"
  try_vault "$(printf '%s\n' "$CANDIDATES" | sed -n '1p')" "search"
fi

emit_header() {
  echo "=== FEATURE-IDEA VAULT DIGEST ==="
  echo "schema: $SCHEMA"
  echo "digest_status: $1"
  echo "today: $TODAY"
}

if [ -z "$VAULT" ]; then
  emit_header "no-vault"
  echo "vault: (not found)"
  echo "searched: $CANDIDATE_LIST"
  echo "cwd: $(pwd 2>/dev/null)"
  echo "hint: 找不到 vault。請不帶參數執行 feature-ideation 從發想開始，或用 --vault 指定路徑。"
  echo "=== END DIGEST ==="
  exit 0
fi

VDIR="$(dirname "$VAULT")"
VBASE="$(basename "$VAULT")"
VSTEM="${VBASE%.md}"
DETAIL=""
[ -d "$VDIR/$VSTEM" ] && DETAIL="$VDIR/$VSTEM"

# ------------------------------------------------- 最終更新日 (git→mtime) ---
epoch_to_date() {
  awk -v e="$1" "$AWKLIB"'BEGIN{ print civ(int(e/86400)) }'
}
last_change() { # $1=path -> "YYYY-MM-DD<TAB>source"
  d=""
  if command -v git >/dev/null 2>&1; then
    d="$(git -C "$(dirname "$1")" log -1 --date=short --format=%cd -- "$(basename "$1")" 2>/dev/null)"
  fi
  case "$d" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) printf '%s\tgit\n' "$d"; return ;;
  esac
  e="$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null)"
  case "$e" in
    ''|*[!0-9]*) printf '?\tunknown\n' ;;
    *) printf '%s\tmtime\n' "$(epoch_to_date "$e")" ;;
  esac
}
days_between() { # $1=from $2=to -> N or ?
  awk -v a="$1" -v b="$2" "$AWKLIB"'BEGIN{ if(d2n(a)<0||d2n(b)<0) print "?"; else print d2n(b)-d2n(a) }'
}

VLC="$(last_change "$VAULT")"
VLC_DATE="$(printf '%s' "$VLC" | cut -f1)"
VLC_SRC="$(printf '%s' "$VLC" | cut -f2)"

# ----------------------------------------------------------- ID の形式 -----
# vault frontmatter の id_style で ID の形を切り替える。
#   prefixed (既定) : FI-001 形式。カテゴリ非依存の通し番号
#   categorical     : A-1 形式。カテゴリ文字 + 連番。旧形式の vault を、ID を付け替えずに
#                     移行するためのもの。既存の外部参照を壊さずに済む
# awk へ渡す正規表現は動的正規表現として解釈されるので、バックスラッシュを二重にしてある。
ID_STYLE="$(head -15 "$VAULT" 2>/dev/null | grep -m1 '^id_style:' \
  | sed 's/^id_style:[[:space:]]*//; s/#.*//; s/["'"'"']//g; s/[[:space:]]*$//')"
case "$ID_STYLE" in
  categorical)
    ID_RE_AWK='^[A-Za-z][A-Za-z]?-[0-9]+$'
    ID_RE_ERE='[A-Za-z]{1,2}-[0-9]{1,3}'
    LINK_RE_AWK='\\]\\([^)]*[A-Za-z][A-Za-z]?-[0-9]'
    XREF_RE_AWK='(feature[-_ ]?idea[s]?)[^A-Za-z0-9]{0,30}[A-Za-z][A-Za-z]?-[0-9]+'
    XREF_TAIL_AWK='[A-Za-z][A-Za-z]?-[0-9]+$'
    NAME_RE_ERE='^([A-Za-z]{1,2}-[0-9]+|archive-[0-9]{4})'
    ;;
  *)
    ID_STYLE="prefixed"
    ID_RE_AWK='^FI-[0-9][0-9][0-9]'
    ID_RE_ERE='FI-[0-9]{3}'
    LINK_RE_AWK='\\]\\([^)]*FI-[0-9]'
    XREF_RE_AWK='(feature[-_ ]?idea[s]?)[^A-Za-z0-9]{0,30}FI-[0-9][0-9][0-9]'
    XREF_TAIL_AWK='FI-[0-9][0-9][0-9]$'
    NAME_RE_ERE='^(FI-[0-9]{3}|archive-[0-9]{4})'
    ;;
esac

# 詳細ディレクトリのファイル名が命名規約に沿っているか
is_conforming_name() { printf '%s' "$1" | grep -qE "$NAME_RE_ERE"; }

# ------------------------------------------------------------ index 解析 ----
# 出力はタグ付きの中間レコード。bash 側で組み立てる。
IDX="$(awk -v today="$TODAY" -v staled="$STALE_DAYS" \
        -v idre="$ID_RE_AWK" -v linkre="$LINK_RE_AWK" -v idstyle="$ID_STYLE" "$AWKLIB"'
BEGIN{ SEP="^[ \t]*\\|[ \t:|-]+\\|?[ \t]*$"; tn=d2n(today); ttype="none" }
{ sub(/\r$/,"") }
NR==1 && /^---[ \t]*$/ { fm=1; next }
fm && /^---[ \t]*$/    { fm=0; next }
fm {
  if($0 ~ /^last_sweep:/){ v=maxdate($0); if(v!="") printf "K\tlast_sweep\t%s\n", v }
  next }
/^```/ { fence=!fence; next }
fence  { next }

/^## / {
  h=clean(substr($0,4))
  pending=""; intable=0; ttype="none"; awaiting_meta=0
  if(h ~ /^凡例|^既存 doc|^更新ルール|^ペンディング|^変更履歴|^再評価キュー|^優先度ピック|^実装済み台帳|^不採用の記録|^圖例|^與既有文件|^更新規則|^待整理|^變更紀錄|^重新評估佇列|^優先挑選|^已實作紀錄|^不採用紀錄/){
    section=h
    if(h ~ /^優先度ピック|^優先挑選/){ d=maxdate(h); if(d!="") printf "K\tpick_date\t%s\n", d }
  } else {
    section="category"; category=h; awaiting_meta=1
    printf "CATNAME\t%s\n", h
  }
  next }
/^#/ { pending=""; intable=0; next }

awaiting_meta && /^_/ {
  d=""; if($0 ~ /最終確認|最後確認/) d=maxdate($0)
  printf "CATCHECK\t%s\t%s\n", category, (d==""?"?":d)
  awaiting_meta=0; next }

/^[ \t]*\|/ {
  line=$0
  if(pending!=""){
    if(line ~ SEP){ commit(pending); pending=""; intable=1 } else pending=line
    next }
  if(intable){ row(line); next }
  pending=line; next }
{ pending=""; intable=0 }

function commit(h,  n,p,i,c,lc,last){
  delete col; hdrn=0; ttype="other"
  n=split(h,p,"|"); last=(h ~ /\|[ \t]*$/)? n-1 : n
  for(i=2;i<=last;i++){
    c=clean(p[i]); hdrn++; lc=tolower(c)
    if(lc=="id")                                        col["id"]=hdrn
    else if(c ~ /^(状態|狀態)$/|| lc=="status")              col["status"]=hdrn
    else if(c ~ /^(名前|名稱)$/|| lc=="name")                col["name"]=hdrn
    else if(c ~ /^(効果|效益)$/|| lc=="impact")              col["impact"]=hdrn
    else if(c ~ /^(難易度|難度)$/|| lc=="difficulty")          col["diff"]=hdrn
    else if(c ~ /^(制約|限制)$/|| lc=="constraint")          col["cons"]=hdrn
    else if(c ~ /^(依存|依賴)$/|| lc=="dependency")          col["dep"]=hdrn
    else if(c ~ /^(備考|備註)$/|| lc=="note")                col["note"]=hdrn
    else if(c ~ /^(期日|期限)$/|| lc=="due")                 col["due"]=hdrn
    else if(c ~ /何を判定|判定什麼/)                             col["what"]=hdrn
    else if(c ~ /^(判定材料|判定依據)$/)                           col["material"]=hdrn
    else if(c ~ /^(完了日|完成日)$/)                             col["donedate"]=hdrn
    else if(c ~ /^判定日$/)                             col["decldate"]=hdrn
    else if(c ~ /^(証跡|證據)$/)                               col["proof"]=hdrn
    else if(c ~ /^(知見|心得)$/)                               col["lesson"]=hdrn
    else if(c ~ /^理由$/)                               col["reason"]=hdrn
    else if(c ~ /^(復活条件|復活條件)$/)                           col["revive"]=hdrn
  }
  if(section=="category" && ("id" in col) && ("impact" in col))       ttype="cat"
  else if(section ~ /^再評価キュー|^重新評估佇列/ && ("due" in col))                ttype="queue"
  else if(section ~ /^実装済み台帳|^已實作紀錄/ && ("id" in col))                 ttype="done"
  else if(section ~ /^不採用の記録|^不採用紀錄/ && ("id" in col))                 ttype="declined"
  if(ttype!="other" && hdrn>8) printf "WARN\t%s 的表格有 %d 欄（請控制在 8 欄以內）\n", section, hdrn
}

function cell(p,key,  i){ if(!(key in col)) return ""; return clean(p[col[key]+1]) }

function row(line,  n,p,last,nf,id,st,nm,im,df,cs,nt,due,ov,proof,lesson,rsn,rev,miss){
  if(line ~ SEP || ttype=="other" || ttype=="none") return
  n=split(line,p,"|"); last=(line ~ /\|[ \t]*$/)? n-1 : n; nf=last-1
  if(nf!=hdrn){
    printf "WARN\t第 %d 行: 欄數 %d 與表頭的 %d 不符\n", FNR, nf, hdrn
    if(nf<2) return }

  if(ttype=="queue"){
    due=cell(p,"due")
    if(due !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/){
      if(due!="" && due !~ /^YYYY/) printf "WARN\t重新評估佇列: 期限 \"%s\" 不是 YYYY-MM-DD 格式\n", due
      return }
    id=cell(p,"id"); if(id ~ /^FI-00N/ || id=="") return
    ov=tn-d2n(due)
    if(cell(p,"what")=="") printf "WARN\t重新評估佇列 %s: 「要判定什麼」是空的\n", id
    if(ov>0)        printf "OVERDUE\t%s\t%s\t%d\t%s\n", due, id, ov, cell(p,"what")
    else if(ov>=-7) printf "DUESOON\t%s\t%s\t%d\t%s\n", due, id, -ov, cell(p,"what")
    return }

  if(ttype=="done"){
    id=cell(p,"id"); if(id !~ idre) return
    doneN++; proof=cell(p,"proof"); lesson=cell(p,"lesson"); miss=""
    if(proof=="" || proof ~ /^</) miss="證據"
    if(lesson=="" || lesson ~ /^</) miss=(miss==""?"心得":miss"/心得")
    if(miss!="") printf "LEDGER\t%s\t%s\t%s\n", id, cell(p,"name"), miss
    printf "DONEID\t%s\t%s\n", id, cell(p,"donedate")
    return }

  if(ttype=="declined"){
    id=cell(p,"id"); if(id !~ idre) return
    declN++
    rsn=cell(p,"reason"); rev=cell(p,"revive")
    if(rsn=="" || rsn ~ /^</) printf "WARN\t不採用紀錄 %s: 理由是空的\n", id
    if(rev=="")               printf "WARN\t不採用紀錄 %s: 復活條件是空的（沒有可能就寫 —）\n", id
    printf "DECLID\t%s\n", id
    return }

  # ttype == "cat"
  id=cell(p,"id")
  if(id !~ idre){
    # 既定の prefixed 形式で categorical な ID を見つけたとき。集計対象外だが、
    # 黙って 0 件と報告すると原因が伝わらないので件数を数えて後で案内する。
    if(idstyle=="prefixed" && id ~ /^[A-Za-z][A-Za-z]?-[0-9]+$/) legacy++
    return }
  st=cell(p,"status"); nm=cell(p,"name")
  im=cell(p,"impact"); df=cell(p,"diff"); cs=cell(p,"cons"); nt=cell(p,"note")
  if(st==""){ st="(none)"; printf "WARN\t%s: 狀態是空的\n", id }
  else if(st !~ /^(idea|probing|planned|frozen)$/){
    printf "WARN\t%s: 狀態 \"%s\" 不在規定詞彙 (idea/probing/planned/frozen) 中\n", id, st }
  if(st ~ /^(done|declined)$/)
    printf "WARN\t%s: %s 不應留在 index，請整行移到紀錄表\n", id, st
  if(line ~ /~~/) printf "WARN\t%s: 這是刪除線的墓碑行。請移到紀錄表並從 index 刪除\n", id
  if(length(nt)>200) printf "WARN\t%s: 備註有 %d 字（超過 200 字請升級為詳細檔）\n", id, length(nt)
  if(cs ~ /⚠/ && nt=="") printf "WARN\t%s: 限制為 ⚠️ 但備註沒寫升級條件\n", id

  printf "ROW\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, st, im, df, cs, category, nm, (nt ~ linkre ? "yes":"no")
  printf "CATCOUNT\t%s\n", category
  printf "STCOUNT\t%s\n", st
  printf "IDSEEN\t%s\n", id
  if(st=="frozen") printf "FROZEN\t%s\t%s\n", id, nm
}

END{
  printf "K\tdone_total\t%d\nK\tdecl_total\t%d\n", doneN, declN
  if(legacy>0)
    printf "K\tlegacy_rows\t%d\n", legacy
}
' "$VAULT" 2>/dev/null)"

pick() { printf '%s\n' "$IDX" | awk -F'\t' -v OFS='\t' -v t="$1" '$1==t{ $1=""; sub(/^\t/,""); print }'; }
kv()   { printf '%s\n' "$IDX" | awk -F'\t' -v k="$2" '$1=="K" && $2==k{print $3; exit}'; }

# 優先度ピックに載っている ID (T2 / T4 判定用)
PICK_IDS="$(sed -nE '/^## (優先度ピック|優先挑選)/,/^## /p' "$VAULT" 2>/dev/null \
  | grep -oE "$ID_RE_ERE" | sort -u)"
PICK_DATE="$(kv K pick_date)"
LAST_SWEEP="$(kv K last_sweep)"
DONE_TOTAL="$(kv K done_total)"; DECL_TOTAL="$(kv K decl_total)"

# ---------------------------------------------- 詳細ディレクトリの走査 ------
FOREIGN=""; ORPHAN=""; MISSING=""; STALE_PROBING=""; DETAIL_MD=""; DETAIL_N=0
if [ -n "$DETAIL" ]; then
  DETAIL_MD="$(find "$DETAIL" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)"
  DETAIL_N="$(printf '%s\n' "$DETAIL_MD" | grep -c . )"

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    b="$(basename "$f")"
    is_foreign=0
    # 命名規約 (id_style により FI-... か A-... ) と archive-... 以外は異物
    if ! is_conforming_name "$b"; then
      is_foreign=1
      kind="unknown"
      if head -30 "$f" 2>/dev/null | grep -qE 'REQUIRED SUB-SKILL|^## Task [0-9]|^- \[ \] \*\*Step'; then kind="plan"
      elif head -30 "$f" 2>/dev/null | grep -qE '取得日|設計仕様書|^## 未解決論点|取得日期|設計規格|^## 未解決問題'; then kind="spec"
      fi
      FOREIGN="$FOREIGN
FOREIGN	$f	$kind	$(grep -c '' "$f" 2>/dev/null)行"
    fi
    # 孤児判定は 1 hop (index + 他の詳細ファイル) で行う。
    # 異物として既に報告済みのファイルは重ねて報告しない。
    [ "$is_foreign" -eq 1 ] && continue
    n="$(grep -rlF --include='*.md' -- "$b" "$VAULT" "$DETAIL" 2>/dev/null | grep -vxF "$f" | grep -c .)"
    if [ "${n:-0}" -eq 0 ]; then
      lc="$(last_change "$f")"; lcd="$(printf '%s' "$lc" | cut -f1)"
      ORPHAN="$ORPHAN
ORPHAN	$f	last_change=$lcd	$(days_between "$lcd" "$TODAY")天前"
    fi
  done <<EOF
$DETAIL_MD
EOF

  # probing なのに詳細ファイルが長期間触られていないもの
  pick ROW | awk -F'\t' '$2=="probing"{print $1}' | while IFS= read -r id; do
    [ -n "$id" ] || continue
    df="$(printf '%s\n' "$DETAIL_MD" | grep -m1 "/$id" )"
    [ -n "$df" ] || continue
    lc="$(last_change "$df")"; lcd="$(printf '%s' "$lc" | cut -f1)"
    ag="$(days_between "$lcd" "$TODAY")"
    case "$ag" in
      ''|\?|*[!0-9]*) continue ;;
    esac
    [ "$ag" -ge "$STALE_DAYS" ] && printf 'STALE_PROBING\t%s\tupdated=%s\t%s天\n' "$id" "$lcd" "$ag"
  done > "$TMPD/stale_probing"
  STALE_PROBING="$(cat "$TMPD/stale_probing" 2>/dev/null)"
fi

# index が指すのに存在しない詳細ファイル
MISSING="$(grep -oE '\]\([^)]*\.md\)' "$VAULT" 2>/dev/null | sed 's/^](//; s/)$//' | sort -u \
  | while read -r ref; do
      # Leading "(" needed: bash 3.2 (macOS) ends $( ) at a bare pattern ")".
      case "$ref" in (''|http*|*://*) continue ;; esac
      [ -f "$VDIR/$ref" ] || [ -f "$ref" ] || printf 'MISSING_DETAIL\t%s\n' "$ref"
    done)"

# ------------------------------------------- 絶対日付の期限スキャン (補助) --
# 再評価キューが正規の置き場だが、詳細ファイル本文に書かれた絶対日付も拾う。
# `- [x]` や完了語を含む行は除外する (「2026-07-25 に確定」を期限と誤認しないため)。
SCAN_FILES="$VAULT"
[ -n "$DETAIL_MD" ] && SCAN_FILES="$SCAN_FILES $(printf '%s\n' "$DETAIL_MD" | head -100)"
LOOSE="$(awk -v today="$TODAY" "$AWKLIB"'
BEGIN{ tn=d2n(today) }
{ sub(/\r$/,""); L=$0 }
/^[ \t]*[-*] \[[xX]\]/ { next }
/確定|完了|済み|済$|✅|DONE|已完成|已實作|已結案/ { next }
{
  if(match(L,/(再評価|再判定|判定日|見直し|期限|要確認|重新評估|重新判定|複查|待確認|deadline|due|review[ -]by)[^0-9]{0,30}[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)){
    seg=substr(L,RSTART,RLENGTH); due=substr(seg,length(seg)-9)
    ov=tn-d2n(due)
    if(ov>0) printf "LOOSE_OVERDUE\t%s\t%s:%d\t%d天\t%s\n", due, FILENAME, FNR, ov, clean(substr(L,1,120))
  }
}' $SCAN_FILES 2>/dev/null | sort -u)"

# ---------------------------------------------------- 外部参照との突合 ------
XREF=""; DANGLING=""; XTRUNC="no"
if [ -z "${FEATURE_IDEATION_NO_XREF:-}" ]; then
  SCOPE=""
  for p in docs/decisions .claude/decisions docs/adr docs/plans docs/specs \
           .dev/plans .dev/specs CHANGELOG.md TODO.md ROADMAP.md \
           ${FEATURE_IDEATION_XREF_PATHS:-}; do
    [ -e "$PROJECT_DIR/$p" ] && SCOPE="$SCOPE $PROJECT_DIR/$p"
  done
  if [ -n "$SCOPE" ]; then
    # 素の ID を grep すると配列添字や版番号に大量ヒットするので、
    # 必ず feature-idea(s) の修飾つきのみを拾う。
    RAW="$(grep -rInE --include='*.md' \
      "(feature[-_ ]?idea[s]?)[^A-Za-z0-9]{0,30}$ID_RE_ERE" $SCOPE 2>/dev/null | head -60)"
    # index に載っている ID = 突合が要る対象。台帳 2 表の ID は既に閉じているので
    # 突合の必要がなく、報告もしない (未知の ID だけが dangling)。
    KNOWN="$(pick IDSEEN | sort -u | tr '\n' ' ')"
    CLOSED="$( { pick DONEID | cut -f1; pick DECLID | cut -f1; } | sort -u | tr '\n' ' ')"
    XALL="$(printf '%s\n' "$RAW" | awk -F: -v known="$KNOWN" -v closed="$CLOSED" \
        -v xre="$XREF_RE_AWK" -v xtail="$XREF_TAIL_AWK" "$AWKLIB"'
      BEGIN{ n=split(known,a," "); for(i=1;i<=n;i++) k[a[i]]=1
             m=split(closed,b," "); for(i=1;i<=m;i++) c[b[i]]=1 }
      NF>=3 {
        file=$1; ln=$2; rest=$0; sub(/^[^:]*:[0-9]+:/,"",rest)
        s=rest
        while(match(s,xre)){
          seg=substr(s,RSTART,RLENGTH); s=substr(s,RSTART+RLENGTH)
          if(match(seg,xtail)){
            id=substr(seg,RSTART)
            if(id in c) continue
            key=id SUBSEP file SUBSEP ln
            if(!seen[key]++)
              printf "%s\t%s\t%s:%s\t%s\n",(id in k?"XREF":"DANGLING"),id,file,ln,clean(substr(rest,1,150)) } } }')"
    XREF="$(printf '%s\n' "$XALL" | grep '^XREF' | head -15)"
    DANGLING="$(printf '%s\n' "$XALL" | grep '^DANGLING' | head -8)"
    [ "$(printf '%s\n' "$XALL" | grep -c .)" -gt 23 ] && XTRUNC="yes"
  fi
fi

# ------------------------------------------------- 優先度ピック改訂トリガ ---
PICK_TRIG=""
if [ -n "$PICK_DATE" ]; then
  PAGE="$(days_between "$PICK_DATE" "$TODAY")"
  case "$PAGE" in
    ''|\?|*[!0-9]*) ;;
    *) [ "$PAGE" -ge 90 ] && PICK_TRIG="$PICK_TRIG
PICK_TRIGGER	T1	距上次挑選 ($PICK_DATE) 已 ${PAGE} 天" ;;
  esac
  if [ -n "$PICK_IDS" ]; then
    NP=0; NC=0
    CLOSED_IDS="$(pick DONEID | cut -f1; pick DECLID | cut -f1)"
    for i in $PICK_IDS; do
      NP=$((NP+1))
      printf '%s\n' "$CLOSED_IDS" | grep -qxF "$i" && NC=$((NC+1))
    done
    [ "$NP" -gt 0 ] && [ $((NC*2)) -gt "$NP" ] && PICK_TRIG="$PICK_TRIG
PICK_TRIGGER	T2	挑選的 ${NP} 項中有 ${NC} 項已完成/不採用（過半）"
  fi
  # T4: 前回ピック以降に、ピックに載っていない ID が実装済み台帳に入った。
  # 完了日でフィルタしないと、移行直後や台帳が育った vault で常に発火してしまう。
  T4=""
  for i in $(pick DONEID | awk -F'\t' -v pd="$PICK_DATE" '$2>pd{print $1}'); do
    printf '%s\n' "$PICK_IDS" | grep -qxF "$i" || T4="$T4 $i"
  done
  [ -n "$T4" ] && PICK_TRIG="$PICK_TRIG
PICK_TRIGGER	T4	不在挑選中的 ID 進了已實作紀錄:$T4"
fi

# --------------------------------------------------------------- 出力 ------
section() { echo; echo "-- $1 --"; }
emit_or_none() { if printf '%s\n' "$1" | grep -q .; then printf '%s\n' "$1" | grep .; else echo "(none)"; fi; }

emit_header "$STATUS"
echo "vault: $VAULT"
echo "vault_resolved_by: $RESOLVED_BY"
if [ -n "$CANDIDATES" ] && [ "$(printf '%s\n' "$CANDIDATES" | grep -c .)" -gt 1 ]; then
  printf 'vault_candidates: %s\n' "$(printf '%s\n' "$CANDIDATES" | tr '\n' ' ')"
fi
echo "vault_last_change: $VLC_DATE ($VLC_SRC) $(days_between "$VLC_DATE" "$TODAY")天前"
if [ -n "$LAST_SWEEP" ]; then
  echo "last_sweep: $LAST_SWEEP ($(days_between "$LAST_SWEEP" "$TODAY")天前)"
else
  echo "last_sweep: (none)"
fi
echo "pick_date: ${PICK_DATE:-(none)}"
if [ -n "$DETAIL" ]; then echo "detail_dir: $DETAIL ($DETAIL_N md)"; else echo "detail_dir: (none)"; fi

section "COUNTS"
echo "open_total: $(pick ROW | grep -c .)"
LEGACY="$(kv K legacy_rows)"
if [ -n "$LEGACY" ]; then
  echo "legacy_rows: $LEGACY"
  echo "legacy_note: 有 $LEGACY 行使用類別式 ID（A-1 等）。此 vault 未宣告 id_style，因此以 FI-NNN 格式處理，上方計數不含這些行。若想不改 ID 就納入統計，請在 frontmatter 寫 id_style: categorical。"
fi
echo "ledger_done: ${DONE_TOTAL:-0}"
echo "ledger_declined: ${DECL_TOTAL:-0}"
pick CATCOUNT | sort | uniq -c | awk '{c=$1; $1=""; sub(/^ /,""); printf "by_cat\t%s\t%d\n",$0,c}'
pick STCOUNT  | sort | uniq -c | awk '{printf "by_status\t%s\t%d\n",$2,$1}'
pick ROW | awk -F'\t' '{print $3}' | sort | uniq -c | awk '{printf "by_impact\t%s\t%d\n",$2,$1}'
pick ROW | awk -F'\t' '{print $5}' | sort | uniq -c | awk '{printf "by_constraint\t%s\t%d\n",$2,$1}'
echo "detail_promoted: $(pick ROW | awk -F'\t' '$8=="yes"' | grep -c .)"

section "ROWS"
pick ROW | head -"$MAX_ROWS" | awk -F'\t' '{printf "row\t%s\t%s\t%s/%s/%s\t%s\t%s\n",$1,$2,$3,$4,$5,$6,$7}'
[ "$(pick ROW | grep -c .)" -gt "$MAX_ROWS" ] && echo "rows_truncated: yes"

section "ALERT: OVERDUE (重新評估佇列)"
emit_or_none "$(pick OVERDUE | awk -F'\t' '{printf "overdue\t%s\t%s\t逾期 %s 天\t%s\n",$2,$1,$3,$4}')"

section "ALERT: OVERDUE (內文中的絕對日期)"
emit_or_none "$LOOSE"

section "ALERT: DUE SOON (7 天內)"
emit_or_none "$(pick DUESOON | awk -F'\t' '{printf "due_soon\t%s\t%s\t剩 %s 天\t%s\n",$2,$1,$3,$4}')"

section "ALERT: STALE"
S=""
if [ -n "$LAST_SWEEP" ]; then
  A="$(days_between "$LAST_SWEEP" "$TODAY")"
  case "$A" in ''|\?|*[!0-9]*) ;; *) [ "$A" -ge "$STALE_DAYS" ] && S="stale_sweep	last_sweep=$LAST_SWEEP	${A}天" ;; esac
else
  S="stale_sweep	last_sweep 未設定（請加到 frontmatter）"
fi
pick CATCHECK | while IFS="$(printf '\t')" read -r c d; do
  [ -n "$c" ] || continue
  case "$d" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      A="$(days_between "$d" "$TODAY")"
      case "$A" in ''|\?|*[!0-9]*) ;; *) [ "$A" -ge "$STALE_DAYS" ] && printf 'stale_category\t%s\t最後確認=%s\t%s天\n' "$c" "$d" "$A" ;; esac ;;
    *) printf 'stale_category\t%s\t未填寫最後確認\n' "$c" ;;
  esac
done > "$TMPD/stale_cat"
S="$S
$(cat "$TMPD/stale_cat" 2>/dev/null)$STALE_PROBING"
emit_or_none "$S"

section "ALERT: FROZEN"
FZ="$(pick FROZEN | awk -F'\t' '{printf "frozen\t%s\t%s\n",$1,$2}')"
emit_or_none "$FZ"
FZN="$(printf '%s\n' "$FZ" | grep -c .)"
[ "$FZN" -gt 5 ] && echo "frozen_over_limit: $FZN 項。請考慮移到 known-issues"

section "ALERT: LEDGER INCOMPLETE"
emit_or_none "$(pick LEDGER | awk -F'\t' '{printf "ledger_incomplete\t%s\t%s\t%s 是空的\n",$1,$2,$3}')"

section "ALERT: DETAIL DIR"
emit_or_none "$FOREIGN
$ORPHAN
$MISSING"

section "ALERT: EXTERNAL MENTION"
emit_or_none "$XREF"
[ "$XTRUNC" = yes ] && echo "xref_truncated: yes"

section "ALERT: DANGLING ID"
emit_or_none "$DANGLING"

section "PICK TRIGGER"
emit_or_none "$PICK_TRIG"

section "PARSE WARNINGS"
emit_or_none "$(pick WARN)"

echo
echo "=== END DIGEST ==="
exit 0
