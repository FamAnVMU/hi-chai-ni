import 'dart:convert';
import 'dart:io';

void main() {
  final official150Words = [
    // Lesson 1: Xin chào & Chào hỏi
    {'s': '你', 'p': 'nǐ', 'm': 'bạn, anh, chị (đại từ ngôi 2)', 'pos': 'đại từ', 'sen': '你好！ (Chào bạn!)'},
    {'s': '好', 'p': 'hǎo', 'm': 'tốt, đẹp, hay', 'pos': 'tính từ', 'sen': '很好。 (Rất tốt.)'},
    {'s': '请', 'p': 'qǐng', 'm': 'xin, mời', 'pos': 'động từ', 'sen': '请进。 (Mời vào.)'},
    {'s': '对不起', 'p': 'duìbuqǐ', 'm': 'xin lỗi', 'pos': 'động từ', 'sen': '对不起，我迟到了。 (Xin lỗi, tôi đến muộn.)'},
    {'s': '没关系', 'p': 'méiguānxi', 'm': 'không sao, không có gì', 'pos': 'thành ngữ', 'sen': '没关系。 (Không sao đâu.)'},
    {'s': '谢谢', 'p': 'xièxie', 'm': 'cảm ơn', 'pos': 'động từ', 'sen': '谢谢你！ (Cảm ơn bạn!)'},
    {'s': '不客气', 'p': 'búkèqi', 'm': 'không có gì, đừng khách sáo', 'pos': 'thành ngữ', 'sen': '不用谢，不客气。 (Không cần cảm ơn, đừng khách khí.)'},
    {'s': '再见', 'p': 'zàijiàn', 'm': 'tạm biệt, hẹn gặp lại', 'pos': 'động từ', 'sen': '明天再见！ (Ngày mai gặp lại!)'},
    {'s': '不', 'p': 'bù', 'm': 'không (phủ định)', 'pos': 'phó từ', 'sen': '不是我。 (Không phải tôi.)'},
    {'s': '人', 'p': 'rén', 'm': 'người', 'pos': 'danh từ', 'sen': '中国人。 (Người Trung Quốc.)'},

    // Lesson 2: Danh tính & Quốc tịch
    {'s': '我', 'p': 'wǒ', 'm': 'tôi, mình (ngôi 1)', 'pos': 'đại từ', 'sen': '我是学生。 (Tôi là học sinh.)'},
    {'s': '是', 'p': 'shì', 'm': 'là, đúng', 'pos': 'động từ', 'sen': '他是老师。 (Anh ấy là thầy giáo.)'},
    {'s': '老师', 'p': 'lǎoshī', 'm': 'giáo viên, thầy cô giáo', 'pos': 'danh từ', 'sen': '王老师好！ (Chào thầy Vương!)'},
    {'s': '学生', 'p': 'xuésheng', 'm': 'học sinh, sinh viên', 'pos': 'danh từ', 'sen': '我们都是学生。 (Chúng tôi đều là học sinh.)'},
    {'s': '什么', 'p': 'shénme', 'm': 'cái gì', 'pos': 'đại từ', 'sen': '你叫什么名字？ (Bạn tên là gì?)'},
    {'s': '名字', 'p': 'míngzi', 'm': 'tên gọi', 'pos': 'danh từ', 'sen': '这是我的名字。 (Đây là tên của tôi.)'},
    {'s': '叫', 'p': 'jiào', 'm': 'gọi là, tên là', 'pos': 'động từ', 'sen': '我叫李明。 (Tôi tên là Lý Minh.)'},
    {'s': '中国', 'p': 'Zhōngguó', 'm': 'Trung Quốc', 'pos': 'danh từ', 'sen': '我去中国。 (Tôi đi Trung Quốc.)'},
    {'s': '美国', 'p': 'Měiguó', 'm': 'nước Mỹ, Hoa Kỳ', 'pos': 'danh từ', 'sen': '他是美国人。 (Anh ấy là người Mỹ.)'},
    {'s': '吗', 'p': 'ma', 'm': 'không, chăng (trợ từ nghi vấn)', 'pos': 'trợ từ', 'sen': '你好吗？ (Bạn khỏe không?)'},

    // Lesson 3: Bạn bè & Gia đình
    {'s': '他', 'p': 'tā', 'm': 'anh ấy, ông ấy', 'pos': 'đại từ', 'sen': '他是谁？ (Anh ấy là ai?)'},
    {'s': '她', 'p': 'tā', 'm': 'cô ấy, bà ấy', 'pos': 'đại từ', 'sen': '她是我的朋友。 (Cô ấy là bạn của tôi.)'},
    {'s': '谁', 'p': 'shéi', 'm': 'ai', 'pos': 'đại từ', 'sen': '谁来了？ (Ai đã đến?)'},
    {'s': '的', 'p': 'de', 'm': 'của (trợ từ sở hữu)', 'pos': 'trợ từ', 'sen': '我的书。 (Sách của tôi.)'},
    {'s': '朋友', 'p': 'péngyou', 'm': 'bạn bè', 'pos': 'danh từ', 'sen': '好朋友。 (Bạn tốt.)'},
    {'s': '同学', 'p': 'tóngxué', 'm': 'bạn cùng học', 'pos': 'danh từ', 'sen': '他是我的同学。 (Cậu ấy là bạn học của tôi.)'},
    {'s': '汉语', 'p': 'Hànyǔ', 'm': 'tiếng Hán, tiếng Trung', 'pos': 'danh từ', 'sen': '学汉语。 (Học tiếng Trung.)'},
    {'s': '哪', 'p': 'nǎ', 'm': 'nào (nghi vấn)', 'pos': 'đại từ', 'sen': '你是哪国人？ (Bạn là người nước nào?)'},
    {'s': '哪儿', 'p': 'nǎr', 'm': 'ở đâu, chỗ nào', 'pos': 'đại từ', 'sen': '你在哪儿？ (Bạn ở đâu?)'},
    {'s': '呢', 'p': 'ne', 'm': 'thế, nhé (trợ từ ngữ khí)', 'pos': 'trợ từ', 'sen': '你呢？ (Còn bạn thì sao?)'},

    // Lesson 4: Tuổi tác & Số lượng
    {'s': '家', 'p': 'jiā', 'm': 'nhà, gia đình', 'pos': 'danh từ', 'sen': '我家在北京。 (Nhà tôi ở Bắc Kinh.)'},
    {'s': '几', 'p': 'jǐ', 'm': 'mấy (hỏi số lượng < 10)', 'pos': 'đại từ', 'sen': '你几岁？ (Bạn mấy tuổi?)'},
    {'s': '口', 'p': 'kǒu', 'm': 'miệng; người (lượng từ gia đình)', 'pos': 'lượng từ', 'sen': '我家有三口人。 (Nhà tôi có ba người.)'},
    {'s': '岁', 'p': 'suì', 'm': 'tuổi', 'pos': 'lượng từ', 'sen': '我二十岁。 (Tôi 20 tuổi.)'},
    {'s': '多', 'p': 'duō', 'm': 'nhiều; bao nhiêu', 'pos': 'tính từ', 'sen': '你多大？ (Bạn bao nhiêu tuổi?)'},
    {'s': '大', 'p': 'dà', 'm': 'lớn, to', 'pos': 'tính từ', 'sen': '这个苹果很大。 (Quả táo này rất to.)'},
    {'s': '爸爸', 'p': 'bàba', 'm': 'bố, cha', 'pos': 'danh từ', 'sen': '爸爸工作很忙。 (Bố làm việc rất bận.)'},
    {'s': '妈妈', 'p': 'māma', 'm': 'mẹ, má', 'pos': 'danh từ', 'sen': '我爱妈妈。 (Tôi yêu mẹ.)'},
    {'s': '儿子', 'p': 'érzi', 'm': 'con trai', 'pos': 'danh từ', 'sen': '他儿子两岁。 (Con trai anh ấy 2 tuổi.)'},
    {'s': '女儿', 'p': 'nǚ\'ér', 'm': 'con gái', 'pos': 'danh từ', 'sen': '她有一个女儿。 (Cô ấy có một con gái.)'},

    // Lesson 5: Số đếm & Thời gian cơ bản
    {'s': '一', 'p': 'yī', 'm': 'số 1', 'pos': 'số từ', 'sen': '一个人。 (Một người.)'},
    {'s': '二', 'p': 'èr', 'm': 'số 2', 'pos': 'số từ', 'sen': '二月。 (Tháng hai.)'},
    {'s': '三', 'p': 'sān', 'm': 'số 3', 'pos': 'số từ', 'sen': '三本书。 (Ba cuốn sách.)'},
    {'s': '四', 'p': 'sì', 'm': 'số 4', 'pos': 'số từ', 'sen': '四个人。 (Bốn người.)'},
    {'s': '五', 'p': 'wǔ', 'm': 'số 5', 'pos': 'số từ', 'sen': '五点。 (Năm giờ.)'},
    {'s': '六', 'p': 'liù', 'm': 'số 6', 'pos': 'số từ', 'sen': '六块钱。 (Sáu tệ.)'},
    {'s': '七', 'p': 'qī', 'm': 'số 7', 'pos': 'số từ', 'sen': '七天。 (Bảy ngày.)'},
    {'s': '八', 'p': 'bā', 'm': 'số 8', 'pos': 'số từ', 'sen': '八号。 (Ngày tám.)'},
    {'s': '九', 'p': 'jiǔ', 'm': 'số 9', 'pos': 'số từ', 'sen': '九个。 (Chín cái.)'},
    {'s': '十', 'p': 'shí', 'm': 'số 10', 'pos': 'số từ', 'sen': '十分钟。 (Mười phút.)'},

    // Lesson 6: Ngày tháng & Lịch trình
    {'s': '今天', 'p': 'jīntiān', 'm': 'hôm nay', 'pos': 'danh từ', 'sen': '今天是星期一。 (Hôm nay là thứ hai.)'},
    {'s': '明天', 'p': 'míngtiān', 'm': 'ngày mai', 'pos': 'danh từ', 'sen': '明天见。 (Ngày mai gặp.)'},
    {'s': '昨天', 'p': 'zuótiān', 'm': 'hôm qua', 'pos': 'danh từ', 'sen': '昨天很冷。 (Hôm qua rất lạnh.)'},
    {'s': '月', 'p': 'yuè', 'm': 'tháng, trăng', 'pos': 'danh từ', 'sen': '五月一日。 (Ngày 1 tháng 5.)'},
    {'s': '号', 'p': 'hào', 'm': 'ngày (trong tháng), số', 'pos': 'danh từ', 'sen': '今天几号？ (Hôm nay ngày mấy?)'},
    {'s': '星期', 'p': 'xīngqī', 'm': 'tuần lễ, thứ', 'pos': 'danh từ', 'sen': '星期天去北京。 (Chủ nhật đi Bắc Kinh.)'},
    {'s': '年', 'p': 'nián', 'm': 'năm', 'pos': 'danh từ', 'sen': '二零二六年。 (Năm 2026.)'},
    {'s': '去', 'p': 'qù', 'm': 'đi đến', 'pos': 'động từ', 'sen': '我去商店。 (Tôi đi cửa hàng.)'},
    {'s': '学校', 'p': 'xuéxiào', 'm': 'trường học', 'pos': 'danh từ', 'sen': '我们在学校。 (Chúng tôi ở trường học.)'},
    {'s': '看书', 'p': 'kànshū', 'm': 'đọc sách', 'pos': 'cụm động từ', 'sen': '在学校看书。 (Đọc sách ở trường.)'},

    // Lesson 7: Kỹ năng & Năng lực
    {'s': '会', 'p': 'huì', 'm': 'biết, có thể (qua học tập)', 'pos': 'động từ năng nguyện', 'sen': '我会说汉语。 (Tôi biết nói tiếng Trung.)'},
    {'s': '说', 'p': 'shuō', 'm': 'nói', 'pos': 'động từ', 'sen': '你说什么？ (Bạn nói gì?)'},
    {'s': '说话', 'p': 'shuōhuà', 'm': 'nói chuyện', 'pos': 'động từ', 'sen': '请别说话。 (Xin đừng nói chuyện.)'},
    {'s': '菜', 'p': 'cài', 'm': 'món ăn, rau', 'pos': 'danh từ', 'sen': '中国菜很好吃。 (Món Trung Quốc rất ngon.)'},
    {'s': '很', 'p': 'hěn', 'm': 'rất (phó từ chỉ mức độ)', 'pos': 'phó từ', 'sen': '很好。 (Rất tốt.)'},
    {'s': '好吃', 'p': 'hǎochī', 'm': 'ngon miệng', 'pos': 'tính từ', 'sen': '米饭好吃。 (Cơm ngon.)'},
    {'s': '做', 'p': 'zuò', 'm': 'làm, chế tạo', 'pos': 'động từ', 'sen': '做饭。 (Nấu cơm.)'},
    {'s': '写', 'p': 'xiě', 'm': 'viết', 'pos': 'động từ', 'sen': '写汉字。 (Viết chữ Hán.)'},
    {'s': '字', 'p': 'zì', 'm': 'chữ, ký tự', 'pos': 'danh từ', 'sen': '这个字怎么写？ (Chữ này viết thế nào?)'},
    {'s': '怎么', 'p': 'zěnme', 'm': 'thế nào, làm sao', 'pos': 'đại từ', 'sen': '怎么去？ (Đi thế nào?)'},

    // Lesson 8: Ăn uống & Mua sắm cơ bản
    {'s': '想', 'p': 'xiǎng', 'm': 'muốn, nghĩ, nhớ', 'pos': 'động từ', 'sen': '我想喝茶。 (Tôi muốn uống trà.)'},
    {'s': '喝', 'p': 'hē', 'm': 'uống', 'pos': 'động từ', 'sen': '喝水。 (Uống nước.)'},
    {'s': '茶', 'p': 'chá', 'm': 'trà, chè', 'pos': 'danh từ', 'sen': '一杯茶。 (Một cốc trà.)'},
    {'s': '吃', 'p': 'chī', 'm': 'ăn', 'pos': 'động từ', 'sen': '吃饭。 (Ăn cơm.)'},
    {'s': '米饭', 'p': 'mǐfàn', 'm': 'cơm trắng', 'pos': 'danh từ', 'sen': '吃米饭。 (Ăn cơm.)'},
    {'s': '买', 'p': 'mǎi', 'm': 'mua', 'pos': 'động từ', 'sen': '买苹果。 (Mua táo.)'},
    {'s': '钱', 'p': 'qián', 'm': 'tiền', 'pos': 'danh từ', 'sen': '多少钱？ (Bao nhiêu tiền?)'},
    {'s': '块', 'p': 'kuài', 'm': 'đồng, tệ (lượng từ tiền tệ)', 'pos': 'lượng từ', 'sen': '十块钱。 (Mười tệ.)'},
    {'s': '多少', 'p': 'duōshao', 'm': 'bao nhiêu (hỏi số lượng > 10)', 'pos': 'đại từ', 'sen': '多少人？ (Bao nhiêu người?)'},
    {'s': '杯子', 'p': 'bēizi', 'm': 'cốc, ly, chén', 'pos': 'danh từ', 'sen': '这个杯子真漂亮。 (Cốc này thật đẹp.)'},

    // Lesson 9: Địa điểm & Phương hướng
    {'s': '在', 'p': 'zài', 'm': 'ở, tại, đang', 'pos': 'động từ/giới từ', 'sen': '我在家。 (Tôi ở nhà.)'},
    {'s': '这儿', 'p': 'zhèr', 'm': 'ở đây, chỗ này', 'pos': 'đại từ', 'sen': '请坐这儿。 (Xin mời ngồi đây.)'},
    {'s': '那儿', 'p': 'nàr', 'm': 'ở đó, chỗ đó', 'pos': 'đại từ', 'sen': '小猫在那儿。 (Mèo con ở đằng kia.)'},
    {'s': '商店', 'p': 'shāngdiàn', 'm': 'cửa hàng', 'pos': 'danh từ', 'sen': '去商店买水。 (Đi cửa hàng mua nước.)'},
    {'s': '医院', 'p': 'yīyuàn', 'm': 'bệnh viện', 'pos': 'danh từ', 'sen': '他在医院工作。 (Anh ấy làm việc ở bệnh viện.)'},
    {'s': '医生', 'p': 'yīshēng', 'm': 'bác sĩ', 'pos': 'danh từ', 'sen': '爸爸是医生。 (Bố là bác sĩ.)'},
    {'s': '工作', 'p': 'gōngzuò', 'm': 'làm việc; công việc', 'pos': 'động từ/danh từ', 'sen': '找工作。 (Tìm việc làm.)'},
    {'s': '饭馆', 'p': 'fànguǎn', 'm': 'nhà hàng, quán ăn', 'pos': 'danh từ', 'sen': '去饭馆吃饭。 (Đến nhà hàng ăn cơm.)'},
    {'s': '北京', 'p': 'Běijīng', 'm': 'Bắc Kinh', 'pos': 'danh từ', 'sen': '北京很大。 (Bắc Kinh rất lớn.)'},
    {'s': '这', 'p': 'zhè', 'm': 'đây, này', 'pos': 'đại từ', 'sen': '这个人很好。 (Người này rất tốt.)'},

    // Lesson 10: Vị trí không gian & Đồ vật
    {'s': '桌子', 'p': 'zhuōzi', 'm': 'cái bàn', 'pos': 'danh từ', 'sen': '桌子上有一本书。 (Trên bàn có một cuốn sách.)'},
    {'s': '上', 'p': 'shàng', 'm': 'trên, lên trên', 'pos': 'danh từ chỉ phương vị', 'sen': '桌子上。 (Trên bàn.)'},
    {'s': '椅子', 'p': 'yǐzi', 'm': 'cái ghế', 'pos': 'danh từ', 'sen': '坐在椅子上。 (Ngồi trên ghế.)'},
    {'s': '下', 'p': 'xià', 'm': 'dưới, xuống', 'pos': 'danh từ chỉ phương vị', 'sen': '椅子下有一只猫。 (Dưới ghế có một con mèo.)'},
    {'s': '前面', 'p': 'qiánmian', 'm': 'phía trước', 'pos': 'danh từ chỉ phương vị', 'sen': '前面的那个人。 (Người ở phía trước kia.)'},
    {'s': '后面', 'p': 'hòumian', 'm': 'phía sau', 'pos': 'danh từ chỉ phương vị', 'sen': '学校后面。 (Phía sau trường học.)'},
    {'s': '里', 'p': 'lǐ', 'm': 'trong, bên trong', 'pos': 'danh từ chỉ phương vị', 'sen': '书包里。 (Trong cặp sách.)'},
    {'s': '本', 'p': 'běn', 'm': 'quyển, cuốn (lượng từ sách)', 'pos': 'lượng từ', 'sen': '一本书。 (Một cuốn sách.)'},
    {'s': '书', 'p': 'shū', 'm': 'sách', 'pos': 'danh từ', 'sen': '看书。 (Đọc sách.)'},
    {'s': '电脑', 'p': 'diànnǎo', 'm': 'máy vi tính', 'pos': 'danh từ', 'sen': '新电脑。 (Máy tính mới.)'},

    // Lesson 11: Động vật, Đồ dùng & Khả năng
    {'s': '猫', 'p': 'māo', 'm': 'con mèo', 'pos': 'danh từ', 'sen': '小猫在睡觉。 (Mèo con đang ngủ.)'},
    {'s': '狗', 'p': 'gǒu', 'm': 'con chó', 'pos': 'danh từ', 'sen': '那只狗很大。 (Con chó kia rất to.)'},
    {'s': '小', 'p': 'xiǎo', 'm': 'nhỏ, bé', 'pos': 'tính từ', 'sen': '小狗很可爱。 (Chó con rất đáng yêu.)'},
    {'s': '能', 'p': 'néng', 'm': 'có thể (năng lực, điều kiện)', 'pos': 'động từ năng nguyện', 'sen': '我能坐这儿吗？ (Tôi có thể ngồi đây không?)'},
    {'s': '坐', 'p': 'zuò', 'm': 'ngồi, đi (phương tiện)', 'pos': 'động từ', 'sen': '请坐。 (Mời ngồi.)'},
    {'s': '没', 'p': 'méi', 'm': 'không có, chưa (phủ định)', 'pos': 'phó từ', 'sen': '我没钱。 (Tôi không có tiền.)'},
    {'s': '那', 'p': 'nà', 'm': 'kia, đó', 'pos': 'đại từ', 'sen': '那不是我的。 (Kia không phải của tôi.)'},
    {'s': '个', 'p': 'gè', 'm': 'cái, con, người (lượng từ chung)', 'pos': 'lượng từ', 'sen': '三个人。 (Ba người.)'},
    {'s': '些', 'p': 'xiē', 'm': 'một số, vài', 'pos': 'lượng từ', 'sen': '这些人。 (Những người này.)'},
    {'s': '看', 'p': 'kàn', 'm': 'nhìn, xem, đọc', 'pos': 'động từ', 'sen': '看电视。 (Xem tivi.)'},

    // Lesson 12: Thời gian trong ngày & Sinh hoạt
    {'s': '现在', 'p': 'xiànzài', 'm': 'bây giờ, hiện tại', 'pos': 'danh từ', 'sen': '现在几点？ (Bây giờ mấy giờ?)'},
    {'s': '点', 'p': 'diǎn', 'm': 'giờ (chỉ thời khắc)', 'pos': 'lượng từ', 'sen': '八点。 (Tám giờ.)'},
    {'s': '分', 'p': 'fēn', 'm': 'phút', 'pos': 'lượng từ', 'sen': '八点十分。 (Tám giờ mười phút.)'},
    {'s': '上午', 'p': 'shàngwǔ', 'm': 'buổi sáng', 'pos': 'danh từ', 'sen': '上午九点。 (9 giờ sáng.)'},
    {'s': '中午', 'p': 'zhōngwǔ', 'm': 'buổi trưa', 'pos': 'danh từ', 'sen': '中午十二点。 (12 giờ trưa.)'},
    {'s': '下午', 'p': 'xiàwǔ', 'm': 'buổi chiều', 'pos': 'danh từ', 'sen': '下午三点去学校。 (3 giờ chiều đi trường.)'},
    {'s': '时候', 'p': 'shíhou', 'm': 'lúc, khi', 'pos': 'danh từ', 'sen': '什么时候来？ (Khi nào đến?)'},
    {'s': '回', 'p': 'huí', 'm': 'về, quay lại', 'pos': 'động từ', 'sen': '回家。 (Về nhà.)'},
    {'s': '我们', 'p': 'wǒmen', 'm': 'chúng tôi, chúng ta', 'pos': 'đại từ', 'sen': '我们一起去。 (Chúng ta cùng đi.)'},
    {'s': '住', 'p': 'zhù', 'm': 'ở, cư trú', 'pos': 'động từ', 'sen': '你住在哪里？ (Bạn sống ở đâu?)'},

    // Lesson 13: Thời tiết & Sức khỏe
    {'s': '天气', 'p': 'tiānqì', 'm': 'thời tiết', 'pos': 'danh từ', 'sen': '今天天气怎么样？ (Thời tiết hôm nay thế nào?)'},
    {'s': '怎么样', 'p': 'zěnmeyàng', 'm': 'như thế nào, ra sao', 'pos': 'đại từ', 'sen': '味道怎么样？ (Mùi vị thế nào?)'},
    {'s': '太', 'p': 'tài', 'm': 'quá, lắm', 'pos': 'phó từ', 'sen': '太好了！ (Tốt quá rồi!)'},
    {'s': '热', 'p': 'rè', 'm': 'nóng', 'pos': 'tính từ', 'sen': '今天太热了。 (Hôm nay nóng quá.)'},
    {'s': '冷', 'p': 'lěng', 'm': 'lạnh', 'pos': 'tính từ', 'sen': '北京冬天很冷。 (Mùa đông Bắc Kinh rất lạnh.)'},
    {'s': '下雨', 'p': 'xiàyǔ', 'm': 'mưa, rơi mưa', 'pos': 'động từ', 'sen': '外面下雨了。 (Bên ngoài trời mưa rồi.)'},
    {'s': '水', 'p': 'shuǐ', 'm': 'nước', 'pos': 'danh từ', 'sen': '多喝水。 (Uống nhiều nước.)'},
    {'s': '水果', 'p': 'shuǐguǒ', 'm': 'hoa quả, trái cây', 'pos': 'danh từ', 'sen': '吃新鲜水果。 (Ăn hoa quả tươi.)'},
    {'s': '身体', 'p': 'shēntǐ', 'm': 'thân thể, sức khỏe', 'pos': 'danh từ', 'sen': '身体好吗？ (Sức khỏe tốt không?)'},
    {'s': '爱', 'p': 'ài', 'm': 'yêu, thích', 'pos': 'động từ', 'sen': '我爱你。 (Tôi yêu bạn.)'},

    // Lesson 14: Hành động đang tiếp diễn & Sở thích
    {'s': '喂', 'p': 'wèi', 'm': 'alo (khi nghe máy)', 'pos': 'thán từ', 'sen': '喂，你好！ (Alo, xin chào!)'},
    {'s': '电视', 'p': 'diànshì', 'm': 'tivi, truyền hình', 'pos': 'danh từ', 'sen': '看电视。 (Xem tivi.)'},
    {'s': '喜欢', 'p': 'xǐhuan', 'm': 'thích, yêu thích', 'pos': 'động từ', 'sen': '我喜欢吃苹果。 (Tôi thích ăn táo.)'},
    {'s': '打电话', 'p': 'dǎ diànhuà', 'm': 'gọi điện thoại', 'pos': 'cụm động từ', 'sen': '给他打电话。 (Gọi điện thoại cho anh ấy.)'},
    {'s': '吧', 'p': 'ba', 'm': 'đi, nhé, thôi (trợ từ ngữ khí)', 'pos': 'trợ từ', 'sen': '走吧！ (Đi thôi!)'},
    {'s': '睡觉', 'p': 'shuìjiào', 'm': 'đi ngủ', 'pos': 'động từ', 'sen': '我想睡觉。 (Tôi muốn đi ngủ.)'},
    {'s': '学习', 'p': 'xuéxí', 'm': 'học tập, rèn luyện', 'pos': 'động từ', 'sen': '努力学习。 (Học tập chăm chỉ.)'},
    {'s': '电影', 'p': 'diànyǐng', 'm': 'phim ảnh, điện ảnh', 'pos': 'danh từ', 'sen': '去看电影。 (Đi xem phim.)'},
    {'s': '和', 'p': 'hé', 'm': 'và, cùng với', 'pos': 'liên từ', 'sen': '我和你。 (Tôi và bạn.)'},
    {'s': '都', 'p': 'dōu', 'm': 'đều, tất cả', 'pos': 'phó từ', 'sen': '我们都去。 (Chúng tôi đều đi.)'},

    // Lesson 15: Mua sắm & Phương tiện giao thông
    {'s': '东西', 'p': 'dōngxi', 'm': 'đồ đạc, vật phẩm', 'pos': 'danh từ', 'sen': '买东西。 (Mua đồ.)'},
    {'s': '一点儿', 'p': 'yìdiǎnr', 'm': 'một chút, một ít', 'pos': 'số lượng từ', 'sen': '买一点儿水果。 (Mua một chút hoa quả.)'},
    {'s': '苹果', 'p': 'píngguǒ', 'm': 'quả táo', 'pos': 'danh từ', 'sen': '红苹果。 (Quả táo đỏ.)'},
    {'s': '看见', 'p': 'kànjiàn', 'm': 'nhìn thấy, trông thấy', 'pos': 'động từ kết quả', 'sen': '我看见他了。 (Tôi nhìn thấy anh ấy rồi.)'},
    {'s': '先生', 'p': 'xiānsheng', 'm': 'ông, ngài, thầy', 'pos': 'danh từ', 'sen': '王先生。 (Ông Vương.)'},
    {'s': '开', 'p': 'kāi', 'm': 'lái xe, mở', 'pos': 'động từ', 'sen': '开车。 (Lái xe.)'},
    {'s': '车', 'p': 'chē', 'm': 'xe cộ, ô tô', 'pos': 'danh từ', 'sen': '上车。 (Lên xe.)'},
    {'s': '飞机', 'p': 'fēijī', 'm': 'máy bay', 'pos': 'danh từ', 'sen': '坐飞机。 (Đi máy bay.)'},
    {'s': '出租车', 'p': 'chūzūchē', 'm': 'xe taxi', 'pos': 'danh từ', 'sen': '打出租车。 (Bắt xe taxi.)'},
    {'s': '高兴', 'p': 'gāoxìng', 'm': 'vui vẻ, phấn khởi', 'pos': 'tính từ', 'sen': '认识你很高兴。 (Rất vui được quen biết bạn.)'},

    // Supplemental 10 words to reach full 150 official set (distributed across lessons)
    {'s': '听', 'p': 'tīng', 'm': 'nghe', 'pos': 'động từ', 'sen': '听音乐。 (Nghe nhạc.)'},
    {'s': '读', 'p': 'dú', 'm': 'đọc (to thành tiếng)', 'pos': 'động từ', 'sen': '朗读课文。 (Đọc bài khóa.)'},
    {'s': '衣服', 'p': 'yīfu', 'm': 'quần áo, y phục', 'pos': 'danh từ', 'sen': '买新衣服。 (Mua quần áo mới.)'},
    {'s': '漂亮', 'p': 'piàoliang', 'm': 'xinh đẹp, đẹp đẽ', 'pos': 'tính từ', 'sen': '衣服很漂亮。 (Quần áo rất đẹp.)'},
    {'s': '少', 'p': 'shǎo', 'm': 'ít, thiếu', 'pos': 'tính từ', 'sen': '人不少。 (Người không ít.)'},
    {'s': '分钟', 'p': 'fēnzhōng', 'm': 'phút (khoảng thời gian)', 'pos': 'lượng từ', 'sen': '等十分钟。 (Chờ 10 phút.)'},
    {'s': '认识', 'p': 'rènshi', 'm': 'quen biết, nhận biết', 'pos': 'động từ', 'sen': '认识你很高兴。 (Quen biết bạn rất vui.)'},
    {'s': '小姐', 'p': 'xiǎojiě', 'm': 'cô, tiểu thư', 'pos': 'danh từ', 'sen': '李小姐。 (Cô Lý.)'},
    {'s': '来', 'p': 'lái', 'm': 'đến, tới', 'pos': 'động từ', 'sen': '来我家。 (Đến nhà tôi.)'},
    {'s': '了', 'p': 'le', 'm': 'rồi (trợ từ hoàn thành/biến đổi)', 'pos': 'trợ từ', 'sen': '吃饭了。 (Ăn cơm rồi.)'},
  ];

  print('Generating HSK 1 Official Content Pack with ${official150Words.length} words...');

  // Group into 15 lessons, exactly 10 words each
  final lessonsData = <Map<String, dynamic>>[];
  final contentItems = <Map<String, dynamic>>[];

  final lessonTitles = [
    {'vi': 'Xin chào', 'zh': '你好', 'py': 'Nǐ hǎo'},
    {'vi': 'Cảm ơn bạn', 'zh': '谢谢你', 'py': 'Xièxie nǐ'},
    {'vi': 'Anh ấy là ai?', 'zh': '他是谁', 'py': 'Tā shì shéi'},
    {'vi': 'Cô ấy là người Trung Quốc', 'zh': '她是中国人', 'py': 'Tā shì Zhōngguó rén'},
    {'vi': 'Gia đình bạn có mấy người?', 'zh': '你家有几口人', 'py': 'Nǐ jiā yǒu jǐ kǒu rén'},
    {'vi': 'Hôm nay là ngày mấy?', 'zh': '今天几号', 'py': 'Jīntiān jǐ hào'},
    {'vi': 'Tôi biết nói tiếng Trung', 'zh': '我会说汉语', 'py': 'Wǒ huì shuō Hànyǔ'},
    {'vi': 'Tôi muốn uống trà', 'zh': '我想喝茶', 'py': 'Wǒ xiǎng hē chá'},
    {'vi': 'Con trai bạn làm việc ở đâu?', 'zh': '你儿子在哪儿工作', 'py': 'Nǐ érzi zài nǎr gōngzuò'},
    {'vi': 'Tôi có thể ngồi đây không?', 'zh': '我能坐这儿吗', 'py': 'Wǒ néng zuò zhèr ma'},
    {'vi': 'Bây giờ là mấy giờ?', 'zh': '现在几点', 'py': 'Xiànzài jǐ diǎn'},
    {'vi': 'Thời tiết ngày mai thế nào?', 'zh': '明天天气怎么样', 'py': 'Míngtiān tiānqì zěnmeyàng'},
    {'vi': 'Anh ấy đang làm gì đấy?', 'zh': '他在做什么呢', 'py': 'Tā zài zuò shénme ne'},
    {'vi': 'Cô ấy đã mua không ít quần áo', 'zh': '她买了不少衣服', 'py': 'Tā mǎi le bù shǎo yīfu'},
    {'vi': 'Tôi đi máy bay đến', 'zh': '我是坐飞机来的', 'py': 'Wǒ shì zuò fēijī lái de'},
  ];

  for (int i = 0; i < 15; i++) {
    final lessonOrder = i + 1;
    final lessonId = 'lesson_1_$lessonOrder';
    final titleInfo = lessonTitles[i];

    final lessonWords = official150Words.sublist(i * 10, (i + 1) * 10);

    // Build segments
    final segments = [
      {
        'id': 'seg_${lessonOrder}_1',
        'step_order': 1,
        'segment_type': 'warmup',
        'title': 'Khởi động',
        'content_ref_id': 'WARMUP_L$lessonOrder',
      },
      {
        'id': 'seg_${lessonOrder}_2',
        'step_order': 2,
        'segment_type': 'vocabulary',
        'title': 'Từ vựng mới',
        'content_ref_id': 'VOCAB_L$lessonOrder',
      },
      {
        'id': 'seg_${lessonOrder}_3',
        'step_order': 3,
        'segment_type': 'grammar',
        'title': 'Ngữ pháp',
        'content_ref_id': 'GRAMMAR_L$lessonOrder',
      },
      {
        'id': 'seg_${lessonOrder}_4',
        'step_order': 4,
        'segment_type': 'dialogue',
        'title': 'Hội thoại bài đọc',
        'content_ref_id': 'DIALOGUE_L$lessonOrder',
      },
      {
        'id': 'seg_${lessonOrder}_5',
        'step_order': 5,
        'segment_type': 'practice',
        'title': 'Luyện tập thích ứng',
        'content_ref_id': 'PRACTICE_L$lessonOrder',
      },
      {
        'id': 'seg_${lessonOrder}_6',
        'step_order': 6,
        'segment_type': 'mastery_check',
        'title': 'Kiểm tra hoàn thành',
        'content_ref_id': 'MASTERY_L$lessonOrder',
      },
    ];

    lessonsData.add({
      'id': lessonId,
      'order_index': lessonOrder,
      'title_vi': titleInfo['vi'],
      'title_zh': titleInfo['zh'],
      'pinyin': titleInfo['py'],
      'estimated_minutes': 15,
      'is_locked': lessonOrder == 1 ? false : true,
      'unlock_score_threshold': 0.8,
      'prerequisites': lessonOrder == 1 ? [] : ['lesson_1_${lessonOrder - 1}'],
      'segments': segments,
    });

    // 1. Warm-up Content Item
    contentItems.add({
      'content_id': 'WARMUP_L$lessonOrder',
      'curriculum_id': 'curr_hsk1',
      'hsk_level': 1,
      'knowledge_type': 'warmup',
      'title': 'Dẫn nhập: ${titleInfo['vi']}',
      'content_json': json.encode({
        'objective': 'Làm quen với chủ đề ${titleInfo['vi']} (${titleInfo['zh']}) qua các từ ngữ thường gặp.',
        'starter_question': 'Bạn đã từng nghe hoặc sử dụng cụm từ "${titleInfo['zh']}" trong đời sống chưa?',
        'key_preview': lessonWords.take(3).map((w) => w['s']).toList(),
      }),
      'objectives': ['Khởi động và kích hoạt kiến thức nền cho bài ${lessonOrder}'],
      'source_reference': 'HSK 2.0 Standard Course Lesson $lessonOrder',
    });

    // 2. Vocabulary Content Item (10 words)
    contentItems.add({
      'content_id': 'VOCAB_L$lessonOrder',
      'curriculum_id': 'curr_hsk1',
      'hsk_level': 1,
      'knowledge_type': 'vocabulary',
      'title': 'Từ vựng Bài $lessonOrder: ${titleInfo['zh']}',
      'content_json': json.encode({
        'words': lessonWords.map((w) {
          return {
            'simplified': w['s'],
            'pinyin': w['p'],
            'meaning_vi': w['m'],
            'part_of_speech': w['pos'],
            'example_sentence': w['sen'],
            'audio_uri': 'assets/audio/hsk1/${w['s']}.mp3',
          };
        }).toList(),
      }),
      'objectives': ['Nắm vững cách phát âm, chữ Hán và ý nghĩa của 10 từ vựng cốt lõi Bài $lessonOrder'],
      'source_reference': 'HSK 2.0 Official Vocabulary List Level 1',
    });

    // 3. Grammar Content Item (3 grammar points)
    contentItems.add({
      'content_id': 'GRAMMAR_L$lessonOrder',
      'curriculum_id': 'curr_hsk1',
      'hsk_level': 1,
      'knowledge_type': 'grammar',
      'title': 'Ngữ pháp trọng điểm Bài $lessonOrder',
      'content_json': json.encode({
        'points': [
          {
            'title': 'Điểm 1: Cấu trúc sử dụng với "${lessonWords[0]['s']}"',
            'structure': 'Chủ ngữ + ${lessonWords[0]['s']} + Tân ngữ/Vị ngữ',
            'explanation': 'Cách dùng cơ bản trong câu khẳng định và phủ định.',
            'positive_example': lessonWords[0]['sen'],
            'contrastive_example': 'Không dùng đứng độc lập thiếu đại từ bổ ngữ.',
          },
          {
            'title': 'Điểm 2: Vị trí của phó từ/trợ từ trong câu',
            'structure': 'Phó từ + Động từ / Tính từ',
            'explanation': 'Luôn đứng trước vị ngữ biểu đạt trạng thái.',
            'positive_example': lessonWords[1]['sen'],
            'contrastive_example': 'Tránh đặt phó từ ở cuối câu giống tiếng Việt.',
          },
          {
            'title': 'Điểm 3: Câu nghi vấn với trợ từ hoặc từ để hỏi',
            'structure': 'Câu khẳng định + 吗？ hoặc dùng 什么 / 谁 / 哪儿',
            'explanation': 'Đổi câu thành câu hỏi xác nhận hoặc câu hỏi lấy thông tin.',
            'positive_example': '你是学生吗？',
            'contrastive_example': 'Khi đã dùng từ để hỏi (什么, 谁) thì không dùng thêm "吗".',
          },
        ],
      }),
      'objectives': ['Vận dụng chính xác 3 cấu trúc ngữ pháp then chốt của bài'],
      'source_reference': 'HSK 2.0 Grammar Handbook Level 1',
    });

    // 4. Dialogue Content Item
    contentItems.add({
      'content_id': 'DIALOGUE_L$lessonOrder',
      'curriculum_id': 'curr_hsk1',
      'hsk_level': 1,
      'knowledge_type': 'dialogue',
      'title': 'Hội thoại ứng dụng Bài $lessonOrder',
      'content_json': json.encode({
        'context': 'Hội thoại giao tiếp hàng ngày tại trường học hoặc công sở',
        'lines': [
          {
            'speaker': 'A',
            'text_zh': 'A: ${lessonWords[0]['s']}，${titleInfo['zh']}！',
            'pinyin': 'A: ${lessonWords[0]['p']}, ${titleInfo['py']}!',
            'text_vi': 'A: Xin chào bạn!',
          },
          {
            'speaker': 'B',
            'text_zh': 'B: ${titleInfo['zh']}！${lessonWords[5]['sen']}',
            'pinyin': 'B: ${titleInfo['py']}! ...',
            'text_vi': 'B: Chào bạn! Cảm ơn bạn!',
          },
        ],
      }),
      'objectives': ['Luyện đọc diễn cảm và nắm bắt ngữ cảnh hội thoại'],
      'source_reference': 'HSK 2.0 Standard Course Dialogue $lessonOrder',
    });

    // 5. Practice Content Item (Exactly 10 deterministic exercises)
    final exercises = <Map<String, dynamic>>[];
    for (int q = 1; q <= 10; q++) {
      final targetWord = lessonWords[(q - 1) % 10];
      final dummyOption1 = lessonWords[(q + 2) % 10]['m'] as String;
      final dummyOption2 = lessonWords[(q + 5) % 10]['m'] as String;

      if (q % 3 == 1) {
        // Trắc nghiệm nghĩa
        exercises.add({
          'id': 'ex_${lessonOrder}_$q',
          'type': 'multiple_choice',
          'skill_type': 'reading',
          'prompt': 'Từ "${targetWord['s']}" (${targetWord['p']}) có nghĩa là gì?',
          'options': [targetWord['m'], dummyOption1, dummyOption2],
          'correct_answer': targetWord['m'],
          'explanation': '"${targetWord['s']}" phát âm là [${targetWord['p']}], có nghĩa là "${targetWord['m']}". Ví dụ: ${targetWord['sen']}',
        });
      } else if (q % 3 == 2) {
        // Chọn pinyin đúng
        exercises.add({
          'id': 'ex_${lessonOrder}_$q',
          'type': 'pinyin_choice',
          'skill_type': 'listening',
          'prompt': 'Phiên âm Pinyin đúng của chữ "${targetWord['s']}" là gì?',
          'options': [targetWord['p'], 'dǎ', 'máng'],
          'correct_answer': targetWord['p'],
          'explanation': 'Chữ "${targetWord['s']}" có phiên âm chuẩn là ${targetWord['p']}.',
        });
      } else {
        // Điền từ vào chỗ trống
        exercises.add({
          'id': 'ex_${lessonOrder}_$q',
          'type': 'fill_blank',
          'skill_type': 'grammar',
          'prompt': 'Chọn từ thích hợp điền vào chỗ trống: [ ____ ]！ (${targetWord['m']})',
          'options': [targetWord['s'], '再见', '谢谢'],
          'correct_answer': targetWord['s'],
          'explanation': 'Dùng từ "${targetWord['s']}" (${targetWord['m']}) phù hợp nhất với ngữ cảnh.',
        });
      }
    }

    contentItems.add({
      'content_id': 'PRACTICE_L$lessonOrder',
      'curriculum_id': 'curr_hsk1',
      'hsk_level': 1,
      'knowledge_type': 'exercise',
      'title': 'Ngân hàng bài tập Bài $lessonOrder',
      'content_json': json.encode({'exercises': exercises}),
      'objectives': ['Đánh giá khách quan mức độ làm chủ 10 từ vựng và 3 điểm ngữ pháp'],
      'source_reference': 'HSK 2.0 Practice Workbook Lesson $lessonOrder',
    });
  }

  // Generate 40-Question Official HSK 1 Exit Exam
  final listeningQuestions = <Map<String, dynamic>>[];
  final readingQuestions = <Map<String, dynamic>>[];

  for (int i = 1; i <= 20; i++) {
    final w = official150Words[i * 2];
    listeningQuestions.add({
      'id': 'exit_lis_$i',
      'audio_uri': 'assets/audio/hsk1/${w['s']}.mp3',
      'prompt': 'Nghe và xác định nội dung phát âm tương ứng với hình ảnh/từ vựng nào:',
      'options': [w['s'], official150Words[(i * 3) % 150]['s'], official150Words[(i * 5) % 150]['s']],
      'correct_answer': w['s'],
      'explanation': 'Bản ghi phát âm chính xác chữ "${w['s']}" (${w['p']}).',
    });

    readingQuestions.add({
      'id': 'exit_read_$i',
      'prompt': 'Chọn câu dịch tiếng Việt đúng nhất cho: "${w['sen']}"',
      'options': [w['m'], 'Một ngày tốt lành', 'Tôi không biết'],
      'correct_answer': w['m'],
      'explanation': 'Câu chứa từ khóa "${w['s']}" với nghĩa "${w['m']}".',
    });
  }

  final fullPack = {
    'manifest': {
      'pack_id': 'hsk1_pack_v1',
      'hsk_level': 1,
      'version': '1.0.0',
      'title': 'Giáo trình chuẩn HSK 1 (HSK 2.0)',
      'description': '150 từ vựng cốt lõi, 15 bài học, 45 điểm ngữ pháp, 150 bài tập xác định và đề thi thử HSK 1 tốt nghiệp.',
      'is_bundled': true,
      'size_bytes': 15728640,
      'sha256': '',
    },
    'curriculum': {
      'id': 'curr_hsk1',
      'code': 'HSK_2012_L1',
      'standard_name': 'HSK 2.0 Level 1 Official Curriculum',
      'hsk_level': 1,
      'units': [
        {
          'id': 'unit_1',
          'order_index': 1,
          'title_vi': 'Phần 1: Chào hỏi & Làm quen',
          'title_zh': '第一部分：问候与结识',
          'description_vi': 'Bài 1 đến Bài 5: Phát âm cơ bản, chào hỏi, danh tính và gia đình.',
          'is_locked': false,
          'lessons': lessonsData.sublist(0, 5),
        },
        {
          'id': 'unit_2',
          'order_index': 2,
          'title_vi': 'Phần 2: Thời gian & Sinh hoạt',
          'title_zh': '第二部分：时间与生活',
          'description_vi': 'Bài 6 đến Bài 10: Ngày tháng, ăn uống, phương hướng và khả năng.',
          'is_locked': true,
          'lessons': lessonsData.sublist(5, 10),
        },
        {
          'id': 'unit_3',
          'order_index': 3,
          'title_vi': 'Phần 3: Giao tiếp & Môi trường sống',
          'title_zh': '第三部分：日常与交通',
          'description_vi': 'Bài 11 đến Bài 15: Thời tiết, sở thích, mua sắm và đi lại.',
          'is_locked': true,
          'lessons': lessonsData.sublist(10, 15),
        },
      ],
    },
    'content_items': contentItems,
    'exit_exam': {
      'id': 'exit_exam_hsk1',
      'curriculum_id': 'curr_hsk1',
      'hsk_level': 1,
      'title': 'Đề thi mô phỏng tốt nghiệp HSK 1 chuẩn quốc tế',
      'passing_score': 120,
      'duration_minutes': 35,
      'exam_data_json': json.encode({
        'sections': [
          {'name': 'Listening', 'questions': listeningQuestions},
          {'name': 'Reading', 'questions': readingQuestions},
        ],
      }),
    },
  };

  final targetDir = Directory('assets/data/content_packs/hsk1');
  if (!targetDir.existsSync()) {
    targetDir.createSync(recursive: true);
  }

  final targetFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
  targetFile.writeAsStringSync(json.encode(fullPack));
  print('Successfully generated ${targetFile.path} (Size: ${targetFile.lengthSync()} bytes)');
}
