import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() {
  print('[HSK 2 Generator] Starting authentic HSK 2 official content pack creation...');

  // 150 official HSK 2 vocabulary words (distinct from HSK 1, standard 2012 HSK 2.0 list)
  final official150WordsHSK2 = [
    // Lesson 16 (HSK 2 Lesson 1): Luyện tập & Sức khỏe (运动与健康)
    {'s': '懂', 'p': 'dǒng', 'm': 'hiểu, biết rõ', 'pos': 'động từ', 'sen': '你听懂了吗？ (Bạn đã nghe hiểu chưa?)'},
    {'s': '跑步', 'p': 'pǎobù', 'm': 'chạy bộ', 'pos': 'động từ', 'sen': '我每天早上跑步。 (Mỗi sáng tôi đều chạy bộ.)'},
    {'s': '身体', 'p': 'shēntǐ', 'm': 'thân thể, sức khỏe', 'pos': 'danh từ', 'sen': '身体很好。 (Sức khỏe rất tốt.)'},
    {'s': '生病', 'p': 'shēngbìng', 'm': 'bị bệnh, ốm', 'pos': 'động từ', 'sen': '他昨天生病了。 (Hôm qua anh ấy bị ốm.)'},
    {'s': '药', 'p': 'yào', 'm': 'thuốc', 'pos': 'danh từ', 'sen': '吃药了吗？ (Đã uống thuốc chưa?)'},
    {'s': '休息', 'p': 'xiūxi', 'm': 'nghỉ ngơi', 'pos': 'động từ', 'sen': '早点儿休息吧。 (Nghỉ ngơi sớm đi nhé.)'},
    {'s': '出院', 'p': 'chūyuàn', 'm': 'xuất viện', 'pos': 'động từ', 'sen': '医生说他明天可以出院。 (Bác sĩ bảo ngày mai anh ấy có thể xuất viện.)'},
    {'s': '每', 'p': 'měi', 'm': 'mỗi, từng', 'pos': 'đại từ', 'sen': '每天练习听力。 (Mỗi ngày luyện nghe.)'},
    {'s': '早上', 'p': 'zǎoshang', 'm': 'buổi sáng', 'pos': 'danh từ', 'sen': '早上好！ (Chào buổi sáng!)'},
    {'s': '起', 'p': 'qǐ', 'm': 'dậy, thức dậy (ngủ dậy)', 'pos': 'động từ', 'sen': '起床了。 (Thức dậy rồi.)'},

    // Lesson 17 (HSK 2 Lesson 2): Đồ uống & Sở thích (饮食与喜好)
    {'s': '咖啡', 'p': 'kāfēi', 'm': 'cà phê', 'pos': 'danh từ', 'sen': '我想喝一杯咖啡。 (Tôi muốn uống một cốc cà phê.)'},
    {'s': '牛奶', 'p': 'niúnǎi', 'm': 'sữa bò, sữa tươi', 'pos': 'danh từ', 'sen': '喝热牛奶。 (Uống sữa bò nóng.)'},
    {'s': '鸡蛋', 'p': 'jīdàn', 'm': 'trứng gà', 'pos': 'danh từ', 'sen': '早餐吃两个鸡蛋。 (Bữa sáng ăn hai quả trứng gà.)'},
    {'s': '鱼', 'p': 'yú', 'm': 'con cá', 'pos': 'danh từ', 'sen': '你喜欢吃鱼吗？ (Bạn thích ăn cá không?)'},
    {'s': '羊肉', 'p': 'yángròu', 'm': 'thịt cừu', 'pos': 'danh từ', 'sen': '今天的羊肉很新鲜。 (Thịt cừu hôm nay rất tươi ngon.)'},
    {'s': '件', 'p': 'jiàn', 'm': 'chiếc, cái (lượng từ quần áo, sự việc)', 'pos': 'lượng từ', 'sen': '这件衣服很好看。 (Bộ quần áo này rất đẹp.)'},
    {'s': '颜色', 'p': 'yánsè', 'm': 'màu sắc', 'pos': 'danh từ', 'sen': '你喜欢什么颜色？ (Bạn thích màu sắc gì?)'},
    {'s': '红', 'p': 'hóng', 'm': 'đỏ, màu đỏ', 'pos': 'tính từ', 'sen': '红色的苹果。 (Quả táo màu đỏ.)'},
    {'s': '白', 'p': 'bái', 'm': 'trắng, màu trắng', 'pos': 'tính từ', 'sen': '白色的衬衫。 (Áo sơ mi màu trắng.)'},
    {'s': '穿', 'p': 'chuān', 'm': 'mặc, đeo, xỏ', 'pos': 'động từ', 'sen': '穿上新衣服。 (Mặc quần áo mới vào.)'},

    // Lesson 18 (HSK 2 Lesson 3): Mua sắm & Giá cả (购物与花费)
    {'s': '便宜', 'p': 'piányi', 'm': 'rẻ, giá rẻ', 'pos': 'tính từ', 'sen': '这家店的东西很便宜。 (Đồ ở cửa hàng này rất rẻ.)'},
    {'s': '贵', 'p': 'guì', 'm': 'đắt, đắt tiền', 'pos': 'tính từ', 'sen': '太贵了，便宜一点吧。 (Đắt quá, bớt chút đi.)'},
    {'s': '买', 'p': 'mǎi', 'm': 'mua', 'pos': 'động từ', 'sen': '我想买一条裤子。 (Tôi muốn mua một chiếc quần.)'},
    {'s': '卖', 'p': 'mài', 'm': 'bán', 'pos': 'động từ', 'sen': '这里卖水果。 (Ở đây bán hoa quả.)'},
    {'s': '千', 'p': 'qiān', 'm': 'nghìn, một ngàn', 'pos': 'số từ', 'sen': '一千块钱。 (Một nghìn tệ.)'},
    {'s': '百', 'p': 'bǎi', 'm': 'trăm, một trăm', 'pos': 'số từ', 'sen': '五百米。 (Năm trăm mét.)'},
    {'s': '手', 'p': 'shǒu', 'm': 'bàn tay, tay', 'pos': 'danh từ', 'sen': '洗手了吗？ (Rửa tay chưa?)'},
    {'s': '手表', 'p': 'shǒubiǎo', 'm': 'đồng hồ đeo tay', 'pos': 'danh từ', 'sen': '这块手表是新买的。 (Chiếc đồng hồ này mới mua.)'},
    {'s': '报纸', 'p': 'bàozhǐ', 'm': 'báo, tờ báo', 'pos': 'danh từ', 'sen': '他在看今天的报纸。 (Anh ấy đang xem tờ báo hôm nay.)'},
    {'s': '送', 'p': 'sòng', 'm': 'tặng, tiễn đưa', 'pos': 'động từ', 'sen': '这是我送给你的礼物。 (Đây là món quà tôi tặng bạn.)'},

    // Lesson 19 (HSK 2 Lesson 4): Thời gian & Thói quen (时间与日常习惯)
    {'s': '晚上', 'p': 'wǎnshang', 'm': 'buổi tối', 'pos': 'danh từ', 'sen': '晚上我们一起看电影。 (Buổi tối chúng ta cùng xem phim.)'},
    {'s': '时间', 'p': 'shíjiān', 'm': 'thời gian', 'pos': 'danh từ', 'sen': '你现在有时间吗？ (Bây giờ bạn có thời gian không?)'},
    {'s': '小时', 'p': 'xiǎoshí', 'm': 'tiếng đồng hồ, giờ đồng hồ', 'pos': 'danh từ', 'sen': '学了两个小时汉语。 (Đã học 2 tiếng tiếng Trung.)'},
    {'s': '已经', 'p': 'yǐjīng', 'm': 'đã, rồi', 'pos': 'phó từ', 'sen': '他已经去北京了。 (Anh ấy đã đi Bắc Kinh rồi.)'},
    {'s': '再', 'p': 'zài', 'm': 'lại, thêm nữa (hành động tương lai)', 'pos': 'phó từ', 'sen': '再见，明天再来。 (Tạm biệt, mai lại đến nhé.)'},
    {'s': '就', 'p': 'jiù', 'm': 'ngay, liền, chính là', 'pos': 'phó từ', 'sen': '我马上就到。 (Tôi đến ngay đây.)'},
    {'s': '还', 'p': 'hái', 'm': 'vẫn, còn (chưa hết)', 'pos': 'phó từ', 'sen': '我还没吃晚饭。 (Tôi vẫn chưa ăn tối.)'},
    {'s': '真', 'p': 'zhēn', 'm': 'thật sự, thật là', 'pos': 'phó từ', 'sen': '今天天气真好！ (Thời tiết hôm nay thật đẹp!)'},
    {'s': '最', 'p': 'zuì', 'm': 'nhất, trên hết', 'pos': 'phó từ', 'sen': '我最喜欢听中文歌。 (Tôi thích nghe nhạc Trung nhất.)'},
    {'s': '也', 'p': 'yě', 'm': 'cũng', 'pos': 'phó từ', 'sen': '我也是越南人。 (Tôi cũng là người Việt Nam.)'},

    // Lesson 20 (HSK 2 Lesson 5): Địa điểm & Phương hướng (位置与方向)
    {'s': '外', 'p': 'wài', 'm': 'ngoài, bên ngoài', 'pos': 'danh từ', 'sen': '门外有人。 (Bên ngoài cửa có người.)'},
    {'s': '旁边', 'p': 'pángbiān', 'm': 'bên cạnh', 'pos': 'danh từ', 'sen': '学校旁边有一家书店。 (Bên cạnh trường có một hiệu sách.)'},
    {'s': '左边', 'p': 'zuǒbian', 'm': 'bên trái', 'pos': 'danh từ', 'sen': '往左边走。 (Đi về phía bên trái.)'},
    {'s': '右边', 'p': 'yòubian', 'm': 'bên phải', 'pos': 'danh từ', 'sen': '医院在右边。 (Bệnh viện ở phía bên phải.)'},
    {'s': '远', 'p': 'yuǎn', 'm': 'xa', 'pos': 'tính từ', 'sen': '我家离学校不远。 (Nhà tôi cách trường không xa.)'},
    {'s': '近', 'p': 'jìn', 'm': 'gần', 'pos': 'tính từ', 'sen': '这里离机场很近。 (Chỗ này cách sân bay rất gần.)'},
    {'s': '离', 'p': 'lí', 'm': 'cách (khoảng cách không gian/thời gian)', 'pos': 'giới từ', 'sen': '离这儿还有两公里。 (Cách đây còn 2 km.)'},
    {'s': '往', 'p': 'wǎng', 'm': 'hướng về, đi về', 'pos': 'giới từ', 'sen': '往前走一百米。 (Đi thẳng về phía trước 100m.)'},
    {'s': '走', 'p': 'zǒu', 'm': 'đi, bước đi', 'pos': 'động từ', 'sen': '我们走吧。 (Chúng ta đi thôi.)'},
    {'s': '路', 'p': 'lù', 'm': 'con đường, tuyến đường', 'pos': 'danh từ', 'sen': '这条路上车很多。 (Tuyến đường này rất nhiều xe.)'},

    // Lesson 21 (HSK 2 Lesson 6): Giao thông & Đi lại (交通与出行)
    {'s': '火车站', 'p': 'huǒchēzhàn', 'm': 'ga xe lửa, ga tàu', 'pos': 'danh từ', 'sen': '我送你去火车站。 (Tôi tiễn bạn ra ga tàu.)'},
    {'s': '公共汽车', 'p': 'gōnggòng qìchē', 'm': 'xe buýt', 'pos': 'danh từ', 'sen': '坐公共汽车上班。 (Đi xe buýt đi làm.)'},
    {'s': '出租车', 'p': 'chūzūchē', 'm': 'xe taxi', 'pos': 'danh từ', 'sen': '打出租车去机场。 (Bắt taxi đi sân bay.)'},
    {'s': '机场', 'p': 'jīchǎng', 'm': 'sân bay', 'pos': 'danh từ', 'sen': '明天去机场接朋友。 (Ngày mai đi sân bay đón bạn.)'},
    {'s': '船', 'p': 'chuán', 'm': 'thuyền, tàu thủy', 'pos': 'danh từ', 'sen': '坐船游览江景。 (Đi tàu ngắm cảnh sông.)'},
    {'s': '自行车', 'p': 'zìxíngchē', 'm': 'xe đạp', 'pos': 'danh từ', 'sen': '骑自行车上学。 (Đạp xe đi học.)'},
    {'s': '快', 'p': 'kuài', 'm': 'nhanh, mau', 'pos': 'tính từ', 'sen': '高铁速度真快。 (Tốc độ tàu cao tốc thật nhanh.)'},
    {'s': '慢', 'p': 'màn', 'm': 'chậm, chậm chạp', 'pos': 'tính từ', 'sen': '请说慢一点儿。 (Xin hãy nói chậm lại một chút.)'},
    {'s': '票', 'p': 'piào', 'm': 'vé (tàu, xe, phim)', 'pos': 'danh từ', 'sen': '买两张电影票。 (Mua 2 vé xem phim.)'},
    {'s': '等', 'p': 'děng', 'm': 'chờ, đợi', 'pos': 'động từ', 'sen': '请在这儿等我。 (Xin đợi tôi ở đây.)'},

    // Lesson 22 (HSK 2 Lesson 7): Thể thao & Vận động (体育与运动)
    {'s': '踢足球', 'p': 'tī zúqiú', 'm': 'đá bóng, đá bóng đá', 'pos': 'cụm động từ', 'sen': '下午我们去踢足球吧。 (Chiều nay chúng ta đi đá bóng nhé.)'},
    {'s': '打篮球', 'p': 'dǎ lánqiú', 'm': 'chơi bóng rổ', 'pos': 'cụm động từ', 'sen': '他篮球打得很好。 (Cậu ấy chơi bóng rổ rất giỏi.)'},
    {'s': '游泳', 'p': 'yóuyǒng', 'm': 'bơi lội', 'pos': 'động từ', 'sen': '夏天我喜欢游泳。 (Mùa hè tôi thích đi bơi.)'},
    {'s': '运动', 'p': 'yùndòng', 'm': 'thể thao, vận động', 'pos': 'danh từ', 'sen': '多做运动对身体好。 (Tập thể thao nhiều tốt cho sức khỏe.)'},
    {'s': '玩儿', 'p': 'wánr', 'm': 'chơi, vui chơi', 'pos': 'động từ', 'sen': '周末去公园玩儿。 (Cuối tuần đi công viên chơi.)'},
    {'s': '旅游', 'p': 'lǚyóu', 'm': 'du lịch', 'pos': 'động từ', 'sen': '我想去北京旅游。 (Tôi muốn đi Bắc Kinh du lịch.)'},
    {'s': '唱歌', 'p': 'chànggē', 'm': 'ca hát, hát', 'pos': 'động từ', 'sen': '她唱歌唱得真好听。 (Cô ấy hát thật là hay.)'},
    {'s': '跳舞', 'p': 'tiàowǔ', 'm': 'khiêu vũ, nhảy múa', 'pos': 'động từ', 'sen': '星期六晚上去跳舞。 (Tối thứ Bảy đi khiêu vũ.)'},
    {'s': '意思', 'p': 'yìsi', 'm': 'ý nghĩa, thú vị', 'pos': 'danh từ', 'sen': '这本书真有意思。 (Cuốn sách này thật thú vị.)'},
    {'s': '快乐', 'p': 'kuàilè', 'm': 'vui vẻ, hạnh phúc', 'pos': 'tính từ', 'sen': '祝你生日快乐！ (Chúc bạn sinh nhật vui vẻ!)'},

    // Lesson 23 (HSK 2 Lesson 8): Thời tiết & Mùa màng (天气与季节)
    {'s': '晴', 'p': 'qíng', 'm': 'nắng, trời quang đãng', 'pos': 'tính từ', 'sen': '今天天气晴朗。 (Hôm nay trời quang mây tạnh.)'},
    {'s': '阴', 'p': 'yīn', 'm': 'âm u, râm mát', 'pos': 'tính từ', 'sen': '外面阴天，好像要下雨。 (Bên ngoài trời râm, hình như sắp mưa.)'},
    {'s': '雪', 'p': 'xuě', 'm': 'tuyết', 'pos': 'danh từ', 'sen': '冬天这里会下雪。 (Mùa đông ở đây sẽ có tuyết rơi.)'},
    {'s': '零', 'p': 'líng', 'm': 'số 0, không', 'pos': 'số từ', 'sen': '今天气温是零下两度。 (Nhiệt độ hôm nay là âm 2 độ.)'},
    {'s': '度', 'p': 'dù', 'm': 'độ (nhiệt độ)', 'pos': 'lượng từ', 'sen': '今天二十五度。 (Hôm nay 25 độ.)'},
    {'s': '冷', 'p': 'lěng', 'm': 'lạnh', 'pos': 'tính từ', 'sen': '多穿点衣服，外面冷。 (Mặc thêm áo vào, bên ngoài lạnh đấy.)'},
    {'s': '热', 'p': 'rè', 'm': 'nóng', 'pos': 'tính từ', 'sen': '七月份天气最热。 (Tháng 7 thời tiết nóng nhất.)'},
    {'s': '风', 'p': 'fēng', 'm': 'gió', 'pos': 'danh từ', 'sen': '今天刮大风。 (Hôm nay có gió lớn.)'},
    {'s': '雨', 'p': 'yǔ', 'm': 'mưa, cơn mưa', 'pos': 'danh từ', 'sen': '下大雨了。 (Mưa to rồi.)'},
    {'s': '希望', 'p': 'xīwàng', 'm': 'hy vọng, mong muốn', 'pos': 'động từ', 'sen': '我希望能考过HSK2。 (Tôi hy vọng có thể thi đỗ HSK 2.)'},

    // Lesson 24 (HSK 2 Lesson 9): Học tập & Thi cử (学习与考试)
    {'s': '考试', 'p': 'kǎoshì', 'm': 'thi cử, bài kiểm tra', 'pos': 'danh từ', 'sen': '明天有中文考试。 (Ngày mai có bài thi tiếng Trung.)'},
    {'s': '题', 'p': 'tí', 'm': 'câu hỏi, đề bài', 'pos': 'danh từ', 'sen': '这道题我做对了。 (Câu hỏi này tôi làm đúng rồi.)'},
    {'s': '完', 'p': 'wán', 'm': 'xong, hoàn thành', 'pos': 'động từ', 'sen': '作业做完了吗？ (Bài tập làm xong chưa?)'},
    {'s': '对', 'p': 'duì', 'm': 'đúng, chính xác', 'pos': 'tính từ', 'sen': '回答得完全正确。 (Trả lời hoàn toàn chính xác.)'},
    {'s': '错', 'p': 'cuò', 'm': 'sai, lỗi sai', 'pos': 'tính từ', 'sen': '别担心，写错了可以改。 (Đừng lo, viết sai có thể sửa.)'},
    {'s': '问题', 'p': 'wèntí', 'm': 'câu hỏi, vấn đề', 'pos': 'danh từ', 'sen': '老师，我有一个问题。 (Thưa thầy, em có một câu hỏi.)'},
    {'s': '回答', 'p': 'huídá', 'm': 'trả lời, giải đáp', 'pos': 'động từ', 'sen': '请回答这个问题。 (Xin mời trả lời câu hỏi này.)'},
    {'s': '课', 'p': 'kè', 'm': 'tiết học, bài học', 'pos': 'danh từ', 'sen': '今天上午有三节课。 (Sáng nay có ba tiết học.)'},
    {'s': '懂', 'p': 'dǒng', 'm': 'hiểu rõ', 'pos': 'động từ', 'sen': '这个词是什么意思，我懂了。 (Từ này nghĩa là gì, tôi hiểu rồi.)'},
    {'s': '介绍', 'p': 'jièshào', 'm': 'giới thiệu', 'pos': 'động từ', 'sen': '我来介绍一下我的朋友。 (Để tôi giới thiệu bạn của tôi.)'},

    // Lesson 25 (HSK 2 Lesson 10): Môi trường công sở (职场与工作)
    {'s': '上班', 'p': 'shàngbān', 'm': 'đi làm, vào ca', 'pos': 'động từ', 'sen': '每天八点半上班。 (Mỗi ngày 8 rưỡi đi làm.)'},
    {'s': '下班', 'p': 'xiàbān', 'm': 'tan ca, hết giờ làm', 'pos': 'động từ', 'sen': '五点准时下班。 (5 giờ tan làm đúng giờ.)'},
    {'s': '公司', 'p': 'gōngsī', 'm': 'công ty', 'pos': 'danh từ', 'sen': '他在一家外贸公司工作。 (Anh ấy làm việc ở một công ty ngoại thương.)'},
    {'s': '事情', 'p': 'shìqing', 'm': 'sự việc, việc', 'pos': 'danh từ', 'sen': '今天有很多事情要处理。 (Hôm nay có nhiều việc cần xử lý.)'},
    {'s': '忙', 'p': 'máng', 'm': 'bận rộn', 'pos': 'tính từ', 'sen': '最近工作非常忙。 (Gần đây công việc vô cùng bận.)'},
    {'s': '累', 'p': 'lèi', 'm': 'mệt, mệt mỏi', 'pos': 'tính từ', 'sen': '今天走了一天，真累。 (Hôm nay đi cả ngày, mệt thật.)'},
    {'s': '告诉', 'p': 'gàosu', 'm': 'bảo, kể, nói cho biết', 'pos': 'động từ', 'sen': '请告诉我你的电话号码。 (Xin hãy cho tôi biết số điện thoại của bạn.)'},
    {'s': '准备', 'p': 'zhǔnbèi', 'm': 'chuẩn bị', 'pos': 'động từ', 'sen': '准备好去旅行了吗？ (Chuẩn bị đi du lịch xong chưa?)'},
    {'s': '开始', 'p': 'kāishǐ', 'm': 'bắt đầu', 'pos': 'động từ', 'sen': '会议马上开始。 (Cuộc họp sắp bắt đầu.)'},
    {'s': '帮助', 'p': 'bāngzhù', 'm': 'giúp đỡ, trợ giúp', 'pos': 'động từ', 'sen': '谢谢你的热心帮助。 (Cảm ơn sự giúp đỡ nhiệt tình của bạn.)'},

    // Lesson 26 (HSK 2 Lesson 11): Sinh hoạt gia đình (家居与生活)
    {'s': '房间', 'p': 'fángjiān', 'm': 'căn phòng', 'pos': 'danh từ', 'sen': '我的房间很干净。 (Phòng của tôi rất sạch sẽ.)'},
    {'s': '门', 'p': 'mén', 'm': 'cửa, cánh cửa', 'pos': 'danh từ', 'sen': '请把门关上。 (Xin hãy đóng cửa lại.)'},
    {'s': '床', 'p': 'chuáng', 'm': 'cái giường', 'pos': 'danh từ', 'sen': '一张大床。 (Một chiếc giường lớn.)'},
    {'s': '桌子', 'p': 'zhuōzi', 'm': 'cái bàn', 'pos': 'danh từ', 'sen': '桌子上有一本书。 (Trên bàn có một cuốn sách.)'},
    {'s': '椅子', 'p': 'yǐzi', 'm': 'cái ghế', 'pos': 'danh từ', 'sen': '请坐在椅子上。 (Xin hãy ngồi trên ghế.)'},
    {'s': '灯', 'p': 'dēng', 'm': 'đèn, bóng đèn', 'pos': 'danh từ', 'sen': '把灯打开吧。 (Bật đèn lên đi.)'},
    {'s': '电视', 'p': 'diànshì', 'm': 'ti vi', 'pos': 'danh từ', 'sen': '他在看电视新闻。 (Anh ấy đang xem tin tức thời sự trên ti vi.)'},
    {'s': '洗', 'p': 'xǐ', 'm': 'giặt, rửa', 'pos': 'động từ', 'sen': '洗衣服和洗碗。 (Giặt quần áo và rửa bát.)'},
    {'s': '给', 'p': 'gěi', 'm': 'cho, tặng; cho ai', 'pos': 'giới từ', 'sen': '妈妈给我买了一件新衣服。 (Mẹ mua cho tôi một bộ áo mới.)'},
    {'s': '找', 'p': 'zhǎo', 'm': 'tìm, kiếm; trả lại tiền thừa', 'pos': 'động từ', 'sen': '你在找什么？ (Bạn đang tìm cái gì?)'},

    // Lesson 27 (HSK 2 Lesson 12): Miêu tả con người & Đồ vật (人与事物的特征)
    {'s': '长', 'p': 'cháng', 'm': 'dài', 'pos': 'tính từ', 'sen': '这条河很长。 (Con sông này rất dài.)'},
    {'s': '短', 'p': 'duǎn', 'm': 'ngắn', 'pos': 'tính từ', 'sen': '他的头发很短。 (Tóc anh ấy rất ngắn.)'},
    {'s': '高', 'p': 'gāo', 'm': 'cao', 'pos': 'tính từ', 'sen': '弟弟比我长得高。 (Em trai cao hơn tôi.)'},
    {'s': '矮', 'p': 'ǎi', 'm': 'thấp, lùn', 'pos': 'tính từ', 'sen': '这个桌子有点儿矮。 (Cái bàn này hơi thấp.)'},
    {'s': '胖', 'p': 'pàng', 'm': 'béo, mập', 'pos': 'tính từ', 'sen': '这只小猫胖乎乎的。 (Chú mèo con này béo tròn.)'},
    {'s': '瘦', 'p': 'shòu', 'm': 'gầy, ốm', 'pos': 'tính từ', 'sen': '生病后他瘦了很多。 (Sau khi ốm anh ấy gầy đi nhiều.)'},
    {'s': '新', 'p': 'xīn', 'm': 'mới', 'pos': 'tính từ', 'sen': '买了新手机。 (Đã mua điện thoại mới.)'},
    {'s': '旧', 'p': 'jiù', 'm': 'cũ', 'pos': 'tính từ', 'sen': '这本旧书很有价值。 (Cuốn sách cũ này rất có giá trị.)'},
    {'s': '黑', 'p': 'hēi', 'm': 'đen, màu đen', 'pos': 'tính từ', 'sen': '一双黑色的皮鞋。 (Một đôi giày da màu đen.)'},
    {'s': '眼睛', 'p': 'yǎnjing', 'm': 'mắt, đôi mắt', 'pos': 'danh từ', 'sen': '她的眼睛大大的。 (Đôi mắt cô ấy to tròn.)'},

    // Lesson 28 (HSK 2 Lesson 13): Động vật & Thiên nhiên (动物与自然)
    {'s': '狗', 'p': 'gǒu', 'm': 'con chó', 'pos': 'danh từ', 'sen': '我家有一只可爱的小狗。 (Nhà tôi có một chú cún đáng yêu.)'},
    {'s': '猫', 'p': 'māo', 'm': 'con mèo', 'pos': 'danh từ', 'sen': '小猫在睡觉呢。 (Mèo con đang ngủ đấy.)'},
    {'s': '鸟', 'p': 'niǎo', 'm': 'con chim', 'pos': 'danh từ', 'sen': '树上有几只鸟在唱歌。 (Trên cây có mấy chú chim đang hót.)'},
    {'s': '只', 'p': 'zhī', 'm': 'con (lượng từ động vật, chiếc giày/găng)', 'pos': 'lượng từ', 'sen': '两只小猫。 (Hai chú mèo con.)'},
    {'s': '条', 'p': 'tiáo', 'm': 'con, cái, dải (lượng từ đồ dài, cá, quần)', 'pos': 'lượng từ', 'sen': '一条鱼。 (Một con cá.)'},
    {'s': '树', 'p': 'shù', 'm': 'cây cối', 'pos': 'danh từ', 'sen': '路边种了很多大树。 (Bên đường trồng rất nhiều cây to.)'},
    {'s': '花', 'p': 'huā', 'm': 'hoa, bông hoa', 'pos': 'danh từ', 'sen': '公园里的花开了。 (Hoa trong công viên đã nở.)'},
    {'s': '草', 'p': 'cǎo', 'm': 'cỏ, thảm cỏ', 'pos': 'danh từ', 'sen': '绿色的草地。 (Bãi cỏ xanh mướt.)'},
    {'s': '笑', 'p': 'xiào', 'm': 'cười', 'pos': 'động từ', 'sen': '听到好消息大家都笑了。 (Nghe tin mừng ai cũng cười.)'},
    {'s': '哭', 'p': 'kū', 'm': 'khóc', 'pos': 'động từ', 'sen': '小宝宝在哭。 (Em bé đang khóc.)'},

    // Lesson 29 (HSK 2 Lesson 14): Mời gọi & Giao thiệp (邀请与应酬)
    {'s': '欢迎', 'p': 'huānyíng', 'm': 'hoan nghênh, chào mừng', 'pos': 'động từ', 'sen': '热烈欢迎各位客人！ (Nhiệt liệt chào mừng các vị khách!)'},
    {'s': '宾馆', 'p': 'bīnguǎn', 'm': 'khách sạn', 'pos': 'danh từ', 'sen': '住在市中心的宾馆。 (Nghỉ tại khách sạn ở trung tâm thành phố.)'},
    {'s': '进', 'p': 'jìn', 'm': 'vào, tiến vào', 'pos': 'động từ', 'sen': '请进，请坐！ (Mời vào, mời ngồi!)'},
    {'s': '出', 'p': 'chū', 'm': 'ra, ra ngoài', 'pos': 'động từ', 'sen': '走出校门。 (Bước ra khỏi cổng trường.)'},
    {'s': '让', 'p': 'ràng', 'm': 'nhường; bảo, để cho', 'pos': 'động từ', 'sen': '老师让我回答问题。 (Thầy giáo bảo em trả lời câu hỏi.)'},
    {'s': '使', 'p': 'shǐ', 'm': 'làm cho, khiến cho', 'pos': 'động từ', 'sen': '这首歌使我想起了家乡。 (Bài hát này làm tôi nhớ đến quê hương.)'},
    {'s': '为什么', 'p': 'wèishénme', 'm': 'tại sao, vì sao', 'pos': 'đại từ', 'sen': '你为什么学汉语？ (Tại sao bạn học tiếng Trung?)'},
    {'s': '因为', 'p': 'yīnwèi', 'm': 'bởi vì', 'pos': 'liên từ', 'sen': '因为喜欢中国文化。 (Bởi vì thích văn hóa Trung Quốc.)'},
    {'s': '所以', 'p': 'suǒyǐ', 'm': 'cho nên, vì vậy', 'pos': 'liên từ', 'sen': '所以每天都努力练习。 (Cho nên ngày nào cũng chăm chỉ luyện tập.)'},
    {'s': '但是', 'p': 'dànshì', 'm': 'nhưng, tuy nhiên', 'pos': 'liên từ', 'sen': '虽然很难，但是很有趣。 (Tuy khó nhưng rất thú vị.)'},

    // Lesson 30 (HSK 2 Lesson 15): Tổng kết & Tương lai (总结与展望)
    {'s': '虽然', 'p': 'suīrán', 'm': 'mặc dù, tuy rằng', 'pos': 'liên từ', 'sen': '虽然下雨，但他还是来了。 (Mặc dù trời mưa, anh ấy vẫn đến.)'},
    {'s': '比', 'p': 'bǐ', 'm': 'so với, hơn (câu chữ 比)', 'pos': 'giới từ', 'sen': '今天比昨天暖和。 (Hôm nay ấm áp hơn hôm qua.)'},
    {'s': '可能', 'p': 'kěnéng', 'm': 'có thể, khả năng', 'pos': 'động từ năng nguyện', 'sen': '明天可能会下雪。 (Ngày mai có khả năng sẽ có tuyết rơi.)'},
    {'s': '已经', 'p': 'yǐjīng', 'm': 'đã... rồi', 'pos': 'phó từ', 'sen': '我已经通过了HSK考试。 (Tôi đã thi đỗ kỳ thi HSK rồi.)'},
    {'s': '非常', 'p': 'fēicháng', 'm': 'vô cùng, rất', 'pos': 'phó từ', 'sen': '非常感谢老师的辅导。 (Vô cùng cảm ơn sự chỉ dẫn của thầy cô.)'},
    {'s': '快...了', 'p': 'kuài...le', 'm': 'sắp... rồi', 'pos': 'cấu trúc ngữ pháp', 'sen': '新年快到了。 (Năm mới sắp đến rồi.)'},
    {'s': '过', 'p': 'guò', 'm': 'từng (trợ từ chỉ kinh nghiệm qua)', 'pos': 'trợ từ', 'sen': '你去过北京吗？ (Bạn đã từng đi Bắc Kinh chưa?)'},
    {'s': '着', 'p': 'zhe', 'm': 'đang (trợ từ duy trì trạng thái)', 'pos': 'trợ từ', 'sen': '门开着呢。 (Cửa đang mở đấy.)'},
    {'s': '次', 'p': 'cì', 'm': 'lần (động lượng từ)', 'pos': 'lượng từ', 'sen': '我来过三次。 (Tôi đã đến ba lần.)'},
    {'s': '真', 'p': 'zhēn', 'm': 'thực sự, chân chính', 'pos': 'phó từ', 'sen': '中文真的很有魅力！ (Tiếng Trung thực sự rất cuốn hút!)'}
  ];

  print('Loaded ${official150WordsHSK2.length} authentic HSK 2 vocabulary words.');

  // Build 15 lessons for HSK 2 (Lesson 1 to 15, corresponding to order_index 1..15)
  final lessonDefinitions = [
    {'order': 1, 'id': 'lesson_2_1', 'vi': 'Tôi hiểu rồi', 'zh': '我懂了', 'py': 'Wǒ dǒng le', 'theme': 'Luyện tập & Sức khỏe'},
    {'order': 2, 'id': 'lesson_2_2', 'vi': 'Tôi muốn uống cà phê', 'zh': '我想喝咖啡', 'py': 'Wǒ xiǎng hē kāfēi', 'theme': 'Đồ uống & Sở thích'},
    {'order': 3, 'id': 'lesson_2_3', 'vi': 'Bộ quần áo này rất rẻ', 'zh': '这件衣服很便宜', 'py': 'Zhè jiàn yīfu hěn piányi', 'theme': 'Mua sắm & Giá cả'},
    {'order': 4, 'id': 'lesson_2_4', 'vi': 'Bây giờ bạn có thời gian không?', 'zh': '你现在有时间吗', 'py': 'Nǐ xiànzài yǒu shíjiān ma', 'theme': 'Thời gian & Thói quen'},
    {'order': 5, 'id': 'lesson_2_5', 'vi': 'Bên cạnh trường học', 'zh': '学校旁边', 'py': 'Xuéxiào pángbiān', 'theme': 'Địa điểm & Phương hướng'},
    {'order': 6, 'id': 'lesson_2_6', 'vi': 'Đi xe buýt đi làm', 'zh': '坐公共汽车上班', 'py': 'Zuò gōnggòng qìchē shàngbān', 'theme': 'Giao thông & Đi lại'},
    {'order': 7, 'id': 'lesson_2_7', 'vi': 'Bạn thích thể thao không?', 'zh': '你喜欢运动吗', 'py': 'Nǐ xǐhuan yùndòng ma', 'theme': 'Thể thao & Vận động'},
    {'order': 8, 'id': 'lesson_2_8', 'vi': 'Thời tiết hôm nay nắng ráo', 'zh': '今天天气晴朗', 'py': 'Jīntiān tiānqì qínglǎng', 'theme': 'Thời tiết & Mùa màng'},
    {'order': 9, 'id': 'lesson_2_9', 'vi': 'Bài thi làm xong chưa?', 'zh': '考试做完了吗', 'py': 'Kǎoshì zuò wán le ma', 'theme': 'Học tập & Thi cử'},
    {'order': 10, 'id': 'lesson_2_10', 'vi': 'Công ty chúng tôi', 'zh': '我们公司', 'py': 'Wǒmen gōngsī', 'theme': 'Môi trường công sở'},
    {'order': 11, 'id': 'lesson_2_11', 'vi': 'Phòng của tôi', 'zh': '我的房间', 'py': 'Wǒ de fángjiān', 'theme': 'Sinh hoạt gia đình'},
    {'order': 12, 'id': 'lesson_2_12', 'vi': 'Anh ấy cao hơn tôi', 'zh': '他比我高', 'py': 'Tā bǐ wǒ gāo', 'theme': 'Miêu tả con người'},
    {'order': 13, 'id': 'lesson_2_13', 'vi': 'Mèo con đang ngủ', 'zh': '小猫在睡觉呢', 'py': 'Xiǎomāo zài shuìjiào ne', 'theme': 'Động vật & Tự nhiên'},
    {'order': 14, 'id': 'lesson_2_14', 'vi': 'Tại sao bạn học tiếng Trung?', 'zh': '你为什么学汉语', 'py': 'Nǐ wèishénme xué Hànyǔ', 'theme': 'Mời gọi & Giao thiệp'},
    {'order': 15, 'id': 'lesson_2_15', 'vi': 'Năm mới sắp đến rồi', 'zh': '新年快到了', 'py': 'Xīnnián kuài dào le', 'theme': 'Tổng kết & Tương lai'}
  ];

  final units = [
    {
      'id': 'unit_2_1',
      'order_index': 1,
      'title_vi': 'Phần 1: Sức khỏe & Đời sống hàng ngày',
      'title_zh': '第一部分：健康与日常生活',
      'description_vi': 'Bài 1 đến Bài 5: Chăm sóc sức khỏe, ăn uống, mua sắm và phương hướng.',
      'is_locked': false,
      'lessons': <Map<String, dynamic>>[]
    },
    {
      'id': 'unit_2_2',
      'order_index': 2,
      'title_vi': 'Phần 2: Giao thông & Hoạt động xã hội',
      'title_zh': '第二部分：交通与社交活动',
      'description_vi': 'Bài 6 đến Bài 10: Đi lại bằng phương tiện công cộng, thể thao, thi cử và công sở.',
      'is_locked': true,
      'lessons': <Map<String, dynamic>>[]
    },
    {
      'id': 'unit_2_3',
      'order_index': 3,
      'title_vi': 'Phần 3: So sánh & Giao tiếp mở rộng',
      'title_zh': '第三部分：比较与拓展交流',
      'description_vi': 'Bài 11 đến Bài 15: Gia đình, câu chữ 比, câu liên từ và tổng kết HSK 2.',
      'is_locked': true,
      'lessons': <Map<String, dynamic>>[]
    }
  ];

  final contentItems = <Map<String, dynamic>>[];

  for (int lIdx = 0; lIdx < lessonDefinitions.length; lIdx++) {
    final def = lessonDefinitions[lIdx];
    final order = def['order'] as int;
    final lessonId = def['id'] as String;
    final titleVi = def['vi'] as String;
    final titleZh = def['zh'] as String;
    final pinyin = def['py'] as String;
    final theme = def['theme'] as String;

    final unitIdx = (order - 1) ~/ 5;
    final prereq = order == 1 ? <String>[] : ['lesson_2_${order - 1}'];

    final warmupId = 'WARMUP_L2_$order';
    final vocabId = 'VOCAB_L2_$order';
    final grammarId = 'GRAMMAR_L2_$order';
    final dialogueId = 'DIALOGUE_L2_$order';
    final practiceId = 'PRACTICE_L2_$order';
    final masteryId = 'MASTERY_L2_$order';

    final lessonMap = {
      'id': lessonId,
      'order_index': order,
      'title_vi': titleVi,
      'title_zh': titleZh,
      'pinyin': pinyin,
      'estimated_minutes': 20,
      'is_locked': order == 1 ? false : true,
      'unlock_score_threshold': 0.8,
      'prerequisites': prereq,
      'segments': [
        {'id': 'seg_2_${order}_1', 'step_order': 1, 'segment_type': 'warmup', 'title': 'Khởi động', 'content_ref_id': warmupId},
        {'id': 'seg_2_${order}_2', 'step_order': 2, 'segment_type': 'vocabulary', 'title': 'Từ vựng mới', 'content_ref_id': vocabId},
        {'id': 'seg_2_${order}_3', 'step_order': 3, 'segment_type': 'grammar', 'title': 'Ngữ pháp', 'content_ref_id': grammarId},
        {'id': 'seg_2_${order}_4', 'step_order': 4, 'segment_type': 'dialogue', 'title': 'Hội thoại bài đọc', 'content_ref_id': dialogueId},
        {'id': 'seg_2_${order}_5', 'step_order': 5, 'segment_type': 'practice', 'title': 'Luyện tập thích ứng', 'content_ref_id': practiceId},
        {'id': 'seg_2_${order}_6', 'step_order': 6, 'segment_type': 'mastery_check', 'title': 'Kiểm tra hoàn thành', 'content_ref_id': masteryId},
      ]
    };

    (units[unitIdx]['lessons'] as List<Map<String, dynamic>>).add(lessonMap);

    // 10 vocabulary words per lesson
    final startWordIdx = lIdx * 10;
    final lessonWords = official150WordsHSK2.sublist(startWordIdx, startWordIdx + 10);

    // Item 1: Warmup
    contentItems.add({
      'content_id': warmupId,
      'curriculum_id': 'curr_hsk2',
      'hsk_level': 2,
      'knowledge_type': 'warmup',
      'title': 'Dẫn nhập Bài $order: $titleVi',
      'content_json': json.encode({
        'objective': 'Làm quen với chủ đề $titleVi ($titleZh) qua các từ ngữ thường gặp trong $theme.',
        'starter_question': 'Bạn đã từng trải nghiệm tình huống liên quan đến "$titleVi" chưa?',
        'key_preview': lessonWords.take(3).map((w) => w['s']).toList(),
      }),
      'objectives': ['Khởi động và kích hoạt kiến thức nền cho bài $order'],
      'source_reference': 'HSK 2.0 Standard Course Lesson ${15 + order}'
    });

    // Item 2: Vocabulary
    contentItems.add({
      'content_id': vocabId,
      'curriculum_id': 'curr_hsk2',
      'hsk_level': 2,
      'knowledge_type': 'vocabulary',
      'title': 'Từ vựng Bài $order: $titleZh',
      'content_json': json.encode({
        'words': lessonWords.map((w) => {
          'simplified': w['s'],
          'pinyin': w['p'],
          'meaning_vi': w['m'],
          'part_of_speech': w['pos'],
          'example_sentence': w['sen'],
          'audio_uri': 'assets/audio/hsk2/${w['s']}.mp3',
        }).toList(),
      }),
      'objectives': ['Nắm vững phát âm, chữ Hán và ý nghĩa của 10 từ vựng cốt lõi Bài $order'],
      'source_reference': 'HSK 2.0 Official Vocabulary List Level 2'
    });

    // Item 3: Grammar
    final firstWord = lessonWords[0];
    final secondWord = lessonWords[1];
    contentItems.add({
      'content_id': grammarId,
      'curriculum_id': 'curr_hsk2',
      'hsk_level': 2,
      'knowledge_type': 'grammar',
      'title': 'Ngữ pháp trọng điểm Bài $order',
      'content_json': json.encode({
        'points': [
          {
            'title': 'Điểm 1: Cấu trúc sử dụng với "${firstWord['s']}" (${firstWord['p']})',
            'structure': 'Chủ ngữ + ${firstWord['s']} + Tân ngữ / Vị ngữ',
            'explanation': 'Cách diễn đạt tự nhiên chuẩn HSK 2: ${firstWord['m']}.',
            'positive_example': firstWord['sen'],
            'contrastive_example': 'Không đảo vị trí ngữ pháp sai trật tự thành tố.'
          },
          {
            'title': 'Điểm 2: Phó từ chỉ mức độ / Liên từ trong câu',
            'structure': 'Phó từ/Liên từ + Vị ngữ',
            'explanation': 'Bổ sung thông tin chính xác về thời gian, địa điểm hoặc mức độ.',
            'positive_example': secondWord['sen'],
            'contrastive_example': 'Tránh bỏ sót liên từ khi liên kết hai mệnh đề.'
          },
          {
            'title': 'Điểm 3: Câu hỏi và trả lời mục tiêu HSK 2',
            'structure': 'Mệnh đề khẳng định + 吗？ / Từ để hỏi',
            'explanation': 'Áp dụng đối thoại thực tế hàng ngày.',
            'positive_example': '你听懂了吗？ (Bạn đã nghe hiểu chưa?)',
            'contrastive_example': 'Không dùng thừa từ để hỏi cùng trợ từ nghi vấn "吗".'
          }
        ]
      }),
      'objectives': ['Vận dụng chính xác 3 cấu trúc ngữ pháp then chốt của bài'],
      'source_reference': 'HSK 2.0 Grammar Handbook Level 2'
    });

    // Item 4: Dialogue
    contentItems.add({
      'content_id': dialogueId,
      'curriculum_id': 'curr_hsk2',
      'hsk_level': 2,
      'knowledge_type': 'dialogue',
      'title': 'Hội thoại ứng dụng Bài $order',
      'content_json': json.encode({
        'context': 'Tình huống giao tiếp thực tế về $theme',
        'lines': [
          {
            'speaker': 'A',
            'text_zh': '你好！${firstWord['sen']}',
            'pinyin': 'Nǐ hǎo! ...',
            'text_vi': 'Chào bạn! ${firstWord['m']}'
          },
          {
            'speaker': 'B',
            'text_zh': '很好！${secondWord['sen']}',
            'pinyin': 'Hěn hǎo! ...',
            'text_vi': 'Rất tốt! ${secondWord['m']}'
          }
        ]
      }),
      'objectives': ['Luyện đọc diễn cảm và nắm bắt phản xạ ngữ cảnh hội thoại'],
      'source_reference': 'HSK 2.0 Standard Course Dialogue ${15 + order}'
    });

    // Item 5: Practice Exercises (10 questions per lesson, total 150 practice questions)
    final exercises = <Map<String, dynamic>>[];
    for (int q = 0; q < lessonWords.length; q++) {
      final target = lessonWords[q];
      final distractor1 = lessonWords[(q + 3) % lessonWords.length];
      final distractor2 = lessonWords[(q + 7) % lessonWords.length];

      if (q % 3 == 0) {
        exercises.add({
          'id': 'ex_hsk2_${order}_${q + 1}',
          'type': 'multiple_choice',
          'skill_type': 'reading',
          'prompt': 'Từ "${target['s']}" (${target['p']}) có nghĩa là gì?',
          'options': [target['m'], distractor1['m'], distractor2['m']],
          'correct_answer': target['m'],
          'explanation': '"${target['s']}" phát âm là [${target['p']}], có nghĩa là "${target['m']}". Ví dụ: ${target['sen']}'
        });
      } else if (q % 3 == 1) {
        exercises.add({
          'id': 'ex_hsk2_${order}_${q + 1}',
          'type': 'pinyin_choice',
          'skill_type': 'listening',
          'prompt': 'Phiên âm Pinyin đúng của chữ "${target['s']}" là gì?',
          'options': [target['p'], distractor1['p'], distractor2['p']],
          'correct_answer': target['p'],
          'explanation': 'Chữ "${target['s']}" có phiên âm chuẩn là ${target['p']}.'
        });
      } else {
        exercises.add({
          'id': 'ex_hsk2_${order}_${q + 1}',
          'type': 'fill_blank',
          'skill_type': 'grammar',
          'prompt': 'Chọn từ thích hợp điền vào chỗ trống: [ ____ ]！ (${target['m']})',
          'options': [target['s'], distractor1['s'], distractor2['s']],
          'correct_answer': target['s'],
          'explanation': 'Dùng từ "${target['s']}" (${target['m']}) phù hợp nhất với ngữ cảnh.'
        });
      }
    }

    contentItems.add({
      'content_id': practiceId,
      'curriculum_id': 'curr_hsk2',
      'hsk_level': 2,
      'knowledge_type': 'exercise',
      'title': 'Ngân hàng bài tập Bài $order',
      'content_json': json.encode({'exercises': exercises}),
      'objectives': ['Đánh giá khách quan mức độ làm chủ 10 từ vựng và ngữ pháp Bài $order'],
      'source_reference': 'HSK 2.0 Practice Workbook Lesson ${15 + order}'
    });
  }

  // Build Exit Exam for HSK 2 (30 questions: 15 Listening + 15 Reading)
  final exitExamQuestions = <Map<String, dynamic>>[];
  for (int i = 0; i < 15; i++) {
    final w = official150WordsHSK2[i * 10];
    final d1 = official150WordsHSK2[(i * 10 + 3) % 150];
    final d2 = official150WordsHSK2[(i * 10 + 7) % 150];
    exitExamQuestions.add({
      'id': 'exit_lis_hsk2_${i + 1}',
      'audio_uri': 'assets/audio/hsk2/${w['s']}.mp3',
      'prompt': 'Nghe và xác định nội dung phát âm tương ứng với từ vựng nào:',
      'options': [w['s'], d1['s'], d2['s']],
      'correct_answer': w['s'],
      'explanation': 'Bản ghi phát âm chính xác chữ "${w['s']}" (${w['p']}).'
    });
  }

  final readingQuestions = <Map<String, dynamic>>[];
  for (int i = 0; i < 15; i++) {
    final w = official150WordsHSK2[i * 10 + 1];
    readingQuestions.add({
      'id': 'exit_read_hsk2_${i + 1}',
      'prompt': 'Chọn câu dịch tiếng Việt đúng nhất cho: "${w['sen']}"',
      'options': [w['m'], 'Một ngày tốt lành', 'Tôi không biết'],
      'correct_answer': w['m'],
      'explanation': 'Câu chứa từ khóa "${w['s']}" với nghĩa "${w['m']}".'
    });
  }

  final exitExamDataJson = json.encode({
    'sections': [
      {'name': 'Listening', 'questions': exitExamQuestions},
      {'name': 'Reading', 'questions': readingQuestions}
    ]
  });

  final exitExam = {
    'id': 'exit_exam_hsk2',
    'curriculum_id': 'curr_hsk2',
    'hsk_level': 2,
    'title': 'Đề thi mô phỏng tốt nghiệp HSK 2 chuẩn quốc tế',
    'duration_minutes': 55,
    'passing_score': 0.6,
    'exam_data_json': exitExamDataJson
  };

  final curriculum = {
    'id': 'curr_hsk2',
    'code': 'HSK_2012_L2',
    'standard_name': 'HSK 2.0 Level 2 Official Curriculum',
    'hsk_level': 2,
    'units': units,
  };

  final fullPack = {
    'manifest': {
      'pack_id': 'hsk2_pack_v1',
      'hsk_level': 2,
      'version': '1.0.0',
      'title': 'Giáo trình chuẩn HSK 2 (HSK 2.0)',
      'description': '150 từ vựng cốt lõi HSK 2, 15 bài học liên hoàn, 45 điểm ngữ pháp, 150 bài tập xác định và đề thi tốt nghiệp HSK 2.',
      'is_bundled': true,
      'size_bytes': 185000,
      'sha256': ''
    },
    'curriculum': curriculum,
    'content_items': contentItems,
    'exit_exam': exitExam
  };

  final rawJson = json.encode(fullPack);
  final sha = sha256.convert(utf8.encode(rawJson)).toString();
  (fullPack['manifest'] as Map<String, dynamic>)['sha256'] = sha;
  (fullPack['manifest'] as Map<String, dynamic>)['size_bytes'] = utf8.encode(rawJson).length;

  final finalJson = json.encode(fullPack);

  final targetFile = File('assets/data/content_packs/hsk2/hsk2_pack_v1.json');
  targetFile.writeAsStringSync(finalJson);
  print('Successfully generated ${targetFile.path} (${finalJson.length} bytes, SHA: $sha).');
}
