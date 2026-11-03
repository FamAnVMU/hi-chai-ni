import urllib.request
import json
import os

url_graphics = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt"
url_dict = "https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt"

print("Checking graphics.txt...")
req = urllib.request.Request(url_graphics, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=15) as resp:
    for i in range(3):
        line = resp.readline().decode('utf-8')
        d = json.loads(line)
        print("Sample character:", d.get("character"), "Strokes count:", len(d.get("strokes", [])))
        if i == 0:
            print("First stroke sample:", d.get("strokes", [])[0][:60], "...")
            print("First median sample:", d.get("medians", [])[0][:3], "...")

print("\nChecking dictionary.txt...")
req2 = urllib.request.Request(url_dict, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req2, timeout=15) as resp:
    for i in range(3):
        line = resp.readline().decode('utf-8')
        d = json.loads(line)
        print("Dict sample:", d.get("character"), "Pinyin:", d.get("pinyin"), "Radical:", d.get("radical"), "Decomp:", d.get("decomposition"))
