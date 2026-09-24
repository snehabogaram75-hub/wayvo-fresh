import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';

final Dio dio = Dio(
  BaseOptions(
    baseUrl: 'http://192.168.0.113:5050',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
    },
  ),
);

final CookieJar cookieJar = CookieJar();

void main() {
  dio.interceptors.add(CookieManager(cookieJar));
  runApp(const WayvoApp());
}

class WayvoApp extends StatelessWidget {
  const WayvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        data: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (data['success'] == true) {
        if (isLogin) {
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WAYVO',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
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
                          onPressed: loading ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF17152A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
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
                                    fontWeight: FontWeight.w600,
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
// WAYVO CHAT
// =========================

class WayvoHome extends StatefulWidget {
  const WayvoHome({super.key});

  @override
  State<WayvoHome> createState() => _WayvoHomeState();
}

class _WayvoHomeState extends State<WayvoHome> {
  final messageController = TextEditingController();

  // NEW: controls chat scrolling
  final ScrollController scrollController =
      ScrollController();

  final List<Map<String, String>> messages = [];

  bool sending = false;
  bool historyOpen = false;

  // =========================
  // NEW: SCROLL TO BOTTOM
  // =========================

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

    // NEW: immediately show latest user message
    scrollToBottom();

    try {
      final response = await dio.post(
        '/api/chat',
        data: {
          'message': message,
        },
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (!mounted) return;

      if (response.statusCode == 401) {
        setState(() {
          messages.add({
            'role': 'WAYVO',
            'content': 'Please login first.',
          });
        });

        return;
      }

      setState(() {
        messages.add({
          'role': 'WAYVO',
          'content': data['reply'] ??
              'I could not generate a response.',
        });
      });

      // NEW: scroll after WAYVO reply
    } on DioException catch (e) {
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        setState(() {
          messages.add({
            'role': 'WAYVO',
            'content': 'Please login again.',
          });
        });
      } else {
        setState(() {
          messages.add({
            'role': 'WAYVO',
            'content':
                'Could not connect to WAYVO backend.',
          });
        });
      }

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

  void startNewChat() {
    setState(() {
      messages.clear();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F2),
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

          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Your conversations will appear here.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
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

            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Your conversations will appear here.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
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
          height: 72,
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

              const Expanded(
                child: Text(
                  'Personal AI Workspace',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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

  Widget buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Text(
              'What can we get done?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Tell WAYVO what you’re working on.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 28),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                buildSuggestion('Plan my day'),
                buildSuggestion('Help me learn'),
                buildSuggestion('Give me ideas'),
                buildSuggestion('Solve a problem'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSuggestion(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        messageController.text = text;
        sendMessage();
      },
    );
  }

  Widget buildMessages() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(
          messages.length,
          (index) {
            final message = messages[index];
            final isUser = message['role'] == 'You';

            return Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 650,
                ),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? const Color(0xFF17152A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isUser
                        ? Colors.transparent
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['role'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUser
                            ? Colors.white60
                            : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message['content'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isUser
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildInputArea(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 24,
        12,
        isMobile ? 12 : 24,
        16,
      ),
      color: const Color(0xFFF8F7F2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction:
                    TextInputAction.newline,
                onSubmitted: (_) {
                  if (!isMobile) {
                    sendMessage();
                  }
                },
                decoration: const InputDecoration(
                  hintText:
                      'What do you want to get done?',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.mic_none,
            ),
          ),

          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.photo_camera_outlined,
            ),
          ),

          const SizedBox(width: 4),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF17152A),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed:
                  sending ? null : sendMessage,
              icon: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
