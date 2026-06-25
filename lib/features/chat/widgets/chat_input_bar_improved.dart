import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Enhanced chat input bar with better button visibility and spacing
class ChatInputBarImproved extends StatefulWidget {
  final TextEditingController textController;
  final VoidCallback onSend;
  final VoidCallback onOffer;
  final bool isSending;

  const ChatInputBarImproved({
    Key? key,
    required this.textController,
    required this.onSend,
    required this.onOffer,
    required this.isSending,
  }) : super(key: key);

  @override
  State<ChatInputBarImproved> createState() => _ChatInputBarImprovedState();
}

class _ChatInputBarImprovedState extends State<ChatInputBarImproved> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8F3),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Offer button (if space permits)
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: widget.onOffer,
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  label: const Text('Enviar oferta de precio'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ),
          // Row 2: Message input + Send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.textController,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0DDD5),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0DDD5),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              // Send Button with clear visual state
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: widget.textController.text.isEmpty
                      ? LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.4),
                            AppColors.primary.withValues(alpha: 0.2),
                          ],
                        )
                      : AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: widget.textController.text.isEmpty
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        widget.textController.text.isEmpty ? null : widget.onSend,
                    borderRadius: BorderRadius.circular(28),
                    child: widget.isSending
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          )
                        : Icon(
                            widget.textController.text.isEmpty
                                ? Icons.add_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ],
          ),
          // Row 3: Offer button for mobile (inline below input)
          if (isMobile) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: widget.onOffer,
                icon: const Icon(Icons.local_offer_outlined, size: 16),
                label: const Text(
                  'Enviar oferta',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
