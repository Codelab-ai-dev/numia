import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/message.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _messages = <Message>[];
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  bool _isStreaming = false;
  String? _conversationId;
  int _msgCounter = 0;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isStreaming) return;

    _inputCtrl.clear();

    setState(() {
      _messages.add(Message(
        id: 'msg_${_msgCounter++}',
        content: text,
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    final assistantId = 'msg_${_msgCounter++}';
    setState(() {
      _isStreaming = true;
      _messages.add(Message(
        id: assistantId,
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/api/v1/coach/chat',
        data: {
          'message': text,
          if (_conversationId != null) 'conversation_id': _conversationId,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final rs = response.data as ResponseBody;
      String buffer = '';
      await for (final chunk in rs.stream) {
        final decoded = utf8.decode(chunk);
        buffer += decoded;
        // Process complete SSE events (separated by \n\n)
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final event = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          if (!event.startsWith('data: ')) continue;
          final data = event.substring(6); // Remove "data: " prefix

          if (data == '[DONE]') break;

          final json = jsonDecode(data) as Map<String, dynamic>;

          if (json.containsKey('token')) {
            // Append token to assistant message
            setState(() {
              final msgIdx = _messages.indexWhere((m) => m.id == assistantId);
              if (msgIdx != -1) {
                final old = _messages[msgIdx];
                _messages[msgIdx] = Message(
                  id: old.id,
                  content: old.content + (json['token'] as String),
                  role: MessageRole.assistant,
                  timestamp: old.timestamp,
                );
              }
            });
            _scrollToBottom();
          } else if (json.containsKey('conversation_id')) {
            // Done event — save conversation ID
            _conversationId = json['conversation_id'] as String;
          } else if (json.containsKey('error')) {
            // Error from server
            throw Exception(json['error']);
          }
        }
      }

      if (mounted) setState(() => _isStreaming = false);
    } catch (e, st) {
      debugPrint('Coach error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        final idx = _messages.indexWhere((m) => m.id == assistantId);
        if (idx != -1) {
          _messages[idx] = Message(
            id: assistantId,
            content: 'Hubo un error al conectar con el coach. Intenta de nuevo.',
            role: MessageRole.assistant,
            timestamp: DateTime.now(),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: Column(
          children: [
            // App bar area
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NSpacing.pageH, NSpacing.sp3, NSpacing.pageH, NSpacing.sp3,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        gradient: NColors.grad,
                        shape: BoxShape.circle,
                        boxShadow: [NColors.glowIndigo],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: NSpacing.sp3),
                    Text('Coach numia', style: NTypography.title.copyWith(color: ct.textPrimary)),
                    const SizedBox(width: NSpacing.sp2),
                    const NBadge(label: 'IA', variant: NBadgeVariant.emerald),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(
                        NSpacing.pageH, NSpacing.sp4, NSpacing.pageH, NSpacing.sp4,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _ChatBubble(
                        message: _messages[i],
                        isStreaming: _isStreaming && i == _messages.length - 1,
                      ),
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState() {
    final ct = NColorTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: NColors.grad,
                shape: BoxShape.circle,
                boxShadow: [NColors.glowIndigo],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
            ),
            const SizedBox(height: NSpacing.sp6),
            Text(
              'Tu coach financiero',
              style: NTypography.h2.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Pregúntame sobre ahorro, deudas,\ninversiones o cualquier duda financiera',
              style: NTypography.body.copyWith(color: ct.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp8),

            Wrap(
              spacing: NSpacing.sp2,
              runSpacing: NSpacing.sp2,
              alignment: WrapAlignment.center,
              children: [
                _QuickPrompt(
                  label: '¿Cómo pago mi deuda más rápido?',
                  onTap: () {
                    _inputCtrl.text = '¿Cómo pago mi deuda más rápido?';
                    _send();
                  },
                ),
                _QuickPrompt(
                  label: '¿En qué debería invertir?',
                  onTap: () {
                    _inputCtrl.text = '¿En qué debería invertir?';
                    _send();
                  },
                ),
                _QuickPrompt(
                  label: 'Hazme un presupuesto 50/30/20',
                  onTap: () {
                    _inputCtrl.text = 'Hazme un presupuesto con la regla 50/30/20 para un ingreso de \$25,000 MXN';
                    _send();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Input bar — glass effect ──
  Widget _buildInputBar() {
    final ct = NColorTheme.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ct.glassBlur / 2,
          sigmaY: ct.glassBlur / 2,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            NSpacing.sp4, NSpacing.sp3, NSpacing.sp3, NSpacing.sp3,
          ),
          decoration: BoxDecoration(
            color: ct.surface1,
            border: Border(top: BorderSide(color: ct.borderSubtle)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      color: ct.textPrimary,
                      fontSize: 15,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Pregúntale a numia...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: ct.textTertiary,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: ct.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: NSpacing.sp4,
                        vertical: NSpacing.sp3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(NSpacing.rLg),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NSpacing.sp2),
                GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _isStreaming ? null : NColors.grad,
                      color: _isStreaming ? ct.surface3 : null,
                      shape: BoxShape.circle,
                      boxShadow: _isStreaming ? null : const [NColors.glowIndigo],
                    ),
                    child: _isStreaming
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ct.accent1,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Chat bubble
// ─────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.isStreaming = false});
  final Message message;
  final bool isStreaming;

  bool get isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: NSpacing.sp3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                gradient: NColors.grad,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: NSpacing.sp2),
          ],
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(NSpacing.rLg),
                topRight: const Radius.circular(NSpacing.rLg),
                bottomLeft: Radius.circular(isUser ? NSpacing.rLg : 4),
                bottomRight: Radius.circular(isUser ? 4 : NSpacing.rLg),
              ),
              child: BackdropFilter(
                filter: isUser
                    ? ImageFilter.blur()
                    : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4,
                    vertical: NSpacing.sp3,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser ? NColors.grad : null,
                    color: isUser ? null : ct.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(NSpacing.rLg),
                      topRight: const Radius.circular(NSpacing.rLg),
                      bottomLeft: Radius.circular(isUser ? NSpacing.rLg : 4),
                      bottomRight: Radius.circular(isUser ? 4 : NSpacing.rLg),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: ct.borderSubtle),
                    boxShadow: isUser
                        ? [BoxShadow(color: NColors.indigo.withValues(alpha: 0.2), blurRadius: 12)]
                        : null,
                  ),
                  child: message.content.isEmpty && isStreaming
                      ? _buildTypingIndicator(ct)
                      : Text(
                          message.content,
                          style: GoogleFonts.plusJakartaSans(
                            color: isUser ? Colors.white : ct.textPrimary,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: NSpacing.sp10),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(NColorTheme ct) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 200)),
          curve: Curves.easeInOut,
          builder: (_, value, __) {
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: ct.textTertiary.withValues(alpha: value),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// Quick prompt chip — glass pill
// ─────────────────────────────────────────────
class _QuickPrompt extends StatelessWidget {
  const _QuickPrompt({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NSpacing.rFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NSpacing.sp4,
              vertical: NSpacing.sp2 + 2,
            ),
            decoration: BoxDecoration(
              color: ct.surface2,
              borderRadius: BorderRadius.circular(NSpacing.rFull),
              border: Border.all(color: ct.borderDefault),
            ),
            child: Text(
              label,
              style: NTypography.caption.copyWith(color: ct.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
