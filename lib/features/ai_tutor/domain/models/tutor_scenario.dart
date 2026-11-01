/// Represents a thematic conversation scenario for interactive roleplay.
class TutorScenario {
  final String code;
  final String titleVi;
  final String titleZh;
  final String descriptionVi;
  final String iconName;
  final int suggestedHskLevel;
  final String initialAiGreetingZh;
  final String initialAiGreetingPinyin;
  final String initialAiGreetingVi;
  final String contextPrompt;

  const TutorScenario({
    required this.code,
    required this.titleVi,
    required this.titleZh,
    required this.descriptionVi,
    required this.iconName,
    required this.suggestedHskLevel,
    required this.initialAiGreetingZh,
    required this.initialAiGreetingPinyin,
    required this.initialAiGreetingVi,
    required this.contextPrompt,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'title_vi': titleVi,
      'title_zh': titleZh,
      'description_vi': descriptionVi,
      'icon_name': iconName,
      'suggested_hsk_level': suggestedHskLevel,
      'initial_ai_greeting_zh': initialAiGreetingZh,
      'initial_ai_greeting_pinyin': initialAiGreetingPinyin,
      'initial_ai_greeting_vi': initialAiGreetingVi,
    };
  }
}

/// Catalog of supported conversation scenarios.
class TutorScenarios {
  TutorScenarios._();

  static const TutorScenario freeChat = TutorScenario(
    code: 'free_chat',
    titleVi: 'Hội thoại tự do',
    titleZh: '自由交谈',
    descriptionVi: 'Trò chuyện thoải mái về mọi chủ đề trong cuộc sống, học tập và sở thích.',
    iconName: 'chat_bubble_outline',
    suggestedHskLevel: 1,
    initialAiGreetingZh: '你好！今天过得怎么样？你想聊点什么呢？',
    initialAiGreetingPinyin: 'Nǐ hǎo! Jīntiān guò de zěnmeyàng? Nǐ xiǎng liáo diǎn shénme ne?',
    initialAiGreetingVi: 'Chào bạn! Hôm nay thế nào rồi? Bạn muốn trò chuyện về chủ đề gì nào?',
    contextPrompt: 'Bối cảnh: Cuộc trò chuyện tự do thân mật hàng ngày. Hãy hỏi thăm và gợi mở các chủ đề quen thuộc.',
  );

  static const TutorScenario restaurant = TutorScenario(
    code: 'restaurant',
    titleVi: 'Gọi món tại nhà hàng',
    titleZh: '餐厅点餐',
    descriptionVi: 'Thực hành gọi món, hỏi hương vị món ăn, yêu cầu phục vụ và thanh toán.',
    iconName: 'restaurant',
    suggestedHskLevel: 2,
    initialAiGreetingZh: '您好！欢迎光临！请问几位？想吃点什么？',
    initialAiGreetingPinyin: 'Nín hǎo! Huānyíng guānglín! Qǐngwèn jǐ wèi? Xiǎng chī diǎn shénme?',
    initialAiGreetingVi: 'Kính chào quý khách! Hoan nghênh ghé thăm! Xin hỏi quý khách đi mấy người ạ? Muốn dùng món gì?',
    contextPrompt: 'Bối cảnh: Nhà hàng Trung Hoa. Bạn là người phục vụ lịch sự và nhiệt tình. Học viên là thực khách. Giới thiệu món ăn đặc trưng và hướng dẫn cách gọi món.',
  );

  static const TutorScenario shopping = TutorScenario(
    code: 'shopping',
    titleVi: 'Mua sắm & Trả giá',
    titleZh: '商场购物',
    descriptionVi: 'Hỏi giá, kích cỡ, màu sắc và thực hành các mẫu câu mặc cả giá khéo léo.',
    iconName: 'shopping_bag_outlined',
    suggestedHskLevel: 2,
    initialAiGreetingZh: '你好！想看点什么衣服？这件外套今天打八折哦！',
    initialAiGreetingPinyin: 'Nǐ hǎo! Xiǎng kàn diǎn shénme yīfu? Zhè jiàn wàitào jīntiān dǎ bā zhé ó!',
    initialAiGreetingVi: 'Chào bạn! Bạn muốn xem quần áo loại nào? Chiếc áo khoác này hôm nay giảm 20% đấy nhé!',
    contextPrompt: 'Bối cảnh: Cửa hàng thời trang. Bạn là chủ quán thân thiện. Học viên hỏi mua đồ và có thể mặc cả giá.',
  );

  static const TutorScenario askingDirections = TutorScenario(
    code: 'asking_directions',
    titleVi: 'Hỏi đường tại Trung Quốc',
    titleZh: '问路出行',
    descriptionVi: 'Hỏi đường đến ga tàu điện ngầm, địa danh nổi tiếng, hỏi phương tiện di chuyển.',
    iconName: 'map_outlined',
    suggestedHskLevel: 2,
    initialAiGreetingZh: '你好，看你好像在找路，需要帮忙吗？',
    initialAiGreetingPinyin: 'Nǐ hǎo, kàn nǐ hǎoxiàng zài zhǎo lù, xūyào bāngmáng ma?',
    initialAiGreetingVi: 'Chào bạn, trông bạn có vẻ đang tìm đường, cần mình giúp gì không?',
    contextPrompt: 'Bối cảnh: Trên đường phố Bắc Kinh. Bạn là người dân bản xứ nhiệt tình chỉ đường (rẽ trái, đi thẳng, qua ngã tư, tuyến metro).',
  );

  static const TutorScenario hotelCheckin = TutorScenario(
    code: 'hotel_checkin',
    titleVi: 'Nhận phòng khách sạn',
    titleZh: '酒店入住',
    descriptionVi: 'Check-in khách sạn, hỏi mật khẩu Wi-Fi, yêu cầu bữa sáng và dịch vụ phòng.',
    iconName: 'hotel_outlined',
    suggestedHskLevel: 3,
    initialAiGreetingZh: '您好！请问您有预订吗？请出示一下您的护照。',
    initialAiGreetingPinyin: 'Nín hǎo! Qǐngwèn nín yǒu yùdìng ma? Qǐng chūshì yíxià nín de hùzhào.',
    initialAiGreetingVi: 'Xin chào quý khách! Xin hỏi quý khách đã đặt phòng trước chưa ạ? Xin vui lòng xuất trình hộ chiếu.',
    contextPrompt: 'Bối cảnh: Quầy lễ tân khách sạn 4 sao. Bạn là nhân viên lễ tân chuyên nghiệp, kiểm tra đặt phòng và trả lời thắc mắc của khách.',
  );

  static const TutorScenario airport = TutorScenario(
    code: 'airport',
    titleVi: 'Tại sân bay & Hải quan',
    titleZh: '机场值机',
    descriptionVi: 'Làm thủ tục chuyến bay, ký gửi hành lý, qua cửa kiểm tra an ninh và hải quan.',
    iconName: 'flight_takeoff',
    suggestedHskLevel: 3,
    initialAiGreetingZh: '您好！请把登机牌和行李放这里。请问有需要托运的行李吗？',
    initialAiGreetingPinyin: 'Nín hǎo! Qǐng bǎ dēngjīpái hé xíngli fàng zhèlǐ. Qǐngwèn yǒu xūyào tuōyùn de xíngli ma?',
    initialAiGreetingVi: 'Xin chào! Xin vui lòng để thẻ lên máy bay và hành lý ở đây. Quý khách có hành lý ký gửi không ạ?',
    contextPrompt: 'Bối cảnh: Quầy làm thủ tục check-in tại sân bay quốc tế. Bạn là nhân viên hãng hàng không hướng dẫn cân hành lý và cổng lên máy bay.',
  );

  static const TutorScenario jobInterview = TutorScenario(
    code: 'job_interview',
    titleVi: 'Phỏng vấn xin việc',
    titleZh: '求职面试',
    descriptionVi: 'Giới thiệu bản thân, trình bày kinh nghiệm, điểm mạnh và trả lời câu hỏi nhà tuyển dụng.',
    iconName: 'work_outline',
    suggestedHskLevel: 4,
    initialAiGreetingZh: '你好，请坐。先用一两分钟简单做一个自我介绍吧。',
    initialAiGreetingPinyin: 'Nǐ hǎo, qǐng zuò. Xiān yòng yì liǎng fēnzhōng jiǎndān zuò yí gè zìwǒ jièshào ba.',
    initialAiGreetingVi: 'Chào bạn, mời ngồi. Trước hết hãy dành 1-2 phút giới thiệu ngắn gọn về bản thân nhé.',
    contextPrompt: 'Bối cảnh: Phòng phỏng vấn công ty công nghệ/thương mại. Bạn là người phỏng vấn chuyên nghiệp, đặt câu hỏi tình huống và đánh giá phong thái ứng viên.',
  );

  static const List<TutorScenario> all = [
    freeChat,
    restaurant,
    shopping,
    askingDirections,
    hotelCheckin,
    airport,
    jobInterview,
  ];

  static TutorScenario get defaultScenario => freeChat;

  static TutorScenario fromCode(String? code) {
    if (code == null) return defaultScenario;
    return all.firstWhere(
      (s) => s.code == code,
      orElse: () => defaultScenario,
    );
  }
}
