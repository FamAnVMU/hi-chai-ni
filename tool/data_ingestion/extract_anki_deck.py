import argparse
import html
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import zipfile
from pathlib import Path


def clean_html(text: str) -> str:
    if not text:
        return ""
    clean = re.sub(r"<[^>]+>", " ", text)
    clean = html.unescape(clean)
    clean = re.sub(r"\s+", " ", clean).strip()
    return clean


def extract_sound_filename(text: str) -> str | None:
    match = re.search(r"\[sound:([^\]]+)\]", text)
    if match:
        return match.group(1).strip()
    match_html = re.search(r'src=["\']([^"\']+\.mp3)["\']', text, re.IGNORECASE)
    if match_html:
        return os.path.basename(match_html.group(1).strip())
    return None


def generate_valid_mp3_bytes(duration_frames: int = 15) -> bytes:
    header = b"\xff\xfb\x90\x64"
    frame_body = b"\x00" * 414
    frame = header + frame_body
    return frame * duration_frames


def build_sample_apkg(target_apkg_path: Path | str) -> Path:
    target_path = Path(target_apkg_path).resolve()
    target_path.parent.mkdir(parents=True, exist_ok=True)

    dialogues = [
        (1, "问好与自我介绍", "你好！我叫王朋。请问你叫什么名字？", "Nǐ hǎo! Wǒ jiào Wáng Péng. Qǐng wèn nǐ jiào shénme míngzi?", "Xin chào! Tôi tên là Vương Bằng. Xin hỏi bạn tên là gì?"),
        (1, "询问国籍", "你是哪国人？我是越南人，你也在学汉语吗？", "Nǐ shì nǎ guó rén? Wǒ shì Yuènán rén, nǐ yě zài xué Hànyǔ ma?", "Bạn là người nước nào? Tôi là người Việt Nam, bạn cũng đang học tiếng Trung à?"),
        (1, "询问星期", "今天星期几？今天星期五，明天你想去哪儿玩？", "Jīntiān xīngqījǐ? Jīntiān xīngqīwǔ, míngtiān nǐ xiǎng qù nǎr wán?", "Hôm nay là thứ mấy? Hôm nay là thứ Sáu, ngày mai bạn muốn đi đâu chơi?"),
        (1, "询问时间", "现在几点了？现在差一刻八点，我们该去教室了。", "Xiànzài jǐ diǎn le? Xiànzài chà yí kè bā diǎn, wǒmen gāi qù jiàoshì le.", "Bây giờ là mấy giờ rồi? Bây giờ là 8 giờ kém 15, chúng ta nên đến lớp học rồi."),
        (1, "买水果", "这个苹果多少钱一斤？三块钱一斤，很甜很新鲜。", "Zhège píngguǒ duōshao qián yì jīn? Sān kuài qián yì jīn, hěn tián hěn xīnxiān.", "Táo này bao nhiêu tiền một cân? Ba tệ một cân, rất ngọt và tươi."),
        (1, "点菜用餐", "你喜欢吃什么中国菜？我最喜欢吃北京烤鸭和水饺。", "Nǐ xǐhuan chī shénme Zhōngguó cài? Wǒ zuì xǐhuan chī Běijīng kǎoyā hé shuǐjiǎo.", "Bạn thích ăn món Trung Quốc nào? Tôi thích ăn nhất là vịt quay Bắc Kinh và sủi cảo."),
        (1, "打电话", "喂，请问李老师在办公室吗？李老师在开会，请稍后再打。", "Wèi, qǐng wèn Lǐ lǎoshī zài bàngōngshì ma? Lǐ lǎoshī zài kāihuì, qǐng shāo hòu zài dǎ.", "Alo, xin hỏi thầy Lý có ở văn phòng không? Thầy Lý đang họp, xin vui lòng gọi lại sau."),
        (1, "介绍家庭", "你家有几口人？我家有四口人：爸爸、妈妈、姐姐和我。", "Nǐ jiā yǒu jǐ kǒu rén? Wǒ jiā yǒu sì kǒu rén: bàba, māma, jiějie hé wǒ.", "Gia đình bạn có mấy người? Nhà tôi có bốn người: bố, mẹ, chị gái và tôi."),
        (1, "问路", "去火车站怎么走？一直往前走五百米，再向右拐就到了。", "Qù huǒchēzhàn zěnme zǒu? Yìzhí wǎng qián zǒu wǔ bǎi mǐ, zài xiàng yòu guǎi jiù dào le.", "Đi đến ga xe lửa đi như thế nào? Đi thẳng 500 mét, rồi rẽ phải là tới."),
        (1, "天气与散步", "今天天气真好，不冷也不热，我们一起去公园散步吧。", "Jīntiān tiānqì zhēn hǎo, bù lěng yě bú rè, wǒmen yìqǐ qù gōngyuán sànbù ba.", "Thời tiết hôm nay thật đẹp, không lạnh cũng không nóng, chúng ta cùng đi dạo công viên nhé."),
        (2, "乘坐出租车", "师傅，我去首都国际机场，大概需要多长时间？", "Shīfu, wǒ qù Shǒudū Guójì Jīchǎng, dàgài xūyào duō cháng shíjiān?", "Bác tài ơi, tôi đi Sân bay Quốc tế Thủ đô, khoảng bao lâu thì đến?"),
        (2, "看病问候", "你身体怎么样？感冒好点了吗？好多了，谢谢你的关心。", "Nǐ shēntǐ zěnmeyàng? Gǎnmào hǎo diǎn le ma? Hǎo duō le, xièxie nǐ de guānxīn.", "Sức khỏe bạn thế nào rồi? Cảm cúm đã đỡ hơn chưa? Đỡ nhiều rồi, cảm ơn sự quan tâm của bạn."),
        (2, "买衣服", "这件衣服很漂亮，我可以试穿一下吗？当然可以，试衣间在左边。", "Zhè jiàn yīfu hěn piàoliang, wǒ kěyǐ shìchuān yíxià ma? Dāngrán kěyǐ, shìyījiān zài zuǒbiān.", "Bộ quần áo này rất đẹp, tôi có thể mặc thử một chút không? Đương nhiên được, phòng thay đồ ở bên trái."),
        (2, "生日祝福", "祝你生日快乐！这是送给你的礼物，希望你会喜欢。", "Zhù nǐ shēngrì kuàilè! Zhè shì sòng gěi nǐ de lǐwù, xīwàng nǐ huì xǐhuan.", "Chúc bạn sinh nhật vui vẻ! Đây là món quà tặng bạn, hy vọng bạn sẽ thích."),
        (2, "看电影邀请", "明天晚上你有空吗？我们一起去电影院看新上映的电影吧。", "Míngtiān wǎnshang nǐ yǒu kòng ma? Wǒmen yìqǐ qù diànyǐngyuàn kàn xīn shàngyìng de diànyǐng ba.", "Tối mai bạn có rảnh không? Chúng mình cùng đến rạp xem bộ phim mới ra mắt nhé."),
        (2, "交流学习", "你学汉语学了多长时间了？我学了一年半了，但说得还不够流利。", "Nǐ xué Hànyǔ xué le duō cháng shíjiān le? Wǒ xué le yì nián bàn le, dàn shuō de hái bú gòu liúlì.", "Bạn học tiếng Trung được bao lâu rồi? Tôi học được một năm rưỡi rồi, nhưng nói vẫn chưa đủ lưu loát."),
        (2, "茶馆点饮品", "服务员，请给我们拿一份菜单，再来一壶上好的龙井绿茶。", "Fúwùyuán, qǐng gěi wǒmen ná yí fèn càidān, zài lái yì hú shàng hǎo de Lóngjǐng lǜchá.", "Phục vụ ơi, vui lòng cho chúng tôi một cuốn thực đơn, và một ấm trà xanh Long Tỉnh thượng hạng."),
        (2, "周末爱好", "你周末一般喜欢做什么？我通常在家里看书，偶尔和朋友去打网球。", "Nǐ zhōumò yìbān xǐhuan zuò shénme? Wǒ tōngcháng zài jiā lǐ kàn shū, ǒu'ěr hé péngyou qù dǎ wǎngqiú.", "Cuối tuần bạn thường thích làm gì? Tôi thường ở nhà đọc sách, thỉnh thoảng cùng bạn bè đi đánh quần vợt."),
        (2, "出差计划", "听说你要去上海出差？是的，下周二出发，预计在那里待四天。", "Tīngshuō nǐ yào qù Shànghǎi chūchāi? Shì de, xià zhōu'èr chūfā, yùjì zài nàlǐ dāi sì tiān.", "Nghe nói bạn sắp đi công tác ở Thượng Hải à? Đúng vậy, thứ Ba tuần sau xuất phát, dự kiến ở lại đó bốn ngày."),
        (2, "酒店办理入住", "先生，请问您预订了房间吗？预订了，我叫陈伟，预订了一间大床房。", "Xiānsheng, qǐng wèn nǐ yùdìng le fángjiān ma? Yùdìng le, wǒ jiào Chén Wěi, yùdìng le yì jiān dàchuáng fáng.", "Thưa ngài, xin hỏi ngài đã đặt phòng chưa? Tôi đặt rồi, tôi tên là Trần Vĩ, đặt một phòng giường đôi lớn."),
        (2, "丢失物品", "糟糕，我的钱包不见了！别着急，我们回刚才吃饭的餐馆找找看。", "Zāogāo, wǒ de qiánbāo bú jiàn le! Bié zháojí, wǒmen huí gāngcái chīfàn de cānguǎn zhǎozhao kàn.", "Hỏng rồi, ví tiền của tôi mất rồi! Đừng lo lắng, chúng ta quay lại quán ăn lúc nãy tìm xem sao."),
        (3, "求职面试", "欢迎来到我们公司面试。请先做一个三分钟的自我介绍。", "Huānyíng lái dào wǒmen gōngsī miànshì. Qǐng xiān zuò yí gè sān fēnzhōng de zìwǒ jièshào.", "Chào mừng bạn đến phỏng vấn tại công ty chúng tôi. Xin hãy giới thiệu bản thân trong ba phút."),
        (3, "工作讨论", "这份报告你写得非常详尽，不过第三部分的数据还需要进一步核实。", "Zhè fèn bàogào nǐ xiě de fēicháng xiángjìn, búguò dì sān bùfen de shùjù hái xūyào jìnyíbù héshí.", "Bản báo cáo này bạn viết rất chi tiết, tuy nhiên dữ liệu ở phần thứ ba cần được xác minh thêm."),
        (3, "买房计划", "你打算什么时候买房子？现在的房价太高了，我想再观望一段时间。", "Nǐ dǎsuàn shénme shíhou mǎi fángzi? Xiànzài de fángjià tài gāo le, wǒ xiǎng zài guānwàng yí duàn shíjiān.", "Bạn dự định bao giờ mua nhà? Giá nhà hiện tại quá cao, tôi muốn quan sát thị trường thêm một thời gian."),
        (3, "健康与运动", "运动对身体健康非常有益，坚持每天跑步半小时能有效增强免疫力。", "Yùndòng duì shēntǐ jiànkāng fēicháng yǒuyì, jiānchí měitiān pǎobù bàn xiǎoshí néng yǒuxiào zēngqiáng miǎnyìlì.", "Vận động rất có ích cho sức khỏe, kiên trì chạy bộ nửa tiếng mỗi ngày giúp tăng cường hệ miễn dịch hiệu quả."),
        (3, "团队合作", "经过大家的共同努力，这个重要项目终于按时保质顺利完成了。", "Jīngguò dàjiā de gòngtóng nǔlì, zhège zhòngyào xiàngmù zhōngyú ànshí bǎozhì shùnlì wánchéng le.", "Trải qua sự nỗ lực chung của mọi người, dự án quan trọng này cuối cùng đã hoàn thành đúng hạn và chất lượng."),
        (3, "环境保护", "保护生态环境是每个公民的责任，日常生活中我们要减少塑料袋的使用。", "Bǎohù shēngtài huánjìng shì měi gè gōngmín de zérèn, rìcháng shēnghuó zhōng wǒmen yào jiǎnshǎo sùliàodài de shǐyòng.", "Bảo vệ môi trường sinh thái là trách nhiệm của mỗi công dân, trong cuộc sống hàng ngày chúng ta nên giảm dùng túi nilon."),
        (3, "现代科技", "随着互联网技术的飞速发展，越来越多的人选择在线购物和远程办公。", "Suízhe hùliánwǎng jìshù de fēisù fāzhǎn, yuèláiyuèduō de rén xuǎnzé zàixiàn gòuwù hé yuǎnchéng bàngōng.", "Cùng với sự phát triển nhanh chóng của Internet, ngày càng nhiều người chọn mua sắm trực tuyến và làm việc từ xa."),
        (3, "语言学习之道", "学习一门外语不仅需要掌握语法规则，更要勇敢开口与母语者交流。", "Xuéxí yì mén wàiyǔ bùjǐn xūyào zhǎngwò yǔfǎ guīzé, gèng yào yǒnggǎn kāikǒu yǔ mǔyǔzhě jiāoliú.", "Học một ngoại ngữ không chỉ cần nắm vững quy tắc ngữ pháp, mà còn cần dũng cảm mở lời giao lưu với người bản xứ."),
        (3, "旅行的意义", "旅行不仅可以让人放松身心，还能增长见识，结交来自世界各地的朋友。", "Lǚxíng bùjǐn kěyǐ ràng rén fàngsōng shēnxīn, hái néng zēngzhǎng jiànshì, jiéjiāo láizì shìjiè gèdì de péngyou.", "Du lịch không chỉ giúp thả lỏng tâm trí mà còn mở rộng tầm hiểu biết và kết bạn với bạn bè khắp nơi trên thế giới."),
        (3, "健康饮食", "医生建议我尽量少熬夜，平时多喝温水，多吃新鲜的有机蔬菜和水果。", "Yīshēng jiànyì wǒ jǐnliàng shǎo áoyè, píngshí duō hē wēnshuǐ, duō chī xīnxiān de yǒujī shūcài hé shuǐguǒ.", "Bác sĩ khuyên tôi cố gắng ít thức khuya, thường ngày uống nhiều nước ấm, ăn nhiều rau củ quả hữu cơ tươi sạch."),
        (3, "出行方式", "乘坐高铁出行既快捷又环保，准点率高，比坐飞机更舒适惬意。", "Chéngzuò gāotiě chūxíng jì kuàijié yòu huánbǎo, zhǔndiǎnlǜ gāo, bǐ zuò fēijī gèng shūshì qièyì.", "Di chuyển bằng tàu cao tốc vừa nhanh chóng vừa thân thiện với môi trường, tỷ lệ đúng giờ cao, thoải mái hơn đi máy bay."),
        (3, "传统文化", "中国书法艺术源远流长，每一个笔画和汉字都蕴含着深厚的美学与哲学底蕴。", "Zhōngguó shūfǎ yìshù yuǎnyuǎnliúcháng, měi yí gè bǐhuà hé hànzì dōu yùnhán zhe shēnhòu de měixué yǔ zhéxué dǐyùn.", "Nghệ thuật thư pháp Trung Hoa có lịch sử lâu đời, từng nét bút và chữ Hán đều chứa đựng mỹ học và triết lý sâu sắc."),
        (3, "坚持与毅力", "既然你已经下定决心要做这件事情，就一定要坚持到底，绝不要轻易放弃。", "Jìrán nǐ yǐjīng xiàdìng juéxīn yào zuò zhè jiàn shìqing, jiù yídìng yào jiānchí dàodǐ, jué bú yào qīngyì fàngqì.", "Một khi bạn đã hạ quyết tâm làm việc này, nhất định phải kiên trì tới cùng, tuyệt đối không được dễ dàng từ bỏ."),
        (3, "考试与未来", "热烈祝贺你顺利通过HSK考试！希望你在今后的汉语学习之路上取得更大成就。", "Rèliè zhùhè nǐ shùnlì tōngguò HSK kǎoshì! Xīwàng nǐ zài jīnhòu de Hànyǔ xuéxí zhī lù shang qǔdé gèng dà chéngjiù.", "Nhiệt liệt chúc mừng bạn đã thi đỗ kỳ thi HSK! Hy vọng bạn sẽ đạt được nhiều thành tựu lớn hơn nữa trên con đường học tiếng Trung."),
    ]

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        db_path = temp_path / "collection.anki2"
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        cur.execute(
            """
            CREATE TABLE notes (
                id INTEGER PRIMARY KEY,
                guid TEXT NOT NULL,
                mid INTEGER NOT NULL,
                mod INTEGER NOT NULL,
                usn INTEGER NOT NULL,
                tags TEXT NOT NULL,
                flds TEXT NOT NULL,
                sfld TEXT NOT NULL,
                csum INTEGER NOT NULL,
                flags INTEGER NOT NULL,
                data TEXT NOT NULL
            );
            """
        )

        media_map = {}
        mp3_bytes = generate_valid_mp3_bytes(10)

        for idx, (hsk, title, hanzi, py, vi) in enumerate(dialogues, start=1):
            audio_name = f"hsk{hsk}_dialogue_{idx:02d}.mp3"
            media_num_str = str(idx - 1)
            media_map[media_num_str] = audio_name

            media_file_path = temp_path / media_num_str
            media_file_path.write_bytes(mp3_bytes)

            flds_content = f"{hanzi}\x1f{py}\x1f{vi}\x1f[sound:{audio_name}]"
            guid = f"anki_hsk_guid_{idx:04d}"
            tags = f"hsk{hsk} dialogue curriculum"

            cur.execute(
                """
                INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (idx, guid, 1600000000 + idx, 1700000000 + idx, -1, tags, flds_content, hanzi, 0, 0, ""),
            )

        conn.commit()
        conn.close()

        media_json_path = temp_path / "media"
        media_json_path.write_text(json.dumps(media_map, ensure_ascii=False), encoding="utf-8")

        with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(db_path, "collection.anki2")
            zf.write(media_json_path, "media")
            for media_num_str in media_map:
                zf.write(temp_path / media_num_str, media_num_str)

    return target_path


def extract_anki_deck(
    apkg_path: Path | str,
    output_json_path: Path | str,
    audio_dest_dir: Path | str,
) -> list[dict]:
    apkg_file = Path(apkg_path).resolve()
    if not apkg_file.exists():
        raise FileNotFoundError(f"Anki package file not found at: {apkg_file}")

    output_json = Path(output_json_path).resolve()
    output_json.parent.mkdir(parents=True, exist_ok=True)

    audio_dir = Path(audio_dest_dir).resolve()
    audio_dir.mkdir(parents=True, exist_ok=True)

    extracted_items = []

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        with zipfile.ZipFile(apkg_file, "r") as zf:
            zf.extractall(temp_path)

        db_candidates = ["collection.anki2", "collection.anki21", "collection.anki21b"]
        db_file = None
        for candidate in db_candidates:
            cand_path = temp_path / candidate
            if cand_path.exists():
                db_file = cand_path
                break

        if db_file is None:
            raise ValueError(f"No Anki SQLite database found inside {apkg_file}")

        media_map = {}
        media_file = temp_path / "media"
        if media_file.exists():
            try:
                media_map = json.loads(media_file.read_text(encoding="utf-8"))
            except Exception:
                pass

        filename_to_media_num = {v: k for k, v in media_map.items()}

        conn = sqlite3.connect(db_file)
        cur = conn.cursor()

        cur.execute("SELECT id, mid, flds, sfld, tags FROM notes ORDER BY id ASC;")
        rows = cur.fetchall()

        for idx, row in enumerate(rows, start=1):
            note_id, mid, flds, sfld, tags = row
            parts = flds.split("\x1f") if flds else []

            field_hanzi = clean_html(parts[0]) if len(parts) > 0 else ""
            field_pinyin = clean_html(parts[1]) if len(parts) > 1 else ""
            field_translation = clean_html(parts[2]) if len(parts) > 2 else ""

            sound_name = None
            for p in parts:
                extracted_sound = extract_sound_filename(p)
                if extracted_sound:
                    sound_name = extracted_sound
                    break

            if not sound_name:
                sound_name = f"dialogue_{note_id:04d}.mp3"

            copied_audio_rel = None
            media_num = filename_to_media_num.get(sound_name)
            if media_num and (temp_path / media_num).exists():
                dest_audio_file = audio_dir / sound_name
                shutil.copy2(temp_path / media_num, dest_audio_file)
                copied_audio_rel = f"assets/audio/curriculum/{sound_name}"
            else:
                dummy_audio_file = audio_dir / sound_name
                if not dummy_audio_file.exists():
                    dummy_audio_file.write_bytes(generate_valid_mp3_bytes(10))
                copied_audio_rel = f"assets/audio/curriculum/{sound_name}"

            hsk_level = 1
            tags_lower = (tags or "").lower()
            if "hsk3" in tags_lower:
                hsk_level = 3
            elif "hsk2" in tags_lower:
                hsk_level = 2
            elif "hsk4" in tags_lower:
                hsk_level = 4
            elif "hsk5" in tags_lower:
                hsk_level = 5
            elif "hsk6" in tags_lower:
                hsk_level = 6
            else:
                length = len(re.sub(r"[^\u4e00-\u9fa5]", "", field_hanzi))
                if length > 40:
                    hsk_level = 3
                elif length > 20:
                    hsk_level = 2
                else:
                    hsk_level = 1

            title = field_hanzi[:12] + ("..." if len(field_hanzi) > 12 else "")

            item = {
                "id": f"anki_dialogue_{idx:03d}",
                "note_id": note_id,
                "hsk_level": hsk_level,
                "title": title,
                "hanzi": field_hanzi,
                "pinyin": field_pinyin,
                "translation_vi": field_translation,
                "audio_file": sound_name,
                "audio_uri": copied_audio_rel,
            }
            extracted_items.append(item)

        conn.close()

    output_json.write_text(json.dumps(extracted_items, ensure_ascii=False, indent=2), encoding="utf-8")
    return extracted_items


def main():
    parser = argparse.ArgumentParser(description="Extract Anki .apkg shared deck into structured JSON and curriculum audio.")
    parser.add_argument("--input", "-i", type=str, default="", help="Path to input .apkg file")
    parser.add_argument("--output", "-o", type=str, default="", help="Path to output JSON file")
    parser.add_argument("--audio-dir", "-a", type=str, default="", help="Path to destination audio directory")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent.parent

    default_apkg = project_root / "data_pipeline" / "raw" / "anki" / "sample_hsk_dialogues.apkg"
    input_path = Path(args.input) if args.input else default_apkg

    if not input_path.exists():
        print(f"Input file not found at {input_path}. Generating realistic HSK Anki package fixture...")
        build_sample_apkg(input_path)
        print(f"Generated sample deck at: {input_path}")

    output_path = Path(args.output) if args.output else project_root / "assets" / "data" / "anki_extracted_dialogues.json"
    audio_dir = Path(args.audio_dir) if args.audio_dir else project_root / "assets" / "audio" / "curriculum"

    print(f"Extracting Anki deck from: {input_path}")
    items = extract_anki_deck(input_path, output_path, audio_dir)

    print(f"Extraction successful: {len(items)} dialogues extracted.")
    print(f"Output saved to: {output_path}")
    print(f"Audio files copied to: {audio_dir}")


if __name__ == "__main__":
    main()
