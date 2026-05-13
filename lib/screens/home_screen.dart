import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/theme/app_colors.dart';
import '../utils/theme_notifier.dart';
import '../widgets/custom_button.dart';
import '../widgets/profile_photo_widget.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/ocr_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'result_page.dart';
import 'crop_image_page.dart';
import 'chatbot_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final DateTime createdAt;
  final String? profilePhotoUrl;
  final Function(UserModel)? onProfilePhotoUpdated;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.createdAt,
    this.profilePhotoUrl,
    this.onProfilePhotoUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _currentProfilePhotoUrl;

  // Speech recognition
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentProfilePhotoUrl = widget.profilePhotoUrl;

    // Initialize pulse animation for mic button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize speech recognition
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        if (mounted) {
          setState(() {
            _isListening = false;
            _speechAvailable = false;
          });
        }
      },
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (mounted) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
            _pulseController.stop();
          }
        }
      },
    );

    if (mounted) {
      setState(() {
        _speechAvailable = available;
      });
    }
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      await _initializeSpeech();
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Speech recognition is not available. Please check microphone permissions.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      _pulseController.stop();
    } else {
      setState(() {
        _isListening = true;
        _lastWords = '';
      });
      _pulseController.repeat();

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              if (result.finalResult) {
                final newText = result.recognizedWords.trim();
                if (newText.isNotEmpty) {
                  if (_searchController.text.isNotEmpty &&
                      _lastWords.isNotEmpty) {
                    final currentText = _searchController.text;
                    if (currentText.endsWith(_lastWords)) {
                      _searchController.text = currentText.substring(
                              0, currentText.length - _lastWords.length) +
                          newText;
                    } else {
                      _searchController.text = '$currentText $newText';
                    }
                  } else {
                    _searchController.text = newText;
                  }
                  _lastWords = newText;

                  final textDirection =
                      _getTextDirection(_searchController.text);
                  if (textDirection == ui.TextDirection.rtl) {
                    _searchController.selection =
                        const TextSelection.collapsed(offset: 0);
                  } else {
                    _searchController.selection = TextSelection.collapsed(
                        offset: _searchController.text.length);
                  }
                }
              } else {
                final partialText = result.recognizedWords.trim();
                if (partialText.isNotEmpty) {
                  final currentText = _searchController.text;
                  if (currentText.endsWith(_lastWords)) {
                    _searchController.text = currentText.substring(
                            0, currentText.length - _lastWords.length) +
                        partialText;
                  } else {
                    _searchController.text = '$currentText $partialText';
                  }
                  _lastWords = partialText;

                  final textDirection =
                      _getTextDirection(_searchController.text);
                  if (textDirection == ui.TextDirection.rtl) {
                    _searchController.selection =
                        const TextSelection.collapsed(offset: 0);
                  } else {
                    _searchController.selection = TextSelection.collapsed(
                        offset: _searchController.text.length);
                  }
                }
              }
            });
          }
        },
        localeId: null,
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
      );
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profilePhotoUrl != widget.profilePhotoUrl) {
      setState(() {
        _currentProfilePhotoUrl = widget.profilePhotoUrl;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  void _onProfilePhotoUpdated(UserModel updatedUser) {
    setState(() {
      _currentProfilePhotoUrl = updatedUser.profilePhotoUrl;
    });
    if (widget.onProfilePhotoUpdated != null) {
      widget.onProfilePhotoUpdated!(updatedUser);
    }
  }

  /// Detect text direction (RTL for Arabic/Urdu, LTR for English)
  ui.TextDirection _getTextDirection(String text) {
    if (text.isEmpty) return ui.TextDirection.ltr;
    final arabicPattern = RegExp(r'[\u0600-\u06FF]');
    final hasArabicChars = arabicPattern.hasMatch(text);
    if (hasArabicChars) return ui.TextDirection.rtl;
    return ui.TextDirection.ltr;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: HomeDrawer(
        userId: widget.userId,
        username: widget.username,
        createdAt: widget.createdAt,
        profilePhotoUrl: _currentProfilePhotoUrl,
        onProfilePhotoUpdated: _onProfilePhotoUpdated,
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            color: Colors.white,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            color: Colors.white,
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/bookmarks',
                arguments: widget.userId,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Logo
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    final colorScheme = Theme.of(context).colorScheme;
                    final textTheme = Theme.of(context).textTheme;
                    return RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'True',
                            style: textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: 'Hadith',
                            style: textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Search bar
              _buildSearchBar(context, isDark),

              const SizedBox(height: 24),

              Text(
                'Browse and search authentic Hadith collections.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatbotScreen(userId: widget.userId),
            ),
          );
        },
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            color: colorScheme.secondary,
            onPressed: () => _showInputOptionsSheet(context),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final textDirection = _getTextDirection(_searchController.text);
                return TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  textDirection: textDirection,
                  maxLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Search Hadiths by text, image...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9BA89B),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (value) {
                    final query = value.trim();
                    if (query.isNotEmpty) {
                      _submitQuery(query);
                    }
                  },
                );
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                });
              },
            ),
          // Mic button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : colorScheme.primary,
                  ),
                  onPressed: _toggleListening,
                  tooltip: _isListening ? 'Stop listening' : 'Start voice search',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Input options bottom sheet ─────────────────────────────────────────────

  void _showInputOptionsSheet(BuildContext parentContext) {
    final isDark = ThemeNotifier.instance.isDark;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Theme.of(parentContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose input type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(modalContext).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Open Camera',
                  onPressed: () async {
                    Navigator.pop(modalContext);
                    if (!mounted) return;
                    try {
                      final File? imageFile = await StorageService.pickImage(
                        source: ImageSource.camera,
                      );

                      if (imageFile != null && mounted) {
                        final result =
                            await Navigator.of(parentContext).pushNamed(
                          '/crop_image',
                          arguments: {'imagePath': imageFile.path},
                        );

                        if (result != null && mounted) {
                          String? imagePath;
                          SelectedLanguage? selectedLanguage;

                          if (result is Map<String, dynamic>) {
                            imagePath = result['imagePath'] as String?;
                            selectedLanguage =
                                result['language'] as SelectedLanguage?;
                          } else if (result is String) {
                            imagePath = result;
                            selectedLanguage = null;
                          }

                          if (imagePath != null &&
                              imagePath.trim().isNotEmpty) {
                            final isImagePath = imagePath.contains('/') ||
                                imagePath.contains('\\');

                            if (isImagePath) {
                              if (!mounted) return;

                              showDialog(
                                context: parentContext,
                                barrierDismissible: false,
                                builder: (dialogContext) => PopScope(
                                  canPop: false,
                                  child: AlertDialog(
                                    backgroundColor: Theme.of(dialogContext).colorScheme.surface,
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Extracting text from image...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(dialogContext).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'This may take 30-60 seconds\nPlease wait...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              await Future.delayed(
                                  const Duration(milliseconds: 50));

                              try {
                                final ocrResult = await OCRService
                                    .extractTextFromImageWithDetails(
                                  imagePath,
                                  selectedLanguage: selectedLanguage,
                                );

                                if (mounted) {
                                  Navigator.of(parentContext).pop();
                                }

                                if (ocrResult.isSuccess && mounted) {
                                  try {
                                    final extractedText =
                                        ocrResult.text!.trim();
                                    final isRTL =
                                        _getTextDirection(extractedText) ==
                                            ui.TextDirection.rtl;
                                    setState(() {
                                      _searchController.text = extractedText;
                                      if (isRTL) {
                                        _searchController.selection =
                                            const TextSelection.collapsed(
                                                offset: 0);
                                      } else {
                                        _searchController.selection =
                                            TextSelection.collapsed(
                                                offset: extractedText.length);
                                      }
                                    });
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        if (isRTL) {
                                          _searchController.selection =
                                              const TextSelection.collapsed(
                                                  offset: 0);
                                        } else {
                                          _searchController.selection =
                                              TextSelection.collapsed(
                                                  offset: extractedText.length);
                                        }
                                      }
                                    });
                                    ScaffoldMessenger.of(parentContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Text extracted successfully! (${ocrResult.text!.length} characters)'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } catch (e) {
                                    print(
                                        'OCR Debug: ⚠ Error updating UI after OCR success: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(parentContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Text extracted successfully! (${ocrResult.text!.length} characters)'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                } else if (mounted) {
                                  String errorMsg = ocrResult.errorMessage ??
                                      'No text found in image';
                                  if (ocrResult.backendUrl != null &&
                                      ocrResult.easyOCRAttempted) {
                                    errorMsg +=
                                        '\n\nBackend: ${ocrResult.backendUrl}';
                                  }
                                  ScaffoldMessenger.of(parentContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(errorMsg),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 6),
                                      action: SnackBarAction(
                                        label: 'Dismiss',
                                        textColor: Colors.white,
                                        onPressed: () {},
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  Navigator.of(parentContext).pop();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(parentContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('OCR Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            } else {
                              print(
                                  'OCR Debug: Result is not an image path, skipping OCR');
                            }
                          }
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error opening camera: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icons.camera_alt_outlined,
                  width: double.infinity,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Upload Image',
                  onPressed: () async {
                    Navigator.pop(modalContext);
                    if (!mounted) return;
                    try {
                      final File? imageFile = await StorageService.pickImage(
                        source: ImageSource.gallery,
                      );

                      if (imageFile != null && mounted) {
                        final result =
                            await Navigator.of(parentContext).pushNamed(
                          '/crop_image',
                          arguments: {'imagePath': imageFile.path},
                        );

                        if (result != null && mounted) {
                          String? imagePath;
                          SelectedLanguage? selectedLanguage;

                          if (result is Map<String, dynamic>) {
                            imagePath = result['imagePath'] as String?;
                            selectedLanguage =
                                result['language'] as SelectedLanguage?;
                          } else if (result is String) {
                            imagePath = result;
                            selectedLanguage = null;
                          }

                          if (imagePath != null &&
                              imagePath.trim().isNotEmpty) {
                            final isImagePath = imagePath.contains('/') ||
                                imagePath.contains('\\');

                            if (isImagePath) {
                              if (!mounted) return;

                              showDialog(
                                context: parentContext,
                                barrierDismissible: false,
                                builder: (dialogContext) => PopScope(
                                  canPop: false,
                                  child: AlertDialog(
                                    backgroundColor: Theme.of(dialogContext).colorScheme.surface,
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Extracting text from image...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(dialogContext).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'This may take 30-60 seconds\nPlease wait...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              await Future.delayed(
                                  const Duration(milliseconds: 50));

                              try {
                                final ocrResult = await OCRService
                                    .extractTextFromImageWithDetails(
                                  imagePath,
                                  selectedLanguage: selectedLanguage,
                                );

                                if (mounted) {
                                  Navigator.of(parentContext).pop();
                                }

                                if (ocrResult.isSuccess && mounted) {
                                  try {
                                    final extractedText =
                                        ocrResult.text!.trim();
                                    final isRTL =
                                        _getTextDirection(extractedText) ==
                                            ui.TextDirection.rtl;
                                    setState(() {
                                      _searchController.text = extractedText;
                                      if (isRTL) {
                                        _searchController.selection =
                                            const TextSelection.collapsed(
                                                offset: 0);
                                      } else {
                                        _searchController.selection =
                                            TextSelection.collapsed(
                                                offset: extractedText.length);
                                      }
                                    });
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        if (isRTL) {
                                          _searchController.selection =
                                              const TextSelection.collapsed(
                                                  offset: 0);
                                        } else {
                                          _searchController.selection =
                                              TextSelection.collapsed(
                                                  offset: extractedText.length);
                                        }
                                      }
                                    });
                                    ScaffoldMessenger.of(parentContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Text extracted successfully! (${ocrResult.text!.length} characters)'),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  } catch (e) {
                                    print(
                                        'OCR Debug: ⚠ Error updating UI after OCR success: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(parentContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Text extracted successfully! (${ocrResult.text!.length} characters)'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                } else if (mounted) {
                                  String errorMsg = ocrResult.errorMessage ??
                                      'No text found in image';
                                  if (ocrResult.backendUrl != null &&
                                      ocrResult.easyOCRAttempted) {
                                    errorMsg +=
                                        '\n\nBackend: ${ocrResult.backendUrl}';
                                  }
                                  ScaffoldMessenger.of(parentContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(errorMsg),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 6),
                                      action: SnackBarAction(
                                        label: 'Dismiss',
                                        textColor: Colors.white,
                                        onPressed: () {},
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  Navigator.of(parentContext).pop();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(parentContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('OCR Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            } else {
                              print(
                                  'OCR Debug: Result is not an image path, skipping OCR');
                            }
                          }
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error uploading image: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icons.photo_library_outlined,
                  width: double.infinity,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Upload Audio File',
                  onPressed: () async {
                    Navigator.pop(modalContext);
                    if (!mounted) return;
                    await _pickAudioFile(parentContext);
                  },
                  icon: Icons.audiotrack_outlined,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Audio file picking ────────────────────────────────────────────────────

  static const _waChannel =
      MethodChannel('com.example.true_hadith/whatsapp');

  Future<void> _pickAudioFile(BuildContext parentContext) async {
    // Request audio/storage permission before querying MediaStore
    bool granted = false;
    if (Platform.isAndroid) {
      final results = await [Permission.storage, Permission.audio].request();
      granted = results.values.any((s) => s.isGranted);
    } else {
      granted = (await Permission.storage.request()).isGranted;
    }

    if (!granted && mounted) {
      if ((await Permission.audio.status).isPermanentlyDenied ||
          (await Permission.storage.status).isPermanentlyDenied) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: const Text(
                'Storage permission denied. Enable it in app settings to browse WhatsApp files.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      await _openFilePicker(parentContext);
      return;
    }

    // Query WhatsApp Voice Notes via MediaStore (works on Android 11+ scoped storage)
    List<Map<String, dynamic>> voiceNotes = [];
    try {
      final raw = await _waChannel.invokeMethod<List>('getVoiceNotes');
      if (raw != null) {
        voiceNotes = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}

    if (voiceNotes.isNotEmpty && mounted) {
      _showWhatsAppVoiceNotes(parentContext, voiceNotes);
    } else {
      await _openFilePicker(parentContext);
    }
  }

  void _showWhatsAppVoiceNotes(
      BuildContext parentContext, List<Map<String, dynamic>> files) {
    final isDark = ThemeNotifier.instance.isDark;
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: ThemeColors.background(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'WhatsApp Voice Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.textPrimary(isDark),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${files.length} files',
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: ThemeColors.border(isDark)),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: files.length,
                  itemBuilder: (_, index) {
                    final f = files[index];
                    final name = f['name'] as String;
                    final sizeKb =
                        ((f['size'] as int) / 1024).toStringAsFixed(1);
                    final modified = DateTime.fromMillisecondsSinceEpoch(
                        (f['modified'] as int));
                    final dateStr =
                        '${modified.day.toString().padLeft(2, '0')}/${modified.month.toString().padLeft(2, '0')}/${modified.year}';

                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.audiotrack,
                            color: AppColors.primary, size: 22),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          color: ThemeColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$dateStr · $sizeKb KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.textSecondary(isDark),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleAudioSelected(
                            parentContext, f['path'] as String);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: 'Browse Other Files',
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openFilePicker(parentContext);
                  },
                  icon: Icons.folder_open_outlined,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFilePicker(BuildContext parentContext) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'opus'],
      );
      if (result != null && result.files.single.path != null && mounted) {
        await _handleAudioSelected(parentContext, result.files.single.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Error uploading audio: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAudioSelected(
      BuildContext parentContext, String audioPath) async {
    if (!mounted) return;
    final transcript = await Navigator.of(parentContext).pushNamed(
      '/audio_trimming',
      arguments: {'audioPath': audioPath},
    ) as String?;
    if (transcript != null && transcript.trim().isNotEmpty && mounted) {
      final trimmed = transcript.trim();
      setState(() {
        _searchController.text = trimmed;
      });
      _submitQuery(trimmed);
    }
  }

  // ── Submit query ───────────────────────────────────────────────────────────

  Future<void> _submitQuery(String query) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final results = await ApiService.searchHadiths(
        userId: widget.userId,
        query: query,
      );

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultPage(
              userId: widget.userId,
              query: query,
              results: results,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// ── HomeDrawer ──────────────────────────────────────────────────────────────

class HomeDrawer extends StatelessWidget {
  final int userId;
  final String username;
  final DateTime createdAt;
  final String? profilePhotoUrl;
  final Function(UserModel)? onProfilePhotoUpdated;

  const HomeDrawer({
    super.key,
    required this.userId,
    required this.username,
    required this.createdAt,
    this.profilePhotoUrl,
    this.onProfilePhotoUpdated,
  });

  String _memberSinceText() {
    final formatter = DateFormat('MMMM yyyy');
    return 'Member since ${formatter.format(createdAt)}';
  }

  @override
  Widget build(BuildContext context) {
    // Wrap entire drawer so it rebuilds on theme change
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = ThemeNotifier.instance.isDark;

        return Drawer(
          backgroundColor: colorScheme.surface,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Profile header ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfilePhotoWidget(
                            photoUrl: profilePhotoUrl,
                            userId: userId,
                            size: 80,
                            onPhotoUpdated: onProfilePhotoUpdated != null
                                ? (updatedUser) =>
                                    onProfilePhotoUpdated!(updatedUser)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _memberSinceText(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap photo to view, update, or delete',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: colorScheme.outline.withOpacity(0.5)),

                // ── Nav items ──────────────────────────────────────────
                _DrawerItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/history',
                      arguments: userId,
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.translate_rounded,
                  label: 'Translations',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/translations');
                  },
                ),

                Divider(color: colorScheme.outline.withOpacity(0.5)),

                ListTile(
                  leading: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? AppColors.accentGold : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isDark,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withOpacity(0.4),
                      onChanged: (val) {
                        if (val) {
                          ThemeNotifier.instance.setDark();
                        } else {
                          ThemeNotifier.instance.setLight();
                        }
                      },
                    ),
                  ),
                ),

                const Spacer(),

                // ── Logout ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: CustomButton(
                    text: 'Logout',
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogoutDialog(context);
                    },
                    backgroundColor: AppColors.error,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Logout',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: ${e.toString()}'),
                      backgroundColor: colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Logout',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DrawerItem ─────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
