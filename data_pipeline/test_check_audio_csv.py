import urllib.request

url = "https://downloads.tatoeba.org/exports/sentences_with_audio.csv"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Range": "bytes=0-1024"})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        print("Header sample:")
        print(resp.read().decode('utf-8'))
except Exception as e:
    print("Error:", e)
