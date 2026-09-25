"""PokeAPI 종 이름 CSV에서 [id, 영어, 한국어, 일본어] 사전을 만들어 index.html에 넣는다.
사용: python3 build_names.py  (네트워크 필요)"""
import csv, io, json, re, urllib.request, pathlib

URL = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_species_names.csv"
LANG = {9: "en", 3: "ko", 1: "ja"}  # 9=English, 3=Korean, 1=ja-Hrkt(가타카나)

rows = csv.DictReader(io.StringIO(urllib.request.urlopen(URL).read().decode("utf-8")))
names = {}
for r in rows:
    lang = LANG.get(int(r["local_language_id"]))
    if lang:
        names.setdefault(int(r["pokemon_species_id"]), {})[lang] = r["name"]

table = [[i, n.get("en", ""), n.get("ko", ""), n.get("ja", "")] for i, n in sorted(names.items()) if n.get("en")]
html = pathlib.Path(__file__).with_name("index.html")
src = html.read_text(encoding="utf-8")
line = "const NAMES = " + json.dumps(table, ensure_ascii=False, separators=(",", ":")) + ";"
src, n = re.subn(r"^const NAMES = .*;$", lambda _: line, src, count=1, flags=re.M)
assert n == 1, "index.html에 'const NAMES = ...;' 줄이 없습니다"
html.write_text(src, encoding="utf-8")
print(f"{len(table)}종 기록")
