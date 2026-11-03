import os
import json
import re
from collections import Counter

base_dir = os.path.dirname(os.path.abspath(__file__))

def refine_topic_category(category_cn, category_en, title, structure, tags):
    full_text = f"{category_cn} {category_en} {title} {structure} {' '.join(tags)}".lower()
    
    # 1. Passive
    if '被' in category_cn or any(k in full_text for k in ['passive', '被动', '“被”字句', '叫', '让']):
        if any(k in full_text for k in ['passive', '被动', '“被”字句']) or '被' in structure:
            return 'passive', 'Câu bị động (被动句)'
            
    # 2. Comparison
    if '比较' in category_cn or any(k in full_text for k in ['comparison', 'comparative', 'comparing', '比较句', '比']) and any(k in structure for k in ['比', '一样', '不如', '越来越', '越']):
        return 'comparison', 'Câu so sánh (比较句)'
    if any(k in full_text for k in ['comparing', 'comparison', 'comparative']):
        return 'comparison', 'Câu so sánh (比较句)'

    # 3. Ba sentence
    if '“把”字句' in full_text or 'ba sentence' in full_text or ' 把 ' in f" {structure} ":
        return 'ba_sentence', 'Câu chữ 把 (把字句)'

    # 4. Complement
    if '补语' in category_cn or any(k in full_text for k in ['complement', '补语', 'expressing result']):
        return 'complement', 'Câu bổ ngữ (补语)'

    # 5. Conditionals
    if any(k in full_text for k in ['conditional', '条件', '假设', 'if...then', '只要', '只有', '如果', '要是']):
        return 'conditional', 'Câu điều kiện & giả thiết (条件与假设)'

    # 6. Conjunctions & Multi-clause
    if any(k in category_cn for k in ['连词', '复句']) or any(k in full_text for k in [
        'conjunction', '连词', 'multi-clause', 'connecting ideas', 'giving alternatives', 
        'indicating cause and effect', 'because', 'although', '不但', '而且', '虽然', '但是', '因为', '所以'
    ]):
        return 'conjunction', 'Liên từ & câu phức (连词与复句)'

    # 7. Particles
    if any(k in category_cn for k in ['助词']) or any(k in full_text for k in [
        'particle', '助词', 'structural particle', 'aspect particle', 'modal particle',
        'expressing actions in progress with "zai"', 'change of state with "le"', 'completed action with "le"',
        'experiences with "guo"', 'action in progress with "zhe"'
    ]):
        return 'particle', 'Trợ từ (助词: 的, 地, 得, 了, 过, 着, 吗, 呢, 吧)'
    # Also check if title mentions particle directly
    if any(f'"{p}"' in title for p in ['de', 'le', 'guo', 'zhe', 'ma', 'ne', 'ba', 'a']):
        return 'particle', 'Trợ từ (助词: 的, 地, 得, 了, 过, 着, 吗, 呢, 吧)'

    # 8. Prepositions
    if any(k in category_cn for k in ['介词']) or any(k in full_text for k in [
        'preposition', '介词', 'indicating location with "zai"', 'direction with "wang"',
        'expressing location with "zai"'
    ]):
        return 'preposition', 'Giới từ (介词: 在, 从, 往, 跟, 对, 向, 给, 离...)'

    # 9. Adverbs
    if any(k in category_cn for k in ['副词']) or any(k in full_text for k in [
        'adverb', '副词', 'expressing degree', 'negating', 'denying and refusing', 
        'the "all" adverb "dou"', 'the "also" adverb "ye"', 'intensifier'
    ]):
        return 'adverb', 'Phó từ (副词: 也, 都, 很, 太, 不, 没, 就, 才, 已经...)'

    # 10. Modal verbs
    if any(k in category_cn for k in ['能愿动词']) or any(k in full_text for k in ['modal verb', '能愿动词', 'auxiliary verb']):
        return 'modal_verb', 'Động từ năng nguyện (能愿动词: 会, 能, 可以, 想, 要, 应该...)'

    # 11. Separable verbs
    if any(k in category_cn for k in ['离合词']) or any(k in full_text for k in ['separable verb', '离合词']):
        return 'separable_verb', 'Từ ly hợp (离合词: 睡觉, 唱歌, 跳舞, 帮忙...)'

    # 12. Word parts
    if any(k in category_cn for k in ['语素']) or any(k in full_text for k in ['word parts', 'prefix', 'suffix', '语素', 'affix']):
        return 'word_part', 'Ngữ tố (语素: 前缀, 后缀)'

    # 13. Pronouns
    if any(k in category_cn for k in ['代词']) or any(k in full_text for k in ['pronoun', '代词']):
        return 'pronoun', 'Đại từ (代词: 人称, 指示, 疑问)'

    # 14. Measure words
    if any(k in category_cn for k in ['量词']) or any(k in full_text for k in ['measure word', '量词', 'classifier', 'counting']):
        return 'measure_word', 'Lượng từ (量词)'

    # 15. Special sentence patterns
    if any(k in category_cn for k in ['特殊句型', '句型', '句类']) or any(k in full_text for k in [
        'sentence pattern', 'sentence structure', '特殊句型', '存现句', '连动句', '兼语句', '是……的', '“是”字句'
    ]):
        return 'special_sentence', 'Cấu trúc câu đặc biệt (特殊句型)'

    return 'other', 'Cấu trúc & Cụm từ khác (其他固定结构)'

with open(os.path.join(base_dir, 'processed', 'grammar_all.json'), 'r', encoding='utf-8') as f:
    items = json.load(f)

counts = Counter()
for it in items:
    cat, name = refine_topic_category(
        it.get('category_chinese', ''),
        it.get('category_english', ''),
        it.get('title', ''),
        it.get('structure', ''),
        it.get('category_english', '').split(',')
    )
    counts[cat] += 1

print("New Category Distribution:")
for c, cnt in counts.most_common():
    print(f"  {c}: {cnt}")
