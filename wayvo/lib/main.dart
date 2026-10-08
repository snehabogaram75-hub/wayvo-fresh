import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'my_files.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

final Dio dio = Dio(
  BaseOptions(
    baseUrl: 'https://wayvo-fresh-1.onrender.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(minutes: 5),
    extra: {'withCredentials': true},
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('dart.library.html') == false) {
    final dir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.cookies/'),
    );
    dio.interceptors.add(CookieManager(cookieJar));
  }
  runApp(const WayvoApp());
}

class WayvoApp extends StatelessWidget {
  const WayvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      title: 'WAYVO',
      theme: ThemeData(
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F2),
      ),
      home: const AuthScreen(),
    );
  }
}

// =========================
// AUTH SCREEN
// =========================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    checkSavedLogin();
  }

  Future<void> checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString("email");

    if (savedEmail != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WayvoHome()),
      );
    }
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Please enter email and password.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      final endpoint = isLogin ? '/login' : '/signup';

      final response = await dio.post(
        endpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (data['success'] == true) {
        if (isLogin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("email", email);
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const WayvoHome(),
            ),
          );
        } else {
          setState(() {
            isLogin = true;
            errorMessage = 'Account created. Please login.';
            passwordController.clear();
          });
        }
      } else {
        setState(() {
          errorMessage =
              data['message'] ?? 'Something went wrong.';
        });
      }
    } on DioException catch (e) {
      setState(() {
        errorMessage =
            e.response?.data?['message'] ??
            'Could not connect to WAYVO backend.';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Something went wrong.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFDF5),
              Color(0xFFDCEFF7),
              Color(0xFFB8D8E8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 430,
                ),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: SvgPicture.asset(
                          'assets/wayvo-icon.svg',
                          height: 72,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        isLogin
                            ? 'Welcome back.'
                            : 'Create your WAYVO account.',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 28),

                      TextField(
                        controller: emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon:
                              const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon:
                              const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin:
                              const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              loading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF17152A),
                            foregroundColor: Colors.white,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isLogin
                                      ? 'Login'
                                      : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Center(
                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () {
                                  setState(() {
                                    isLogin = !isLogin;
                                    errorMessage = '';
                                  });
                                },
                          child: Text(
                            isLogin
                                ? 'Create a new account'
                                : 'Already have an account? Login',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================
// WAYVO HOME
// =========================

class WayvoHome extends StatefulWidget {
  const WayvoHome({super.key});

  @override
  State<WayvoHome> createState() => _WayvoHomeState();
}

class _WayvoHomeState extends State<WayvoHome>
    with SingleTickerProviderStateMixin {
  final messageController = TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final ImagePicker imagePicker = ImagePicker();

  final stt.SpeechToText speechToText =
      stt.SpeechToText();

  final FlutterTts tts = FlutterTts();
  bool voiceMode = false;
  bool speaking = false;
  bool sttReady = false;
  bool voiceGotResult = false;
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  String voiceLastWords = '';
  bool voiceStarting = false;
  final ValueNotifier<String> voiceStatus =
      ValueNotifier<String>('Listening…');
  final ValueNotifier<String> voiceText =
      ValueNotifier<String>('');

  final List<Map<String, String>> messages = [];

  List<dynamic> chatList = [];
  int? currentChatId;

  bool sending = false;
  bool historyOpen = false;
  bool showArchived = false;
  bool showLocked = false;
  DateTime? waitStart;
  final FocusNode inputFocus = FocusNode();
  final LocalAuthentication localAuth = LocalAuthentication();
  bool listening = false;

  @override
  void initState() {
    super.initState();
    loadChats();
    initTts();
  }

  Future<void> initTts() async {
    final inOk = await tts.isLanguageAvailable('en-IN');
    await tts.setLanguage(inOk == true ? 'en-IN' : 'en-US');
    await tts.setSpeechRate(0.5);
    await tts.awaitSpeakCompletion(true);
    tts.setStartHandler(() {
      voiceStatus.value = 'Speaking…';
      if (mounted) setState(() => speaking = true);
    });
    tts.setCompletionHandler(() {
      if (mounted) setState(() => speaking = false);
      if (mounted && voiceMode) {
        Future.delayed(
          const Duration(milliseconds: 500),
          startVoiceListen,
        );
      }
    });
    tts.setCancelHandler(() {
      if (mounted) setState(() => speaking = false);
    });
    tts.setErrorHandler((_) {
      if (mounted) setState(() => speaking = false);
    });
  }

  Future<void> speak(String text) async {
    final clean = text
        .replaceAll(RegExp(r'[*#`_>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    await tts.stop();
    await tts.speak(clean);
  }

  Future<void> stopSpeaking() async {
    await tts.stop();
    if (mounted) setState(() => speaking = false);
  }

  Future<bool> ensureStt() async {
    if (sttReady) return true;
    sttReady = await speechToText.initialize(
      onStatus: onSttStatus,
      onError: (e) {
        if (!mounted) return;
        if (voiceMode) {
          voiceStatus.value = 'Listening…';
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (voiceMode && !sending && !speaking && !voiceGotResult) {
              startVoiceListen();
            }
          });
        } else if (listening) {
          setState(() => listening = false);
        }
      },
    );
    return sttReady;
  }

  void onSttStatus(String status) {
    if (!mounted) return;
    if (status == 'done' || status == 'notListening') {
      if (!voiceMode && listening) {
        setState(() => listening = false);
      }
      if (voiceMode && !voiceGotResult) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!voiceMode || voiceGotResult || sending || speaking) return;
          if (voiceLastWords.trim().isNotEmpty) {
            submitVoice(voiceLastWords);
          } else {
            startVoiceListen();
          }
        });
      }
    }
  }

  Future<void> submitVoice(String text) async {
    final words = text.trim();
    if (words.isEmpty || voiceGotResult || sending) return;
    voiceGotResult = true;
    messageController.text = words;
    voiceStatus.value = 'Thinking…';
    await sendMessage();
    if (voiceMode && voiceStatus.value == 'Thinking…') {
      voiceStatus.value = 'No reply. Tap the circle to retry';
    }
  }

  Future<void> startVoiceListen() async {
    if (!voiceMode || sending || speaking || voiceStarting) return;
    voiceStarting = true;
    try {
      final ok = await ensureStt();
      if (!ok) {
        voiceStatus.value = 'Speech not available';
        return;
      }
      if (!voiceMode || speechToText.isListening) return;
      voiceGotResult = false;
      voiceLastWords = '';
      voiceStatus.value = 'Listening…';
      voiceText.value = '';
      await speechToText.listen(
        listenOptions: stt.SpeechListenOptions(
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 60),
        ),
        onResult: (r) {
          voiceText.value = r.recognizedWords;
          voiceLastWords = r.recognizedWords;
          if (r.finalResult) {
            submitVoice(r.recognizedWords);
          }
        },
      );
    } finally {
      voiceStarting = false;
    }
  }

  Future<void> openVoiceMode() async {
    if (sending) return;
    FocusScope.of(context).unfocus();
    setState(() => voiceMode = true);
    voiceStatus.value = 'Listening…';
    voiceText.value = '';
    startVoiceListen();
  }

  Future<void> closeVoiceMode() async {
    if (mounted) setState(() => voiceMode = false);
    await speechToText.stop();
    await tts.stop();
    if (mounted) setState(() => speaking = false);
  }

  Future<void> loadChats() async {
    try {
      final response = await dio.get('/api/chats');
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (mounted && data['success'] == false) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('email');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
        return;
      }

      if (data['success'] == true && mounted) {
        setState(() {
          chatList = data['chats'] ?? [];
        });
      }
    } catch (e) {
      // ignore
    }
  }

  List<dynamic> get visibleChats => chatList.where((c) {
        final locked = c['locked'] == true;
        if (showLocked) return locked;
        if (locked) return false;
        return (c['archived'] == true) == showArchived;
      }).toList();

  int get headerCount => (showArchived || showLocked) ? 1 : 3;

  Future<bool> authenticateUser() async {
    try {
      final supported = await localAuth.isDeviceSupported();
      if (!supported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Set a screen lock (PIN / fingerprint) on your phone to use locked chats.',
              ),
            ),
          );
        }
        return false;
      }
      return await localAuth.authenticate(
        localizedReason: 'Unlock your private chats',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication not available.')),
        );
      }
      return false;
    }
  }

  Future<void> openLockedChats() async {
    final ok = await authenticateUser();
    if (ok && mounted) {
      setState(() => showLocked = true);
    }
  }

  Future<void> openMyFiles() async {
    if (historyOpen) setState(() => historyOpen = false);
    final chatId = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const MyFilesPage()),
    );
    if (chatId != null && mounted) {
      await loadChats();
      await openChat(chatId);
    }
  }

  Widget buildListHeader(int index) {
    final inSub = showArchived || showLocked;
    IconData icon;
    String label;
    VoidCallback onTap;
    if (inSub) {
      icon = Icons.arrow_back;
      label = 'Back to chats';
      onTap = () => setState(() {
            showArchived = false;
            showLocked = false;
          });
    } else if (index == 0) {
      icon = Icons.archive_outlined;
      label = 'Archived';
      onTap = () => setState(() => showArchived = true);
    } else if (index == 1) {
      icon = Icons.lock_outline;
      label = 'Locked chats';
      onTap = openLockedChats;
    } else {
      icon = Icons.folder_open_outlined;
      label = 'My Files';
      onTap = openMyFiles;
    }
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: Colors.white54),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
      onTap: onTap,
    );
  }

  Future<void> toggleChatFlag(int chatId, String action) async {
    try {
      await dio.post('/api/chats/$chatId/$action');
      await loadChats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed. Try again.')),
      );
    }
  }

  Future<void> showChatOptions(dynamic chat) async {
    final pinned = chat['pinned'] == true;
    final archived = chat['archived'] == true;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                pinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(pinned ? 'Unpin' : 'Pin'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            ListTile(
              leading: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              title: Text(archived ? 'Unarchive' : 'Archive'),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              leading: Icon(
                chat['locked'] == true
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
              ),
              title: Text(chat['locked'] == true ? 'Unlock' : 'Lock'),
              onTap: () => Navigator.pop(ctx, 'lock'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'pin') {
      await toggleChatFlag(chat['id'], 'pin');
    } else if (choice == 'archive') {
      await toggleChatFlag(chat['id'], 'archive');
    } else if (choice == 'lock') {
      final wasLocked = chat['locked'] == true;
      await toggleChatFlag(chat['id'], 'lock');
      if (!wasLocked && currentChatId == chat['id'] && mounted) {
        setState(() {
          currentChatId = null;
          messages.clear();
        });
      }
    } else if (choice == 'delete') {
      await confirmDeleteChat(chat);
    }
  }

  Future<void> confirmDeleteChat(dynamic chat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          '"${chat['title'] ?? 'Chat'}" will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteChat(chat['id']);
    }
  }

  Future<void> deleteChat(int chatId) async {
    try {
      final response = await dio.delete('/api/chats/$chatId');
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          chatList.removeWhere((c) => c['id'] == chatId);
          if (currentChatId == chatId) {
            currentChatId = null;
            messages.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete chat')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed. Try again.')),
      );
    }
  }

  Future<void> openChat(int chatId) async {
    try {
      final response = await dio.get('/api/chats/$chatId');
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (data['success'] == true && mounted) {
        setState(() {
          currentChatId = chatId;
          messages.clear();
          for (final m in data['messages']) {
            messages.add({
              'role': m['role'].toString(),
              'content': m['content'].toString(),
            });
          }
        });

        scrollToBottom();

        if (MediaQuery.of(context).size.width < 800) {
          setState(() {
            historyOpen = false;
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  // =========================
  // SEND TEXT MESSAGE
  // =========================

  Future<void> sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty || sending) return;

    setState(() {
      messages.add({
        'role': 'You',
        'content': message,
      });

      sending = true;
      messageController.clear();
    });

    scrollToBottom();

    try {
      final response = await dio.post(
        '/api/chat',
        data: {
          'message': message,
          'chat_id': currentChatId,
        },
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (!mounted) return;

      setState(() {
        currentChatId = data['chat_id'] ?? currentChatId;
        messages.add({
          'role': 'WAYVO',
          'content': data['reply'] ??
              'I could not generate a response.',
        });
      });

      if (voiceMode) {
        final replyText = (data['reply'] ?? '').toString();
        voiceStatus.value = 'Speaking…';
        voiceText.value = replyText;
        speak(replyText);
      }

      scrollToBottom();
      loadChats();
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'WAYVO',
          'content': e.response?.data?['message'] ??
              'Could not connect to WAYVO backend.',
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'WAYVO',
          'content':
              'Something went wrong. Please try again.',
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  // =========================
  // MICROPHONE
  // =========================

  Future<void> toggleMicrophone() async {
    if (speaking) await stopSpeaking();

    if (listening) {
      await speechToText.stop();

      if (mounted) {
        setState(() {
          listening = false;
        });
      }

      return;
    }

    final available = await ensureStt();

    if (!available) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Speech recognition is not available.'),
        ),
      );

      return;
    }

    setState(() {
      listening = true;
    });

    await speechToText.listen(
      listenOptions: stt.SpeechListenOptions(
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (result) {
        if (!mounted) return;

        if (result.finalResult && voiceMode) {
          setState(() {
            messageController.text =
                result.recognizedWords;
            listening = false;
          });
          if (result.recognizedWords.trim().isNotEmpty) {
            sendMessage();
          }
          return;
        }

        setState(() {
          messageController.text =
              result.recognizedWords;

          messageController.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset: messageController.text.length,
            ),
          );
        });
      },
    );
  }

  // =========================
  // PHOTO
  // =========================
  Widget attachTile(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(ctx, value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: Colors.black87),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> chooseAttachmentSource() async {
    if (sending) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              attachTile(ctx, Icons.photo_camera_outlined, 'Camera', 'camera'),
              const SizedBox(width: 12),
              attachTile(ctx, Icons.photo_library_outlined, 'Photos', 'gallery'),
              const SizedBox(width: 12),
              attachTile(ctx, Icons.insert_drive_file_outlined, 'Files', 'document'),
              const SizedBox(width: 12),
              attachTile(ctx, Icons.lock_outline, 'One-time', 'onetime'),
            ],
          ),
        ),
      ),
    );
    if (choice == 'camera') {
      await pickPhoto(source: ImageSource.camera);
    } else if (choice == 'gallery') {
      await pickPhoto(source: ImageSource.gallery);
    } else if (choice == 'document') {
      await pickDocument();
    } else if (choice == 'onetime') {
      await chooseOneTime();
    }
  }

  Future<void> choosePhotoSource() async {
    if (sending) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(
                  context,
                  ImageSource.camera,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(
                  context,
                  ImageSource.gallery,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await pickPhoto(source: source);
    }
  }


  Future<void> pickDocument() async {
    if (sending) return;

    final pickedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'csv',
        'txt',
        'json',
        'md',
        'xml',
      ],
    );

    if (pickedFile == null) return;

    setState(() {
      messages.add({
        'role': 'You',
        'content': 'Document: ${pickedFile.name}',
      });
      sending = true;
    });

    scrollToBottom();

    try {
      final bytes = await pickedFile.xFile.readAsBytes();

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: pickedFile.name,
        ),
        'message':
            'Please analyze this document and summarize the important information.',
        'chat_id': (currentChatId ?? '').toString(),
      });

      final response = await dio.post(
        '/api/chat/document',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 180),
          receiveTimeout: const Duration(seconds: 180),
        ),
      );

      if (response.data['success'] == true) {
        setState(() {
          messages.add({
            'role': 'WAYVO',
            'content': response.data['reply'] ?? 'Document analyzed successfully.',
          });
        });
      } else {
        setState(() {
          messages.add({
            'role': 'WAYVO',
            'content': response.data['message'] ?? 'Could not analyze the document.',
          });
        });
      }
    } catch (e) {
      final errorMessage = e is DioException
          ? "Upload error: ${e.response?.statusCode ?? "network"} - ${e.response?.data ?? e.message}"
          : "Upload error: $e";
      setState(() {
        messages.add({
          'role': 'WAYVO',
          'content': errorMessage,
        });
      });
    } finally {
      setState(() {
        sending = false;
      });
      scrollToBottom();
    }
  }

  Future<void> pickPhoto({ImageSource source = ImageSource.gallery}) async {
    if (sending) return;

    final XFile? image =
        await imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image == null) return;

    final file = File(image.path);

    setState(() {
      messages.add({
        'role': 'You',
        'content': 'Photo: ${image.name}',
      });

      sending = true;
    });

    scrollToBottom();

    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          file.path,
          filename: image.name,
        ),
        'message':
            'Please analyze this image and describe what is inside it.',
        'chat_id': (currentChatId ?? '').toString(),
      });

      final response = await dio.post(
        '/api/chat/image',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (!mounted) return;

      setState(() {
        currentChatId = data['chat_id'] ?? currentChatId;
        messages.add({
          'role': 'WAYVO',
          'content': data['reply'] ??
              'I could not analyze the image.',
        });
      });

      scrollToBottom();
      loadChats();
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'WAYVO',
          'content': e.response?.data?['message'] ??
              'Could not analyze the image.',
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'WAYVO',
          'content':
              'Something went wrong while analyzing the image.',
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  void startNewChat() {
    setState(() {
      messages.clear();
      currentChatId = null;
    });

    if (MediaQuery.of(context).size.width < 800) {
      setState(() {
        historyOpen = false;
      });
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    pulse.dispose();
    tts.stop();
    speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F7F2),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                if (!isMobile) buildSidebar(),
                Expanded(
                  child: buildChatArea(isMobile),
                ),
              ],
            ),

            if (isMobile && historyOpen)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: buildMobileHistory(),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildSidebar() {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Color(0xFF17152A),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'WAYVO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: startNewChat,
                icon: const Icon(Icons.add),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor:
                      const Color(0xFF17152A),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'CHATS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: chatList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Your conversations will appear here.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleChats.length + headerCount,
                    itemBuilder: (context, index) {
                      if (index < headerCount) {
                        return buildListHeader(index);
                      }
                      final c = visibleChats[index - headerCount];
                      final isActive = c['id'] == currentChatId;
                      return ListTile(
                        selected: isActive,
                        selectedTileColor: Colors.white12,
                        title: Text(
                          c['title'] ?? 'Chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        onTap: () => openChat(c['id']),
                        onLongPress: () => showChatOptions(c),
                        leading: c['pinned'] == true
                            ? const Icon(
                                Icons.push_pin,
                                size: 16,
                                color: Colors.white54,
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Colors.white38,
                          ),
                          onPressed: () => showChatOptions(c),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildMobileHistory() {
    return Material(
      elevation: 12,
      child: Container(
        width: 290,
        decoration: const BoxDecoration(
          color: Color(0xFF17152A),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'WAYVO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        historyOpen = false;
                      });
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: startNewChat,
                  icon: const Icon(Icons.add),
                  label: const Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor:
                        const Color(0xFF17152A),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'CHATS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
            child: chatList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Your conversations will appear here.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleChats.length + headerCount,
                    itemBuilder: (context, index) {
                      if (index < headerCount) {
                        return buildListHeader(index);
                      }
                      final c = visibleChats[index - headerCount];
                      final isActive = c['id'] == currentChatId;
                      return ListTile(
                        selected: isActive,
                        selectedTileColor: Colors.white12,
                        title: Text(
                          c['title'] ?? 'Chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        onTap: () => openChat(c['id']),
                        onLongPress: () => showChatOptions(c),
                        leading: c['pinned'] == true
                            ? const Icon(
                                Icons.push_pin,
                                size: 16,
                                color: Colors.white54,
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: Colors.white38,
                          ),
                          onPressed: () => showChatOptions(c),
                        ),
                      );
                    },
                  ),
          ),
          ],
        ),
      ),
    );
  }

  Widget buildChatArea(bool isMobile) {
    return Column(
      children: [
        Container(
          height: isMobile ? 56 : 72,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 28,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  onPressed: () {
                    setState(() {
                      historyOpen = !historyOpen;
                    });
                  },
                  icon: const Icon(Icons.menu),
                ),

              if (isMobile)
                const SizedBox(width: 4),

              Expanded(
                child: Text(
                  isMobile ? 'WAYVO' : 'Personal AI Workspace',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 17,
                    fontWeight:
                        isMobile ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: isMobile ? 1.5 : 0,
                  ),
                ),
              ),

              if (!isMobile)
                const Text(
                  'WAYVO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: messages.isEmpty
              ? buildWelcome()
              : buildMessages(),
        ),

        buildInputArea(isMobile),
      ],
    );
  }

  Widget buildSuggestionCard(IconData icon, String text) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          messageController.text = text;
          sendMessage();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF17152A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildWelcome() {
    final mobile = MediaQuery.of(context).size.width < 800;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 20 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What can we get done?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: mobile ? 26 : 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tell WAYVO what you are working on.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  buildSuggestionCard(Icons.wb_sunny_outlined, 'Plan my day'),
                  const SizedBox(width: 10),
                  buildSuggestionCard(Icons.school_outlined, 'Help me learn'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  buildSuggestionCard(Icons.lightbulb_outline, 'Give me ideas'),
                  const SizedBox(width: 10),
                  buildSuggestionCard(Icons.extension_outlined, 'Solve a problem'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSuggestion(String text) {
    return ActionChip(
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      label: Text(text),
      onPressed: () {
        messageController.text = text;
        sendMessage();
      },
    );
  }

  Future<void> shareText(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open share sheet')),
        );
      }
    }
  }

  void askWayvoAbout(String selected) {
    final t = selected.trim();
    if (t.isEmpty) return;
    if (voiceMode) closeVoiceMode();
    final text = 'Explain this: "$t"';
    messageController.text = text;
    messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    inputFocus.requestFocus();
  }

  Widget wayvoSelectionMenu(
    BuildContext context,
    EditableTextState state,
    String fullText,
  ) {
    final items = <ContextMenuButtonItem>[];
    for (final item in state.contextMenuButtonItems) {
      if (item.type == ContextMenuButtonType.copy ||
          item.type == ContextMenuButtonType.selectAll) {
        items.add(item);
      }
    }
    final value = state.textEditingValue;
    final sel = value.selection.isValid && !value.selection.isCollapsed
        ? value.selection.textInside(value.text)
        : '';
    if (sel.isNotEmpty) {
      items.add(
        ContextMenuButtonItem(
          label: 'Ask WAYVO',
          onPressed: () {
            state.hideToolbar();
            askWayvoAbout(sel);
          },
        ),
      );
      items.add(
        ContextMenuButtonItem(
          label: 'Share',
          onPressed: () {
            state.hideToolbar();
            shareText(sel);
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  void editMessage(String text) {
    if (voiceMode) closeVoiceMode();
    messageController.text = text;
    messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    inputFocus.requestFocus();
  }

  Future<void> copyText(String text, String note) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(note),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> chooseOneTime() async {
    if (sending) return;
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Send as one-time view',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Text message'),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('File (max 5 MB)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null) return;

    if (kind == 'text') {
      final controller = TextEditingController();
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('One-time message'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            minLines: 2,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type your private message',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (text == null || text.trim().isEmpty) return;
      await createOneTime('text', text: text.trim());
    } else if (kind == 'image') {
      final x = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (x == null) return;
      await createOneTime(
        'image',
        bytes: await x.readAsBytes(),
        filename: x.name,
      );
    } else {
      final f = await FilePicker.pickFile(type: FileType.any);
      if (f == null) return;
      await createOneTime(
        'file',
        bytes: await f.xFile.readAsBytes(),
        filename: f.name,
      );
    }
  }

  Future<void> createOneTime(
    String kind, {
    String? text,
    List<int>? bytes,
    String filename = '',
  }) async {
    setState(() => sending = true);
    try {
      final map = <String, dynamic>{
        'kind': kind,
        'chat_id': (currentChatId ?? '').toString(),
      };
      if (text != null) map['text'] = text;
      if (bytes != null) {
        map['file'] = MultipartFile.fromBytes(
          bytes,
          filename: filename.isEmpty ? 'file' : filename,
        );
      }
      final response = await dio.post(
        '/api/onetime',
        data: FormData.fromMap(map),
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          currentChatId = data['chat_id'] ?? currentChatId;
          messages.add({'role': 'You', 'content': data['content']});
          // One-time reply: WAYVO answer about the image
          final oneTimeReply = data['reply'];
          if (oneTimeReply != null &&
              oneTimeReply.toString().trim().isNotEmpty) {
            messages.add({
              'role': 'WAYVO',
              'content': oneTimeReply.toString(),
            });
          }
        });
        scrollToBottom();
        loadChats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Upload failed')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (e.response?.data is Map
                    ? e.response?.data['message']
                    : null) ??
                'Upload failed. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget buildOneTimeBubble(int index, Map<String, String> message) {
    final raw = message['content'] ?? '';
    final opened = raw.startsWith('[[ONETIME_OPENED:');
    final parts = raw.replaceAll('[[', '').replaceAll(']]', '').split(':');
    final id = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final kind = parts.length > 2 ? parts[2] : 'text';
    final label =
        kind == 'image' ? 'Photo' : (kind == 'file' ? 'File' : 'Message');
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: opened ? null : () => openOneTime(index, id, kind),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: opened ? Colors.grey.shade200 : const Color(0xFF17152A),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                opened ? Icons.visibility_off_outlined : Icons.lock_outline,
                size: 18,
                color: opened ? Colors.black45 : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                opened
                    ? 'Opened · $label'
                    : 'One-time $label · Tap to open',
                style: TextStyle(
                  fontSize: 14,
                  color: opened ? Colors.black45 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openOneTime(int index, int itemId, String kind) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open one-time item?'),
        content: const Text(
          'You can view this only once. After you close it, it is deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (go != true) return;
    try {
      final response = await dio.post('/api/onetime/$itemId/view');
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      if (!mounted) return;
      if (index < messages.length) {
        setState(() {
          messages[index]['content'] = '[[ONETIME_OPENED:$itemId:$kind]]';
        });
      }
      if (data['success'] == true) {
        await showOneTimeViewer(data);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 410 && index < messages.length) {
        setState(() {
          messages[index]['content'] = '[[ONETIME_OPENED:$itemId:$kind]]';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already opened')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open. Try again.')),
        );
      }
    }
  }

  final MethodChannel secureChannel = const MethodChannel('wayvo/secure');

  Future<void> setSecure(bool on) async {
    try {
      await secureChannel.invokeMethod(on ? 'on' : 'off');
    } catch (_) {}
  }

  Future<void> showOneTimeViewer(dynamic data) async {
    final kind = (data['kind'] ?? 'text').toString();
    final filename = (data['filename'] ?? '').toString();
    final b64 = data['data_b64'];
    final bytes = b64 != null ? base64Decode(b64.toString()) : null;

    Widget content;
    if (kind == 'image' && bytes != null) {
      content = InteractiveViewer(
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
      );
    } else if (kind == 'file' && bytes != null) {
      final lower = filename.toLowerCase();
      final textLike = ['.txt', '.md', '.csv', '.json', '.xml', '.log']
          .any((e) => lower.endsWith(e));
      String body;
      if (textLike) {
        body = utf8.decode(bytes, allowMalformed: true);
      } else {
        body = '$filename\n\n${(bytes.length / 1024).toStringAsFixed(1)} KB\n\n'
            'Preview not available for this file type.';
      }
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            body,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    } else {
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            (data['text'] ?? '').toString(),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }

    await setSecure(true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF17152A),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'One-time view · deleted after closing',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
    await setSecure(false);
  }

  Widget buildMessages() {
    if (!sending) waitStart = null;
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (messages.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => copyText(
                  messages
                      .map((m) => '${m['role']}: ${m['content']}')
                      .join('\n\n'),
                  'Chat copied',
                ),
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('Copy all'),
              ),
            ),
          ...List.generate(
          messages.length,
          (index) {
            final message = messages[index];
            final isUser =
                message['role'] == 'You';

            if ((message['content'] ?? '').startsWith('[[ONETIME')) {
              return buildOneTimeBubble(index, message);
            }

            return Align(
              alignment: isUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 800
                      ? MediaQuery.of(context).size.width * 0.86
                      : 650,
                ),
                margin:
                    const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF17152A)
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color: isUser
                        ? Colors.transparent
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      message['content'] ?? '',
                      contextMenuBuilder: (ctx, editableTextState) =>
                          wayvoSelectionMenu(
                        ctx,
                        editableTextState,
                        message['content'] ?? '',
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isUser
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isUser)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                editMessage(message['content'] ?? ''),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        if (isUser) const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => copyText(
                            message['content'] ?? '',
                            'Copied',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: isUser
                                  ? Colors.white54
                                  : Colors.black38,
                            ),
                          ),
                        ),
                        if (!isUser) const SizedBox(width: 6),
                        if (!isUser)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                shareText(message['content'] ?? ''),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.ios_share,
                                size: 16,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
          if (sending) buildThinkingBubble(),
        ],
      ),
    );
  }

  Widget buildSlowLoader(double fill, String label) {
    const dark = Color(0xFF17152A);
    const base = TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: 4,
      height: 1.1,
    );
    final dots =
        '.' * (1 + (DateTime.now().millisecondsSinceEpoch ~/ 450) % 3);
    final pulseOpacity =
        0.4 + 0.6 * (fill < 0.5 ? fill * 2 : (1 - fill) * 2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Text(
              'WV',
              style: base.copyWith(color: dark.withValues(alpha: 0.15)),
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: fill,
                heightFactor: 1.0,
                child: Text('WV', style: base.copyWith(color: dark)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: pulseOpacity,
                child: const Icon(
                  Icons.signal_cellular_alt,
                  size: 18,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.replaceAll('…', '') + dots,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildThinkingBubble() {
    waitStart ??= DateTime.now();
    final lastText =
        messages.isNotEmpty ? (messages.last['content'] ?? '') : '';
    final isDoc = lastText.startsWith('Document: ');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final t = pulse.value;
            final secs = DateTime.now()
                .difference(waitStart ?? DateTime.now())
                .inSeconds;
            String label;
            if (secs >= 25) {
              label = isDoc
                  ? 'Pedda file, chadvutunna…'
                  : 'Network slow ga undi, wait chey';
            } else if (secs >= 8) {
              label = 'Konchem slow ga undi, inka chestunna…';
            } else {
              label = 'Thinking…';
            }
            if (secs >= 8) {
              final ms = DateTime.now()
                  .difference(waitStart ?? DateTime.now())
                  .inMilliseconds;
              final fill = (ms % 2600) / 2600.0;
              return buildSlowLoader(fill, label);
            }
            const dark = Color(0xFF17152A);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark,
                    boxShadow: [
                      BoxShadow(
                        color: dark.withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 1 + 5 * t,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Container(
                            width: 6,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 10,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildVoiceAvatar(String status) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        final isSpeaking = status == 'Speaking…';
        final isListening = status == 'Listening…';
        final isThinking = status == 'Thinking…';
        final scale = isListening
            ? 1 + 0.10 * t
            : (isSpeaking ? 1 + 0.05 * t : 1.0);
        final baseColor = isSpeaking
            ? const Color(0xFF2E7D32)
            : const Color(0xFF17152A);
        final eyeH = isThinking ? 4.0 : 14.0;
        final mouthH = isSpeaking ? 5 + 16 * t : (isListening ? 8.0 : 4.0);
        final mouthW = isSpeaking ? 22 + 6 * t : 22.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: (isListening || isSpeaking) ? 10 * t : 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: eyeH,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 22),
                    Container(
                      width: 14,
                      height: eyeH,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: mouthW,
                  height: mouthH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildVoicePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F2),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: voiceStatus,
              builder: (context, status, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildVoiceAvatar(status),
                  const SizedBox(height: 14),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<String>(
              valueListenable: voiceText,
              builder: (context, t, _) => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 60),
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    iconSize: 26,
                    padding: const EdgeInsets.all(12),
                    onPressed: () async {
                      if (speaking) await stopSpeaking();
                      startVoiceListen();
                    },
                    icon: const Icon(Icons.mic),
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF17152A),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 26,
                    padding: const EdgeInsets.all(12),
                    onPressed: closeVoiceMode,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInputArea(bool isMobile) {
    if (voiceMode) return buildVoicePanel();
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 24,
        12,
        isMobile ? 12 : 24,
        16,
      ),
      color: const Color(0xFFF8F7F2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: IconButton(
              onPressed: sending ? null : chooseAttachmentSource,
              icon: const Icon(Icons.add, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      focusNode: inputFocus,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) {
                        if (!isMobile) {
                          sendMessage();
                        }
                      },
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      cursorColor: Colors.black87,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFFFFDF7),
                        hintText: 'What do you want to get done?',
                        hintStyle: TextStyle(color: Colors.black45),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: sending ? null : toggleMicrophone,
                    icon: Icon(
                      listening ? Icons.mic : Icons.mic_none,
                      color: listening ? Colors.red : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF17152A),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: sending
                      ? null
                      : (hasText ? sendMessage : openVoiceMode),
                  icon: Icon(
                    hasText ? Icons.arrow_upward : Icons.graphic_eq,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
