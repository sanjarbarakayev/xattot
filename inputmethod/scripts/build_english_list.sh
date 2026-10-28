#!/bin/bash
# Builds Resources/english-words.txt and Resources/SCOWL-COPYRIGHT.txt from SCOWL.
# Also writes build/uzbek-exception-candidates.txt for hand review into Resources/uzbek-exceptions.txt.
set -euo pipefail

SCOWL_VERSION="2020.12.07"
SCOWL_URL="https://downloads.sourceforge.net/wordlist/scowl-${SCOWL_VERSION}.tar.gz"
EXPECTED_SHA256="5587667caa20c4891390c2d42dbb4d5c4c3f41bee77af1457ece3ba23fb859cc"

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

archive="$work/scowl.tar.gz"
python3 -I -c '
import sys, urllib.request
urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
' "$SCOWL_URL" "$archive"

actual="$(shasum -a 256 "$archive" | cut -d" " -f1)"
echo "SCOWL archive SHA-256: $actual"
if [ -z "$EXPECTED_SHA256" ]; then
    echo "No SHA-256 recorded in this script yet; record the value above in EXPECTED_SHA256." >&2
    exit 1
fi
if [ "$actual" != "$EXPECTED_SHA256" ]; then
    echo "SHA-256 mismatch: expected $EXPECTED_SHA256" >&2
    exit 1
fi

mkdir "$work/src"
tar -xzf "$archive" -C "$work/src"
scowl="$work/src/scowl-${SCOWL_VERSION}"

mkdir -p "$root/Resources" "$root/build"

# Sizes 10-50 cover common words and drop the rare tail that would catch Uzbek by accident.
# Contractions (don't, can't, I'm) live in separate lists; not every set has every size.
for kind in words contractions; do
    for set in english american british; do
        for size in 10 20 35 40 50; do
            file="$scowl/final/${set}-${kind}.${size}"
            if [ -f "$file" ]; then
                cat "$file"
            elif [ "$kind" = words ]; then
                echo "missing $file" >&2
                exit 1
            fi
        done
    done
done | iconv -f ISO-8859-1 -t UTF-8 | LC_ALL=C grep -E "^[A-Za-z']+$" | LC_ALL=C sort -u \
    > "$root/Resources/english-words.txt"

cp "$scowl/Copyright" "$root/Resources/SCOWL-COPYRIGHT.txt"

python3 -I - "$root/Resources/english-words.txt" "$root/build/uzbek-exception-candidates.txt" \
    "$root/Resources/uzbek-exceptions.txt" <<'PY'
import sys

src, dst, known_file = sys.argv[1], sys.argv[2], sys.argv[3]
with open(known_file, encoding="utf-8") as f:
    known = {line.strip() for line in f if line.strip() and not line.startswith("#")}
digraphs = {("c", "h"): "ç", ("s", "h"): "ş", ("o", "'"): "ö", ("g", "'"): "ğ"}


def convert(word):
    """The word as the eager engine leaves it, or None when the word is foreign (w, or c without h)."""
    low = word.lower()
    out, i = [], 0
    while i < len(low):
        c = low[i]
        if c == "w":
            return None
        pair = (c, low[i + 1]) if i + 1 < len(low) else None
        if pair in digraphs:
            out.append(digraphs[pair])
            i += 2
            continue
        if c == "c":
            return None
        out.append(c)
        i += 1
    return "".join(out)


found = {}
with open(src, encoding="utf-8") as f:
    for line in f:
        word = line.strip().lower()
        if word.endswith("'s"):
            continue
        converted = convert(word)
        if converted and any(ch in converted for ch in "çşöğ"):
            found[word] = converted

# Shortest first: short words are the likely Uzbek ones. "listed" marks entries already in the exceptions file.
candidates = sorted(found.items(), key=lambda item: (len(item[0]), item[0]))
rows = [f"{converted}\t{word}\t{'listed' if converted in known else ''}".rstrip() for word, converted in candidates]
with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
print("\n".join(rows))
print(f"{len(candidates)} candidates written to {dst}", file=sys.stderr)
PY

echo "english-words.txt: $(wc -l < "$root/Resources/english-words.txt" | tr -d ' ') words"
