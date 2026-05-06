import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/theme/app_colors.dart';
import '../utils/theme_notifier.dart';
import '../widgets/custom_button.dart';
import '../services/audio_trimming_service.dart';
import '../services/transcription_service.dart';

enum SelectedLanguage { none, english, urdu, arabic }

class AudioTrimmingPage extends StatefulWidget {
  const AudioTrimmingPage({super.key});

  @override
  State<AudioTrimmingPage> createState() => _AudioTrimmingPageState();
}

class _AudioTrimmingPageState extends State<AudioTrimmingPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _audioPath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isGeneratingWaveform = false;
  bool _isTranscribing = false;
  bool _playFullAudio = false; // Toggle between full and trimmed playback

  double _startSeconds = 0;
  double _endSeconds =
      60; // Default to 60 seconds, will be updated when audio loads

  // Waveform data
  List<double> _waveformData = [];
  String? _validationError;

  // Language selection (MANDATORY - same as OCR)
  SelectedLanguage _selectedLanguage = SelectedLanguage.none;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        // Reset position when playback completes
        if (state == PlayerState.completed) {
          final resetPosition = _playFullAudio
              ? Duration.zero
              : Duration(seconds: _startSeconds.toInt());
          _position = resetPosition;
        }
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
        if (_endSeconds > duration.inSeconds.toDouble()) {
          _endSeconds = duration.inSeconds.toDouble();
        }
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;

        // Stop playback when reaching end position (only for trimmed playback)
        if (!_playFullAudio &&
            _isPlaying &&
            position.inSeconds >= _endSeconds.toInt()) {
          _audioPlayer.pause();
          _audioPlayer.seek(Duration(seconds: _startSeconds.toInt()));
          setState(() {
            _isPlaying = false;
            _position = Duration(seconds: _startSeconds.toInt());
          });
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get audio path from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['audioPath'] != null) {
      _audioPath = args['audioPath'] as String;
      _loadAudio();
    }
  }

  Future<void> _loadAudio() async {
    if (_audioPath == null) return;

    setState(() {
      _isLoading = true;
      _isGeneratingWaveform = true;
    });

    try {
      // Load audio file
      await _audioPlayer.setSourceDeviceFile(_audioPath!);

      // Generate waveform asynchronously
      _generateWaveform();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateWaveform() async {
    if (_audioPath == null) return;

    try {
      final waveform = await AudioTrimmingService.generateWaveform(
        audioPath: _audioPath!,
        samples: 200,
      );

      if (mounted) {
        setState(() {
          _waveformData = waveform;
          _isGeneratingWaveform = false;
        });
      }
    } catch (e) {
      print('Error generating waveform: $e');
      if (mounted) {
        setState(() {
          _isGeneratingWaveform = false;
          // Use default waveform on error
          _waveformData =
              List.generate(200, (index) => 0.3 + (index % 5) * 0.1);
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_audioPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // Get the appropriate start position
        final startPosition = _playFullAudio
            ? Duration.zero
            : Duration(seconds: _startSeconds.toInt());

        // Check current state - if stopped or completed, we need to set source and play
        final currentState = _audioPlayer.state;
        if (currentState == PlayerState.stopped ||
            currentState == PlayerState.completed) {
          // Re-set the source and play from the start position
          await _audioPlayer.setSourceDeviceFile(_audioPath!);
          await _audioPlayer.seek(startPosition);
          await _audioPlayer.resume();
        } else {
          // If paused, just seek and resume
          await _audioPlayer.seek(startPosition);
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      _position = _playFullAudio
          ? Duration.zero
          : Duration(seconds: _startSeconds.toInt());
    });
  }

  void _validateTrim() {
    if (_audioPath == null) {
      _validationError = 'No audio file selected';
      return;
    }

    final error = AudioTrimmingService.validateTrimParameters(
      startSeconds: _startSeconds,
      endSeconds: _endSeconds,
      totalDurationSeconds: _duration.inSeconds.toDouble(),
    );

    setState(() {
      _validationError = error;
    });
  }

  Future<void> _generateTranscript() async {
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio file selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate language selection (MANDATORY)
    if (_selectedLanguage == SelectedLanguage.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a language first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate trim parameters
    _validateTrim();
    if (_validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationError!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTranscribing = true;
    });

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating transcript...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Convert SelectedLanguage enum to language code string
      String? languageCode;
      switch (_selectedLanguage) {
        case SelectedLanguage.english:
          languageCode = 'en';
          break;
        case SelectedLanguage.urdu:
          languageCode = 'ur';
          break;
        case SelectedLanguage.arabic:
          languageCode = 'ar';
          break;
        case SelectedLanguage.none:
          languageCode = null; // Should not happen as button is disabled
          break;
      }

      // Log what we're sending
      print('📤 Starting transcription...');
      print('   - Audio path: $_audioPath');
      print('   - Trim: ${_startSeconds}s to ${_endSeconds}s');
      print('   - Language selected: $_selectedLanguage (code: $languageCode)');

      // Transcribe audio with trim positions and language
      final transcript = await TranscriptionService.transcribeAudio(
        audioPath: _audioPath!,
        startSeconds: _startSeconds,
        endSeconds: _endSeconds,
        language: languageCode, // 'en', 'ur', or 'ar'
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Return transcript to previous screen
      if (mounted) {
        Navigator.pop(context, transcript);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatSeconds(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    return _formatDuration(duration);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    return Scaffold(
      backgroundColor: ThemeColors.background(isDark),
      appBar: AppBar(
        backgroundColor: ThemeColors.background(isDark),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: ThemeColors.textPrimary(isDark),
          onPressed: () {
            _stop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Trim Audio',
          style: TextStyle(
            color: ThemeColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select the exact part of the audio you want to generate transcript for.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 24),

              // Waveform with draggable handles
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: ThemeColors.card(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeColors.border(isDark)),
                ),
                child: _isLoading || _isGeneratingWaveform
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text(
                              'Loading audio...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : _audioPath == null
                        ? Center(
                            child: Text(
                              'No audio file selected',
                              style: TextStyle(
                                  color: ThemeColors.textSecondary(isDark)),
                            ),
                          )
                        : _duration.inSeconds > 0
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Waveform with draggable handles
                                    Expanded(
                                      child: AudioWaveformWidget(
                                        duration: _duration,
                                        position: _position,
                                        startSeconds: _startSeconds,
                                        endSeconds: _endSeconds,
                                        waveformData: _waveformData,
                                        onStartChanged: (newStart) {
                                          setState(() {
                                            _startSeconds = newStart;
                                            if (_startSeconds >= _endSeconds) {
                                              _startSeconds = _endSeconds - 1;
                                            }
                                          });
                                          _validateTrim();
                                          if (_isPlaying) {
                                            _stop();
                                          }
                                        },
                                        onEndChanged: (newEnd) {
                                          setState(() {
                                            _endSeconds = newEnd;
                                            if (_endSeconds <= _startSeconds) {
                                              _endSeconds = _startSeconds + 1;
                                            }
                                          });
                                          _validateTrim();
                                          if (_isPlaying) {
                                            _stop();
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Time indicators
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatSeconds(_startSeconds),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: ThemeColors.textSecondary(
                                                isDark),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _formatSeconds(_endSeconds),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: ThemeColors.textSecondary(
                                                isDark),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            : Center(
                                child: Text(
                                  'Loading audio...',
                                  style: TextStyle(
                                      color: ThemeColors.textSecondary(isDark)),
                                ),
                              ),
              ),
              const SizedBox(height: 24),

              // Validation error display
              if (_validationError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_validationError != null) const SizedBox(height: 16),

              // Duration info
              Text(
                'Selected Duration: ${_formatSeconds(_endSeconds - _startSeconds)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Duration: ${_formatDuration(_duration)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 24),

              // Language selection (MANDATORY - same as OCR)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Language *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLanguageButton(
                            'English',
                            SelectedLanguage.english,
                            Icons.language,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLanguageButton(
                            'Urdu',
                            SelectedLanguage.urdu,
                            Icons.translate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLanguageButton(
                            'Arabic',
                            SelectedLanguage.arabic,
                            Icons.text_fields,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Playback mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Play Mode:',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text('Trimmed'),
                    selected: !_playFullAudio,
                    onSelected: (selected) {
                      setState(() {
                        _playFullAudio = !selected;
                      });
                      if (_isPlaying) {
                        _stop();
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _playFullAudio
                          ? ThemeColors.textSecondary(isDark)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Full Audio'),
                    selected: _playFullAudio,
                    onSelected: (selected) {
                      setState(() {
                        _playFullAudio = selected;
                      });
                      if (_isPlaying) {
                        _stop();
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _playFullAudio
                          ? Colors.white
                          : ThemeColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Playback controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.stop,
                      size: 32,
                      color: ThemeColors.textSecondary(isDark),
                    ),
                    onPressed: _stop,
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  const SizedBox(width: 24),
                  // Current position display
                  Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Generate transcript button (disabled until language selected)
              CustomButton(
                text: _isTranscribing
                    ? 'Generating Transcript...'
                    : (_selectedLanguage == SelectedLanguage.none
                        ? 'Select Language First'
                        : 'Generate Transcript'),
                onPressed: _selectedLanguage == SelectedLanguage.none
                    ? null
                    : () {
                        _generateTranscript();
                      },
                isLoading: _isTranscribing,
                icon: Icons.graphic_eq,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build language selection button (same style as OCR)
  Widget _buildLanguageButton(
      String label, SelectedLanguage language, IconData icon) {
    final isDark = ThemeNotifier.instance.isDark;
    final bool isSelected = _selectedLanguage == language;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLanguage = language;
        });
        print('✅ Language set to: $language');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : ThemeColors.card(isDark),
          border: Border.all(
            color: isSelected ? AppColors.primary : ThemeColors.border(isDark),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : ThemeColors.textSecondary(isDark),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : ThemeColors.textSecondary(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced waveform widget with real waveform data
class AudioWaveformWidget extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final double startSeconds;
  final double endSeconds;
  final List<double> waveformData;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;

  const AudioWaveformWidget({
    super.key,
    required this.duration,
    required this.position,
    required this.startSeconds,
    required this.endSeconds,
    required this.waveformData,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget> {
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  double _getPositionFromX(double x, double width) {
    final maxSeconds = widget.duration.inSeconds.toDouble();
    return (x / width) * maxSeconds;
  }

  double _getXFromSeconds(double seconds, double width) {
    final maxSeconds = widget.duration.inSeconds.toDouble();
    return (seconds / maxSeconds) * width;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final maxSeconds = widget.duration.inSeconds.toDouble();

        if (maxSeconds == 0) {
          return const SizedBox();
        }

        final startX = _getXFromSeconds(widget.startSeconds, width);
        final endX = _getXFromSeconds(widget.endSeconds, width);
        final currentX =
            _getXFromSeconds(widget.position.inSeconds.toDouble(), width);

        return GestureDetector(
          onHorizontalDragStart: (details) {
            final x = details.localPosition.dx;
            final startHandleArea = (startX - 20 <= x && x <= startX + 20);
            final endHandleArea = (endX - 20 <= x && x <= endX + 20);

            if (startHandleArea) {
              setState(() => _isDraggingStart = true);
            } else if (endHandleArea) {
              setState(() => _isDraggingEnd = true);
            }
          },
          onHorizontalDragUpdate: (details) {
            final x = details.localPosition.dx.clamp(0.0, width);
            final newSeconds =
                _getPositionFromX(x, width).clamp(0.0, maxSeconds);

            if (_isDraggingStart) {
              widget.onStartChanged(newSeconds);
            } else if (_isDraggingEnd) {
              widget.onEndChanged(newSeconds);
            }
          },
          onHorizontalDragEnd: (_) {
            setState(() {
              _isDraggingStart = false;
              _isDraggingEnd = false;
            });
          },
          child: CustomPaint(
            painter: AudioWaveformPainter(
              duration: widget.duration,
              position: widget.position,
              startSeconds: widget.startSeconds,
              endSeconds: widget.endSeconds,
              waveformData: widget.waveformData,
              isDraggingStart: _isDraggingStart,
              isDraggingEnd: _isDraggingEnd,
            ),
            size: Size(width, height),
          ),
        );
      },
    );
  }
}

class AudioWaveformPainter extends CustomPainter {
  final Duration duration;
  final Duration position;
  final double startSeconds;
  final double endSeconds;
  final List<double> waveformData;
  final bool isDraggingStart;
  final bool isDraggingEnd;

  AudioWaveformPainter({
    required this.duration,
    required this.position,
    required this.startSeconds,
    required this.endSeconds,
    required this.waveformData,
    required this.isDraggingStart,
    required this.isDraggingEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = ThemeNotifier.instance.isDark;
    if (duration.inSeconds == 0) return;

    final maxSeconds = duration.inSeconds.toDouble();
    final startPercent = startSeconds / maxSeconds;
    final endPercent = endSeconds / maxSeconds;
    final currentPercent = position.inSeconds / maxSeconds;

    final startX = startPercent * size.width;
    final endX = endPercent * size.width;
    final currentX = currentPercent * size.width;

    // Draw selected range background
    final rangePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(startX, 0, endX, size.height),
      rangePaint,
    );

    // Draw waveform bars using real waveform data
    final barCount = waveformData.isEmpty ? 80 : waveformData.length;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.8;

    for (int i = 0; i < barCount; i++) {
      final barX = i * barWidth + barWidth / 2;
      final barPercent = i / barCount;

      // Get amplitude from waveform data or use default
      final amplitude = waveformData.isEmpty
          ? 0.3 + (i % 5) * 0.1
          : waveformData[i].clamp(0.0, 1.0);

      final barHeight = amplitude * maxBarHeight;

      // Determine bar color
      Color barColor;
      if (barPercent < startPercent || barPercent > endPercent) {
        // Outside selected range - dimmed
        barColor = ThemeColors.border(isDark).withOpacity(0.3);
      } else if (barPercent <= currentPercent) {
        // Played portion - bright
        barColor = AppColors.primary;
      } else {
        // Selected but not played - medium
        barColor = AppColors.primary.withOpacity(0.5);
      }

      final barPaint = Paint()
        ..color = barColor
        ..strokeWidth = barWidth * 0.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(barX, centerY - barHeight / 2),
        Offset(barX, centerY + barHeight / 2),
        barPaint,
      );
    }

    // Draw start handle (left slider)
    final startHandlePaint = Paint()
      ..color = isDraggingStart ? AppColors.primary : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(startX, centerY),
      12,
      startHandlePaint,
    );

    final startHandleInnerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(startX, centerY),
      6,
      startHandleInnerPaint,
    );

    final handleLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, size.height),
      handleLinePaint,
    );

    // Draw end handle (right slider)
    final endHandlePaint = Paint()
      ..color = isDraggingEnd ? AppColors.primary : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(endX, centerY),
      12,
      endHandlePaint,
    );

    final endHandleInnerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(endX, centerY),
      6,
      endHandleInnerPaint,
    );

    canvas.drawLine(
      Offset(endX, 0),
      Offset(endX, size.height),
      handleLinePaint,
    );

    // Draw current position indicator (only if within selected range)
    if (currentPercent >= startPercent && currentPercent <= endPercent) {
      final currentPaint = Paint()
        ..color = AppColors.accentGold
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(currentX, 0),
        Offset(currentX, size.height),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(AudioWaveformPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.startSeconds != startSeconds ||
        oldDelegate.endSeconds != endSeconds ||
        oldDelegate.isDraggingStart != isDraggingStart ||
        oldDelegate.isDraggingEnd != isDraggingEnd ||
        oldDelegate.waveformData != waveformData;
  }
}
