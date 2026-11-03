import os
import json
from collections import Counter

base_dir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(base_dir, 'processed', 'grammar_all.json'), 'r', encoding='utf-8') as f:
    items = json.load(f)

others = [it for it in items if it['topic_category'] == 'other']
print("Total 'other':", len(others))
print("Sample 'other' items (first 25):")
for it in others[:25]:
    print(f"  [{it['source'][:6]}] {it['title']} | struct: {it['structure'][:30]} | cat: {it.get('category_chinese')}")

# Check tags in Wiki points
wiki_tags = Counter()
for it in items:
    if it.get('category_english'):
        for tag in it['category_english'].split(','):
            wiki_tags[tag.strip()] += 1

print("\nTop Wiki tags:")
for t, c in wiki_tags.most_common(30):
    print(f"  {t}: {c}")
