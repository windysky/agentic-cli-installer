#!/usr/bin/env bash
# migrate_npm_to_nvm.sh — move the npm-managed coding CLIs to ONE nvm Node (latest LTS).
#
# Run once on each PC (office PC, home PC) in a plain WSL terminal, from this repo:
#   cd <this repo> && git pull --ff-only && ./migrate_npm_to_nvm.sh
# Options:  --dry-run   print every change it would make, make none
# Re-runnable: finished steps are skipped. Nothing is removed without your "y".
set -uo pipefail

DRY_RUN=0
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (use --dry-run or --help)" >&2; exit 2 ;;
esac

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LBIN="$HOME/.local/bin"
BACKUP="$HOME/.local/bin.backup"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
TS=$(date +%Y%m%d_%H%M%S)
# Packages install_coding_tools.sh (v1.15.0+) manages through ~/.local/bin/npm.
MANAGED=(@openai/codex opencode-ai oh-my-opencode @anthropic-ai/sandbox-runtime @ast-grep/cli @playwright/cli)

mkdir -p "$BACKUP"
LOG="$BACKUP/migrate_npm_to_nvm.$TS.log"
# tee -i: survives Ctrl-C, so the output does not vanish while a child finishes.
exec > >(tee -ia "$LOG") 2>&1

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m[STOP]\033[0m %s\n  log: %s\n' "$*" "$LOG"; exit 1; }
run()  {
    if (( DRY_RUN )); then printf '  [dry-run] %s\n' "$*"; return 0; fi
    printf '  $ %s\n' "$*"; "$@"
}
ask_yes() { # default No; no usable terminal => No
    local a=""
    if (( DRY_RUN )); then info "[dry-run] would ask: $1 [y/N] (assuming No)"; return 1; fi
    if ! { : </dev/tty; } 2>/dev/null; then info "$1 [y/N]: no terminal -> No"; return 1; fi
    printf '  %s [y/N]: ' "$1"
    read -r a </dev/tty || a=""
    [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]
}
# Long-running children: --foreground keeps them in the terminal's process
# group, so Ctrl-C stops them instead of leaving them running unseen.
nvmrun() {
    local t=$1; shift
    timeout --foreground "$t" bash -c '. "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || exit 97; nvm "$@"' nvmrun "$@"
}
pkg_version() { # $1 = package dir
    sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/package.json" 2>/dev/null | head -n1
}
conda_root() {
    local c
    if [[ -n "${CONDA_EXE:-}" && -x "$CONDA_EXE" ]]; then printf '%s' "$(cd "$(dirname "$CONDA_EXE")/.." && pwd)"; return 0; fi
    for c in "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" "$HOME/mambaforge"; do
        [[ -x "$c/bin/conda" ]] && { printf '%s' "$c"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------- 0. preflight
say "0. Preflight"
(( EUID != 0 )) || die "Run as your normal user, not root/sudo."
for c in curl timeout setsid readlink git cmp; do command -v "$c" >/dev/null 2>&1 || die "'$c' is required."; done
grep -Eq "Agentic Coders Installer v(1\.(1[5-9]|[2-9][0-9])|[2-9])\." "$REPO/install_coding_tools.sh" 2>/dev/null \
    || die "$REPO/install_coding_tools.sh is older than v1.15.0. Run: git -C \"$REPO\" pull --ff-only"
[[ -f "$REPO/codex_wrapper.sh" && -f "$REPO/setup.sh" ]] || die "codex_wrapper.sh / setup.sh missing in $REPO."
if GIT_TERMINAL_PROMPT=0 timeout 30 git -c core.sshCommand='ssh -o BatchMode=yes' -C "$REPO" fetch -q 2>/dev/null; then
    behind=$(git -C "$REPO" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
    (( behind == 0 )) || die "This checkout is $behind commit(s) behind its remote. Run: git -C \"$REPO\" pull --ff-only, then re-run."
else
    warn "git fetch failed or timed out; could not confirm the checkout is current."
fi
[[ -s "$NVM_DIR/nvm.sh" ]] || die "nvm not found at $NVM_DIR. Install it first: https://github.com/nvm-sh/nvm#installing-and-updating"
CROOT=$(conda_root || true)
info "repo: $REPO"; info "nvm:  $NVM_DIR"; info "conda: ${CROOT:-not found}"; info "log:  $LOG"
(( DRY_RUN )) && warn "DRY RUN: nothing will be changed."

# Every conda prefix: the root (base) plus every env conda knows about (all envs_dirs).
PREFIXES=()
if [[ -n "$CROOT" ]]; then
    PREFIXES+=("$CROOT")
    while IFS= read -r pre; do
        [[ -n "$pre" && -d "$pre" && "$pre" != "$CROOT" ]] && PREFIXES+=("$pre")
    done < <(timeout 60 "$CROOT/bin/conda" env list 2>/dev/null | awk '!/^#/ && NF {print $NF}')
fi
label_of() { [[ "$1" == "$CROOT" ]] && printf base || printf '%s' "${1##*/}"; }

# ---------------------------------------------------------------- 1. snapshot
say "1. Current state"
for n in node npm codex; do
    if [[ -L "$LBIN/$n" ]]; then info "$LBIN/$n -> $(readlink "$LBIN/$n")"
    elif [[ -e "$LBIN/$n" ]]; then info "$LBIN/$n (regular file)"
    else info "$LBIN/$n (missing)"; fi
done
info "nvm installed: $(cd "$NVM_DIR/versions/node" 2>/dev/null && ls | tr '\n' ' ')"
for v in "$NVM_DIR"/versions/node/*/; do
    for p in "${MANAGED[@]}"; do [[ -d "$v/lib/node_modules/$p" ]] && info "  nvm $(basename "$v"): $p $(pkg_version "$v/lib/node_modules/$p")"; done
done
for pre in "${PREFIXES[@]}"; do
    for p in "${MANAGED[@]}"; do [[ -d "$pre/lib/node_modules/$p" ]] && info "  conda $(label_of "$pre"): $p $(pkg_version "$pre/lib/node_modules/$p")"; done
done

# ---------------------------------------------------------------- 2. Node LTS
say "2. Node.js: latest LTS via nvm"
NEW=$(nvmrun 60 version-remote --lts 2>/dev/null | tail -n1 | tr -d '[:space:]')
[[ "$NEW" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Could not look up the latest Node LTS (got '${NEW}'). Check the network and re-run."
NEWPREFIX="$NVM_DIR/versions/node/$NEW"
NEWBIN="$NEWPREFIX/bin"
info "latest LTS: $NEW"

OLD=""
cur_real=$(readlink -f "$LBIN/node" 2>/dev/null || true)
if [[ "$cur_real" == "$NVM_DIR"/versions/node/v*/bin/node ]]; then
    OLD=${cur_real#"$NVM_DIR"/versions/node/}; OLD=${OLD%%/*}
else
    d=$(nvmrun 20 version default 2>/dev/null | tail -n1 | tr -d '[:space:]')
    [[ "$d" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && OLD=$d
fi
info "current: ${OLD:-none}"

if [[ -x "$NEWBIN/node" ]]; then
    ok "$NEW already installed"
elif [[ -n "$OLD" && "$OLD" != "$NEW" ]]; then
    run nvmrun 1800 install "$NEW" --reinstall-packages-from="$OLD" || die "nvm install $NEW failed."
else
    run nvmrun 1800 install "$NEW" || die "nvm install $NEW failed."
fi
run nvmrun 30 alias default "$NEW" || warn "nvm alias default $NEW failed."

HAVE_NEW=1
[[ -x "$NEWBIN/node" ]] || HAVE_NEW=0
(( HAVE_NEW || DRY_RUN )) || die "nvm reported success but $NEWBIN/node does not exist."

# ---------------------------------------------------------------- 3. links
say "3. ~/.local/bin links -> $NEW"
mkdir -p "$LBIN"
# node, npm and npx always; plus every other ~/.local/bin link that already
# points into an nvm Node's bin/ (e.g. corepack), so removing an old nvm
# version can never leave a dangling link behind.
LINKS=(node npm npx)
for l in "$LBIN"/*; do
    [[ -L "$l" ]] || continue
    [[ "$(readlink "$l")" == "$NVM_DIR"/versions/node/*/bin/* ]] || continue
    case " ${LINKS[*]} " in *" ${l##*/} "*) ;; *) LINKS+=("${l##*/}") ;; esac
done
for n in "${LINKS[@]}"; do
    if (( HAVE_NEW )) && [[ ! -e "$NEWBIN/$n" ]]; then
        [[ -L "$LBIN/$n" ]] && warn "$NEW has no $n; $LBIN/$n -> $(readlink "$LBIN/$n") left as is (remove it if unused)"
        continue
    fi
    if [[ -e "$NEWBIN/$n" && "$(readlink -f "$LBIN/$n" 2>/dev/null)" == "$(readlink -f "$NEWBIN/$n" 2>/dev/null)" ]]; then
        ok "$LBIN/$n already points at $NEW"; continue
    fi
    if [[ -e "$LBIN/$n" && ! -L "$LBIN/$n" ]]; then run mv "$LBIN/$n" "$BACKUP/$n.$TS"; fi
    [[ -L "$LBIN/$n" ]] && info "old: $LBIN/$n -> $(readlink "$LBIN/$n")"
    run ln -sfn "$NEWBIN/$n" "$LBIN/$n"
done

NPM="$LBIN/npm"
npmx() { PATH="$NEWBIN:$PATH" timeout --foreground 900 "$NPM" "$@"; }

# ---------------------------------------------------------------- 4. npm
say "4. npm: newest release"
if (( HAVE_NEW )); then
    info "npm now: $(npmx --version 2>/dev/null)"
    run npmx install -g npm@latest || warn "npm@latest did not install; keeping the current npm (install_coding_tools.sh's npm row picks a compatible one)."
else
    info "[dry-run] would run: $NPM install -g npm@latest"
fi

# ---------------------------------------------------------------- 5. deploy
say "5. Deploy installer + codex wrapper (setup.sh --force)"
# setup.sh refuses to overwrite a symlinked ~/.local/bin/codex; move it aside first.
[[ -L "$LBIN/codex" ]] && run mv "$LBIN/codex" "$BACKUP/codex.$TS"
if (( DRY_RUN )); then
    info "[dry-run] would run: (cd $REPO && ./setup.sh --force)"
else
    (cd "$REPO" && timeout --foreground 600 ./setup.sh --force) || warn "setup.sh reported a problem; see the output above."
    cmp -s "$REPO/codex_wrapper.sh" "$LBIN/codex" \
        || die "$LBIN/codex is not the new wrapper after setup.sh. Stopped before removing anything."
    ok "$LBIN/codex is the new wrapper"
fi

# ---------------------------------------------------------------- 6. packages
say "6. One copy per tool: nvm copy first, then remove the conda copies"
nvm_pkg_ok() { # $1 = package; the nvm copy exists AND npm sees it as installed
    [[ -d "$NEWPREFIX/lib/node_modules/$1" ]] || return 1
    npmx ls -g --depth=0 "$1" >/dev/null 2>&1 || return 1
    if [[ "$1" == "@openai/codex" ]]; then
        "$NEWBIN/node" "$NEWPREFIX/lib/node_modules/@openai/codex/bin/codex.js" --version </dev/null >/dev/null 2>&1 || return 1
    fi
    return 0
}
RM_PKG=(); RM_PRE=()
for p in "${MANAGED[@]}"; do
    copies=()
    for pre in "${PREFIXES[@]}"; do [[ -d "$pre/lib/node_modules/$p" ]] && copies+=("$pre"); done
    in_old_nvm=0
    for v in "$NVM_DIR"/versions/node/*/; do
        [[ "${v%/}" != "$NEWPREFIX" && -d "$v/lib/node_modules/$p" ]] && in_old_nvm=1
    done
    if [[ "$p" != "@openai/codex" ]] && (( ${#copies[@]} == 0 && in_old_nvm == 0 )) && [[ ! -d "$NEWPREFIX/lib/node_modules/$p" ]]; then
        continue   # not installed anywhere: nothing to do
    fi
    if (( ! HAVE_NEW )); then
        [[ -d "$NEWPREFIX/lib/node_modules/$p" ]] || info "[dry-run] would run: $NPM install -g $p"
        info "[dry-run] $p: nvm copy would be checked before any removal is offered"
        for pre in "${copies[@]}"; do RM_PKG+=("$p"); RM_PRE+=("$pre"); done
        continue
    fi
    if ! nvm_pkg_ok "$p"; then
        run npmx install -g "$p" || warn "Could not install $p into nvm."
    fi
    if nvm_pkg_ok "$p"; then
        ok "$p: nvm copy $(pkg_version "$NEWPREFIX/lib/node_modules/$p") works"
        for pre in "${copies[@]}"; do RM_PKG+=("$p"); RM_PRE+=("$pre"); done
    else
        for pre in "${copies[@]}"; do warn "$p in conda '$(label_of "$pre")' kept: the nvm copy is missing or broken."; done
    fi
done

remove_one() { # $1 package, $2 conda prefix
    local p=$1 pre=$2 lab
    lab=$(label_of "$pre")
    if [[ -x "$pre/bin/npm" && -x "$pre/bin/node" ]]; then
        run env PATH="$pre/bin:$PATH" timeout --foreground 300 "$pre/bin/npm" uninstall -g --prefix "$pre" "$p" \
            && { (( DRY_RUN )) || [[ ! -e "$pre/lib/node_modules/$p" ]]; } && ok "removed $p from '$lab'" \
            || warn "could not remove $p from '$lab'. Manually: conda activate $lab && npm uninstall -g $p"
    else
        warn "conda '$lab' has no working npm. Manually: rm -rf \"$pre/lib/node_modules/$p\" (and its link in $pre/bin)"
    fi
}
if (( ${#RM_PKG[@]} > 0 )); then
    info ""
    info "Conda copies that the nvm copy replaces:"
    for i in "${!RM_PKG[@]}"; do
        info "  - conda $(label_of "${RM_PRE[$i]}"): ${RM_PKG[$i]} $(pkg_version "${RM_PRE[$i]}/lib/node_modules/${RM_PKG[$i]}")"
    done
    if ask_yes "Remove ALL ${#RM_PKG[@]} conda copies listed above?"; then
        for i in "${!RM_PKG[@]}"; do remove_one "${RM_PKG[$i]}" "${RM_PRE[$i]}"; done
    else
        for i in "${!RM_PKG[@]}"; do
            if ask_yes "Remove ${RM_PKG[$i]} from conda env '$(label_of "${RM_PRE[$i]}")'?"; then
                remove_one "${RM_PKG[$i]}" "${RM_PRE[$i]}"
            else
                info "kept: conda '$(label_of "${RM_PRE[$i]}")' ${RM_PKG[$i]}"
            fi
        done
    fi
else
    ok "no conda copies to remove"
fi
# Empty @scope dirs left behind by removals (rmdir only ever removes empty dirs).
for pre in "${PREFIXES[@]}"; do
    for d in "$pre"/lib/node_modules/@*/; do
        d=${d%/}
        [[ -d "$d" && -z "$(ls -A "$d" 2>/dev/null)" ]] && run rmdir "$d"
    done
done
for pre in "${PREFIXES[@]}"; do
    for d in "$pre"/lib/node_modules/* "$pre"/lib/node_modules/@*/*; do
        [[ -f "$d/package.json" ]] || continue
        n=${d#"$pre"/lib/node_modules/}
        case " npm corepack ${MANAGED[*]} " in *" $n "*) continue ;; esac
        info "not managed, left as is: conda $(label_of "$pre"): $n $(pkg_version "$d")"
    done
done
for v in "$NVM_DIR"/versions/node/*/; do
    v=${v%/}; [[ "$v" == "$NEWPREFIX" ]] && continue
    for p in "${MANAGED[@]}"; do
        [[ -d "$v/lib/node_modules/$p" ]] && info "old nvm $(basename "$v") still has $p (off PATH; delete later with: nvm uninstall $(basename "$v"))"
    done
    for l in "$LBIN"/*; do
        [[ -L "$l" && "$(readlink "$l")" == "$v"/* ]] && warn "$l -> $(readlink "$l") still uses old nvm $(basename "$v"); do not uninstall it yet"
    done
done

# ---------------------------------------------------------------- 7. verify
say "7. Verify: which codex / npm each kind of shell gets"
(( DRY_RUN )) && warn "DRY RUN: this shows the CURRENT state, not the result."
want_ver=$(pkg_version "$NEWPREFIX/lib/node_modules/@openai/codex")
PROBE='printf "@@codex=%s\n" "$(command -v codex)"; printf "@@ver=%s\n" "$(codex --version </dev/null 2>/dev/null | head -n1)"; printf "@@npm=%s\n" "$(command -v npm)"; printf "@@prefix=%s\n" "$(npm prefix -g 2>/dev/null)"'
fails=0
check() { # $1 label, $2 strict(1)/report(0), rest = command
    local label=$1 strict=$2; shift 2
    local out c v n pf verdict
    # setsid: a child "bash -i" outside the terminal's foreground group would
    # stop itself on SIGTTIN and ignore timeout's SIGTERM (hang). -k: hard kill.
    # PATH is passed in on purpose: every real shell inherits an exported PATH,
    # and a .bashrc that edits PATH without `export` (path_prepend-style) only
    # reaches child processes such as npm's `#!/usr/bin/env node` if it was.
    out=$(setsid -w timeout -k 5 90 env -i HOME="$HOME" USER="${USER:-}" TERM="${TERM:-xterm}" \
        PATH="/usr/local/bin:/usr/bin:/bin" "$@" 2>/dev/null </dev/null)
    c=$(sed -n 's/^@@codex=//p' <<<"$out"); v=$(sed -n 's/^@@ver=//p' <<<"$out")
    n=$(sed -n 's/^@@npm=//p' <<<"$out");   pf=$(sed -n 's/^@@prefix=//p' <<<"$out")
    if (( DRY_RUN )); then verdict=NOW
    elif [[ -n "$want_ver" && "$v" == *"$want_ver"* && "$pf" == "$NEWPREFIX" \
            && ( "$c" == "$LBIN/codex" || "$c" == "$NEWBIN/codex" ) ]]; then verdict=OK
    elif (( strict )); then verdict=FAIL; fails=$((fails+1)); else verdict=NOTE; fi
    printf '  %-4s %-30s codex=%s (%s)\n       %-30s npm=%s prefix=%s\n' "$verdict" "$label" "${c:-none}" "${v:-no output}" "" "${n:-none}" "${pf:-none}"
}
check "new terminal (base)"        1 bash -ic "$PROBE"
first_env=""
for pre in "${PREFIXES[@]}"; do
    [[ "$pre" == "$CROOT" ]] && continue
    e=${pre##*/}; [[ -n "$first_env" ]] || first_env=$e
    check "conda activate $e"      1 bash -ic "conda activate $e >/dev/null 2>&1; $PROBE"
done
[[ -n "$first_env" ]] && check "deactivate+activate $first_env" 0 bash -ic "conda deactivate; conda deactivate; conda activate $first_env >/dev/null 2>&1; $PROBE"
check "login shell (bash -lc)"     1 bash -lc "$PROBE"
check "ssh-style (non-interactive)" 1 bash -c ". \"\$HOME/.bashrc\" >/dev/null 2>&1; $PROBE"
dangling=$(find "$LBIN" -maxdepth 1 -xtype l -lname "$NVM_DIR/*" -printf '%f -> %l\n' 2>/dev/null)
if [[ -n "$dangling" ]]; then
    while IFS= read -r d; do
        if (( DRY_RUN )); then printf '  NOW  dangling link: %s\n' "$d"
        else printf '  FAIL dangling link: %s\n' "$d"; fails=$((fails+1)); fi
    done <<<"$dangling"
else
    printf '  OK   no dangling ~/.local/bin links into %s\n' "$NVM_DIR"
fi
info "expected: codex ${want_ver:-?} from the nvm copy, npm prefix $NEWPREFIX"
info "NOTE rows are informational: after 'conda deactivate' + 'conda activate X', X's own bin goes in"
info "front of ~/.local/bin, so that env's npm (if it has one) would be the one 'codex update' uses."

say "Done"
if (( DRY_RUN )); then info "Dry run finished. Re-run without --dry-run to apply."
elif (( fails )); then die "$fails verification check(s) failed. Paste the output above to Claude."
else ok "All checks passed. Open a NEW terminal to pick up the changes."; fi
info "log: $LOG"
