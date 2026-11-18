#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
meta="$(cd "$(dirname "$0")" && pwd -P)"
if [ "$#" -ne 1 ]; then
    echo "Usage: bash backup/restore.sh DESTINATION" >&2
    exit 2
fi
mkdir -p "$1"
dest="$(cd "$1" && pwd -P)"
archive="$(awk 'NF {print $2; exit}' "$meta/archive.sha256")"
project=ai-video-1118-astra
for name in "$archive" "$project"; do
    if [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; then
        echo "Destination already contains $name. Choose a fresh location to preserve it." >&2
        exit 1
    fi
done
sandbox="$(mktemp -d "$dest/.avis3-restore.XXXXXX")"
trap 'rm -rf "$sandbox"' EXIT
trap 'exit 1' HUP INT TERM
store="$sandbox/parts"
git init --quiet "$store"
commit="$(cat "$meta/parts-commit")"
url="${SNAPSHOT_GIT_URL:-https://github.com/liuyinchu/ai-video-avis3-arena-plus-1118.git}"
git -C "$store" -c core.autocrlf=false fetch --quiet --no-tags --depth=1 "$url" "$commit"
git -C "$store" -c core.autocrlf=false checkout --quiet --detach FETCH_HEAD
test "$(git -C "$store" rev-parse HEAD)" = "$commit"
check_sums() {
    if command -v sha256sum >/dev/null; then sha256sum -c "$1"; else shasum -a 256 -c "$1"; fi
}
(
    cd "$store"
    check_sums "$meta/parts.sha256"
    cat parts/part-[0-9][0-9][0-9][0-9] > "$sandbox/$archive"
)
(
    cd "$sandbox"
    check_sums "$meta/archive.sha256"
)
mkdir "$sandbox/extracted"
# Keep POSIX modes, empty directories and the original PAX modification times.
tar_args=(-xpf - --no-same-owner -C "$sandbox/extracted")
if tar --version 2>/dev/null | grep -q 'GNU tar'; then
    tar_args=(--warning=no-unknown-keyword --delay-directory-restore "${tar_args[@]}")
fi
zstd -q -dc "$sandbox/$archive" | tar "${tar_args[@]}"
# Some tar implementations update an already-restored directory when a later entry creates children.
# Restore the archived directory times after all members have landed, then independently inventory the tree.
ruby -EUTF-8 -rjson - "$meta/project-files.json" "$sandbox/extracted/$project" <<'TIMES'
rows=JSON.parse(File.read(ARGV[0])).fetch('entries')
root=ARGV[1]
rows.select { |r| r.fetch('type')=='directory' }.each do |r|
  path=File.join(root,r.fetch('path'))
  stat=File.lstat(path)
  abort "Expected directory: #{path}" unless stat.directory?
  sec,nsec=r.fetch('mtime_ns').divmod(1_000_000_000)
  if stat.mtime.to_i!=sec || stat.mtime.nsec!=nsec
    File.utime(stat.atime,Time.at(sec,nsec,:nanosecond),path)
  end
end
TIMES
ruby -EUTF-8 "$meta/inventory.rb" "$sandbox/extracted/$project" --with-mtime > "$sandbox/restored.json"
ruby -EUTF-8 -rjson - "$meta/project-files.json" "$sandbox/restored.json" <<'RUBY'
expected, actual = ARGV.map { |p| JSON.parse(File.read(p)) }
unless expected == actual
  e = expected.fetch('entries').map { |v| [v.fetch('path'),v] }.to_h
  a = actual.fetch('entries').map { |v| [v.fetch('path'),v] }.to_h
  diff = (e.keys | a.keys).select { |p| e[p] != a[p] }
  different=diff.first(8).map { |p| [p,(e[p]||{}).keys.select { |k| !a[p] || e[p][k]!=a[p][k] }] }
  abort "Restored-tree mismatch: #{different.inspect}"
end
entries=actual.fetch('entries')
puts "Verified #{entries.count { |e| e['type']=='file' }} files and #{entries.count { |e| e['type']=='directory' }} directories, including SHA-256, permissions and mtimes."
RUBY
mv "$sandbox/$archive" "$dest/$archive"
mv "$sandbox/extracted/$project" "$dest/$project"
