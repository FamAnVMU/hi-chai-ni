import 'package:flutter/material.dart';
import '../../data/hanzi_repository.dart';
import '../../domain/models/hanzi_models.dart';
import '../widgets/hanzi_writing_canvas.dart';

/// Comprehensive Chinese Character Writing & Stroke Simulation Screen
/// Supports Learn Mode (stroke-by-stroke animation), Practice Mode (guided handwriting),
/// and Test Mode (freehand quiz with strict scoring and SRS tracking).
class HanziWritingScreen extends StatefulWidget {
  final String initialCharacter;
  final List<String> wordCharacters;
  final String? wordTitle;
  final HanziRepository repository;

  const HanziWritingScreen({
    super.key,
    required this.initialCharacter,
    this.wordCharacters = const [],
    this.wordTitle,
    required this.repository,
  });

  @override
  State<HanziWritingScreen> createState() => _HanziWritingScreenState();
}

class _HanziWritingScreenState extends State<HanziWritingScreen>
    with SingleTickerProviderStateMixin {
  late String _currentChar;
  HanziCharacter? _character;
  bool _isLoading = true;

  WritingMode _mode = WritingMode.learn;
  WritingGridType _gridType = WritingGridType.miZiGe;
  bool _showOutline = true;
  bool _showStrokeNumbers = false;
  bool _showHint = false;

  // Animation state (Learn mode)
  late AnimationController _animController;
  int _animatingStrokeIndex = 0;
  bool _isPlaying = false;
  double _animationSpeed = 1.0;

  // Practice & Test state
  int _completedStrokes = 0;
  int _mistakesCount = 0;
  int _orderErrorsCount = 0;
  String? _feedbackMessage;
  bool _isSuccessFeedback = false;

  @override
  void initState() {
    super.initState();
    _currentChar = widget.initialCharacter;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _animController.addListener(() {
      setState(() {});
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStrokeAnimationCompleted();
      }
    });

    _loadCharacter(_currentChar);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCharacter(String char) async {
    setState(() {
      _isLoading = true;
      _currentChar = char;
      _completedStrokes = 0;
      _mistakesCount = 0;
      _orderErrorsCount = 0;
      _feedbackMessage = null;
    });

    final data = await widget.repository.getCharacter(char);
    if (mounted) {
      setState(() {
        _character = data;
        _isLoading = false;
      });

      if (_mode == WritingMode.learn && data != null && data.strokes.isNotEmpty) {
        _startFullAnimation();
      }
    }
  }

  void _onStrokeAnimationCompleted() {
    if (!_isPlaying || _character == null) return;

    if (_animatingStrokeIndex < _character!.strokes.length - 1) {
      setState(() {
        _animatingStrokeIndex++;
      });
      _animController.reset();
      _animController.duration = Duration(
        milliseconds: (700 / _animationSpeed).round(),
      );
      _animController.forward();
    } else {
      // Completed all strokes
      setState(() {
        _isPlaying = false;
        _animatingStrokeIndex = _character!.strokes.length - 1;
      });
    }
  }

  void _startFullAnimation() {
    if (_character == null || _character!.strokes.isEmpty) return;
    setState(() {
      _isPlaying = true;
      _animatingStrokeIndex = 0;
    });
    _animController.reset();
    _animController.duration = Duration(
      milliseconds: (700 / _animationSpeed).round(),
    );
    _animController.forward();
  }

  void _pauseAnimation() {
    setState(() {
      _isPlaying = false;
    });
    _animController.stop();
  }

  void _resumeAnimation() {
    if (_character == null || _character!.strokes.isEmpty) return;
    setState(() {
      _isPlaying = true;
    });
    _animController.forward();
  }

  void _stepPreviousStroke() {
    _pauseAnimation();
    if (_animatingStrokeIndex > 0) {
      setState(() {
        _animatingStrokeIndex--;
      });
      _animController.value = 1.0;
    }
  }

  void _stepNextStroke() {
    _pauseAnimation();
    if (_character != null && _animatingStrokeIndex < _character!.strokes.length - 1) {
      setState(() {
        _animatingStrokeIndex++;
      });
      _animController.value = 1.0;
    }
  }

  void _onStrokeDrawn(StrokeValidationResult result) {
    if (_character == null) return;

    if (result.isMatch) {
      setState(() {
        _completedStrokes++;
        _showHint = false;
        _feedbackMessage = result.message;
        _isSuccessFeedback = true;
      });

      // Check if finished entire character
      if (_completedStrokes >= _character!.strokes.length) {
        _onCharacterCompleted();
      }
    } else {
      setState(() {
        _mistakesCount++;
        if (result.isWrongOrder) {
          _orderErrorsCount++;
        }
        _feedbackMessage = result.message;
        _isSuccessFeedback = false;
      });
    }
  }

  Future<void> _onCharacterCompleted() async {
    final mistakePenalty = (_mistakesCount * 12.0).clamp(0.0, 50.0);
    final finalAccuracy = (100.0 - mistakePenalty).clamp(50.0, 100.0);

    setState(() {
      _feedbackMessage = 'Chúc mừng! Bạn đã hoàn thành chữ ${_character!.character}';
      _isSuccessFeedback = true;
    });

    // Record attempt in database
    await widget.repository.recordPracticeAttempt(
      character: _character!.character,
      accuracy: finalAccuracy,
      mistakes: _mistakesCount,
      strokeOrderErrors: _orderErrorsCount,
      isTestMode: _mode == WritingMode.test,
    );

    if (!mounted) return;

    if (_mode == WritingMode.test) {
      _showCompletionDialog(finalAccuracy);
    }
  }

  void _showCompletionDialog(double accuracy) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              accuracy >= 80 ? Icons.stars : Icons.check_circle_outline,
              color: accuracy >= 80 ? Colors.amber : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Kết quả kiểm tra', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    _character!.character,
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Độ chính xác: ${accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accuracy >= 80 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Tổng số nét:', '${_character!.strokeCount} nét'),
            _buildStatRow('Lỗi sai nét:', '$_mistakesCount lần'),
            _buildStatRow('Lỗi sai thứ tự nét:', '$_orderErrorsCount lần'),
            _buildStatRow('Đánh giá:', accuracy >= 90 ? 'Xuất sắc' : (accuracy >= 75 ? 'Khá' : 'Cần ôn thêm')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetWriting();
            },
            child: const Text('Viết lại'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _nextCharacterOrClose();
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  void _nextCharacterOrClose() {
    if (widget.wordCharacters.isNotEmpty) {
      final currentIdx = widget.wordCharacters.indexOf(_currentChar);
      if (currentIdx >= 0 && currentIdx < widget.wordCharacters.length - 1) {
        _loadCharacter(widget.wordCharacters[currentIdx + 1]);
        return;
      }
    }
    _resetWriting();
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _resetWriting() {
    setState(() {
      _completedStrokes = 0;
      _mistakesCount = 0;
      _orderErrorsCount = 0;
      _feedbackMessage = null;
      _showHint = false;
    });
  }

  void _undoLastStroke() {
    if (_completedStrokes > 0) {
      setState(() {
        _completedStrokes--;
        _feedbackMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wordTitle != null ? 'Luyện viết: ${widget.wordTitle}' : 'Luyện viết chữ Hán'),
        elevation: 0,
        actions: [
          // Grid style toggle
          IconButton(
            tooltip: 'Đổi kiểu khung kẻ ô',
            icon: Icon(
              _gridType == WritingGridType.miZiGe
                  ? Icons.grid_4x4
                  : (_gridType == WritingGridType.tianZiGe ? Icons.crop_square : Icons.border_clear),
            ),
            onPressed: () {
              setState(() {
                if (_gridType == WritingGridType.miZiGe) {
                  _gridType = WritingGridType.tianZiGe;
                } else if (_gridType == WritingGridType.tianZiGe) {
                  _gridType = WritingGridType.none;
                } else {
                  _gridType = WritingGridType.miZiGe;
                }
              });
            },
          ),
          // Outline toggle
          IconButton(
            tooltip: _showOutline ? 'Ẩn nét mờ' : 'Hiện nét mờ',
            icon: Icon(_showOutline ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showOutline = !_showOutline;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _character == null
              ? _buildUnsupportedView()
              : Column(
                  children: [
                    // Multi-character word selector chips
                    if (widget.wordCharacters.length > 1) _buildWordCharactersSelector(),

                    // Character Header Card
                    _buildCharacterHeader(),

                    // Mode Segmented Buttons
                    _buildModeSelector(),

                    // Interactive Writing Canvas Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            // Canvas
                            Expanded(
                              child: HanziWritingCanvas(
                                character: _character,
                                completedStrokesCount: _mode == WritingMode.learn
                                    ? _animatingStrokeIndex
                                    : _completedStrokes,
                                activeStrokeIndex: _mode == WritingMode.learn
                                    ? _animatingStrokeIndex
                                    : null,
                                animationProgress: _mode == WritingMode.learn
                                    ? _animController.value
                                    : 1.0,
                                showOutline: _mode == WritingMode.test ? _showOutline && false : _showOutline,
                                showStrokeNumbers: _showStrokeNumbers,
                                isInteractive: _mode != WritingMode.learn,
                                gridType: _gridType,
                                showHint: _showHint,
                                onStrokeCompleted: _onStrokeDrawn,
                              ),
                            ),

                            // Feedback message banner
                            if (_feedbackMessage != null) _buildFeedbackBanner(),
                          ],
                        ),
                      ),
                    ),

                    // Controls Toolbar at Bottom
                    _buildBottomControls(),
                  ],
                ),
    );
  }

  Widget _buildUnsupportedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Chữ "$_currentChar" hiện chưa có dữ liệu nét viết.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống HI Chinese chỉ sử dụng dữ liệu nét chuẩn xác định nguồn gốc. Chúng tôi sẽ cập nhật trong các gói học liệu tiếp theo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCharactersSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          const Text('Từ ghép:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.wordCharacters.map((c) {
                  final isSelected = c == _currentChar;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && c != _currentChar) {
                          _loadCharacter(c);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterHeader() {
    final c = _character!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Glyph
          Text(
            c.character,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, height: 1.1),
          ),
          const SizedBox(width: 14),
          // Readings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.pinyin,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    if (c.hanviet.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${c.hanviet})',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.meaningVi.isNotEmpty ? c.meaningVi : c.definitionEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
          // Badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'HSK ${c.hskLevel}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${c.strokeCount} nét',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<WritingMode>(
        segments: const [
          ButtonSegment(
            value: WritingMode.learn,
            icon: Icon(Icons.play_circle_outline, size: 18),
            label: Text('Học viết'),
          ),
          ButtonSegment(
            value: WritingMode.practice,
            icon: Icon(Icons.edit_note, size: 18),
            label: Text('Luyện tập'),
          ),
          ButtonSegment(
            value: WritingMode.test,
            icon: Icon(Icons.quiz, size: 18),
            label: Text('Kiểm tra'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (newSelection) {
          final selected = newSelection.first;
          setState(() {
            _mode = selected;
            _resetWriting();
            if (selected == WritingMode.learn) {
              _startFullAnimation();
            } else {
              _pauseAnimation();
            }
          });
        },
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isSuccessFeedback ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isSuccessFeedback ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccessFeedback ? Icons.check_circle : Icons.warning_amber,
            color: _isSuccessFeedback ? Colors.green.shade700 : Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: TextStyle(
                color: _isSuccessFeedback ? Colors.green.shade900 : Colors.red.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_character == null) return const SizedBox.shrink();

    if (_mode == WritingMode.learn) {
      return _buildLearnControls();
    } else {
      return _buildPracticeControls();
    }
  }

  Widget _buildLearnControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stroke sequence number toggle
              FilterChip(
                label: const Text('Số thứ tự', style: TextStyle(fontSize: 12)),
                selected: _showStrokeNumbers,
                onSelected: (val) {
                  setState(() {
                    _showStrokeNumbers = val;
                  });
                },
              ),
              // Speed selector
              DropdownButton<double>(
                value: _animationSpeed,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                  DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                  DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                  DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                ],
                onChanged: (newSpeed) {
                  if (newSpeed != null) {
                    setState(() {
                      _animationSpeed = newSpeed;
                    });
                    if (_isPlaying) {
                      _startFullAnimation();
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Nét trước',
                icon: const Icon(Icons.skip_previous),
                onPressed: _stepPreviousStroke,
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Tạm dừng' : (_animatingStrokeIndex >= _character!.strokes.length - 1 ? 'Phát lại' : 'Phát')),
                onPressed: () {
                  if (_isPlaying) {
                    _pauseAnimation();
                  } else {
                    if (_animatingStrokeIndex >= _character!.strokes.length - 1) {
                      _startFullAnimation();
                    } else {
                      _resumeAnimation();
                    }
                  }
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Nét sau',
                icon: const Icon(Icons.skip_next),
                onPressed: _stepNextStroke,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nét ${_animatingStrokeIndex + 1} / ${_character!.strokes.length}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeControls() {
    final isFinished = _completedStrokes >= _character!.strokes.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Stroke progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tiến độ: $_completedStrokes / ${_character!.strokes.length} nét',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_mistakesCount > 0)
                Text(
                  'Lỗi sai: $_mistakesCount',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
            ],
          ),

          Row(
            children: [
              // Hint button (Practice mode only)
              if (_mode == WritingMode.practice)
                IconButton(
                  tooltip: 'Gợi ý nét',
                  icon: Icon(
                    Icons.lightbulb_outline,
                    color: _showHint ? Colors.amber : Colors.grey,
                  ),
                  onPressed: isFinished
                      ? null
                      : () {
                          setState(() {
                            _showHint = !_showHint;
                          });
                        },
                ),

              // Undo last stroke
              IconButton(
                tooltip: 'Xóa nét trước',
                icon: const Icon(Icons.undo),
                onPressed: _completedStrokes > 0 ? _undoLastStroke : null,
              ),

              // Reset character
              IconButton(
                tooltip: 'Viết lại từ đầu',
                icon: const Icon(Icons.refresh),
                onPressed: _resetWriting,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
