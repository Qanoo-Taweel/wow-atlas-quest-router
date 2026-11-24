#!/usr/bin/env bash
# Regenerates tests/fixtures/*.java.txt with the ORIGINAL Java ATLAS
# (github.com/savastakan/atlas). Requires git + a JDK.
#   tools/java_reference.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
git clone --depth 1 https://github.com/savastakan/atlas "$WORK/atlas" >/dev/null 2>&1
cat > "$WORK/atlas/RefMain.java" <<'JAVA'
public class RefMain {
    public static void main(String[] args) throws Exception {
        Graph graph = new Util().toGraph(args[0]);
        System.out.println(new Atlas().run(graph));
    }
}
JAVA
(cd "$WORK/atlas" && javac -nowarn -d out Atlas.java Edge.java Graph.java Util.java RefMain.java)
for fsm in "$ROOT"/tests/fixtures/*.fsm; do
    java -cp "$WORK/atlas/out" RefMain "$fsm" 2>/dev/null > "${fsm%.fsm}.java.txt"
    echo "wrote ${fsm%.fsm}.java.txt"
done
rm -rf "$WORK"
