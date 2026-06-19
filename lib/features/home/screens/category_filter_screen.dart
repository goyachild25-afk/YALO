import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/models/category_filter_model.dart';
import '../../../shared/models/service_category_model.dart';

class CategoryFilterScreen extends StatefulWidget {
  final String categoryId;

  const CategoryFilterScreen({super.key, required this.categoryId});

  @override
  State<CategoryFilterScreen> createState() => _CategoryFilterScreenState();
}

class _CategoryFilterScreenState extends State<CategoryFilterScreen> {
  final Map<String, Set<String>> _answers = {}; // questionId → selected option ids
  int _currentStep = 0;
  final PageController _pageController = PageController();

  CategoryFilterConfig? get _config => categoryFilters[widget.categoryId];
  ServiceCategory? get _category =>
      serviceCategories.firstWhere((c) => c.id == widget.categoryId,
          orElse: () => serviceCategories.first);

  bool get _currentAnswered {
    if (_config == null) return false;
    final q = _config!.questions[_currentStep];
    if (!q.required) return true;
    return (_answers[q.id]?.isNotEmpty ?? false);
  }

  bool get _isLastStep =>
      _config == null ? true : _currentStep == _config!.questions.length - 1;

  // Construye un resumen legible de las respuestas para pasar al booking
  String _buildAnswersSummary() {
    if (_config == null) return '';
    final parts = <String>[];
    for (final q in _config!.questions) {
      final selected = _answers[q.id];
      if (selected == null || selected.isEmpty) continue;
      final labels = q.options
          .where((o) => selected.contains(o.id))
          .map((o) => o.label)
          .join(', ');
      parts.add('${q.question} → $labels');
    }
    return parts.join('\n');
  }

  void _selectOption(String questionId, String optionId, bool multiSelect) {
    setState(() {
      _answers.putIfAbsent(questionId, () => {});
      if (multiSelect) {
        if (_answers[questionId]!.contains(optionId)) {
          _answers[questionId]!.remove(optionId);
        } else {
          _answers[questionId]!.add(optionId);
        }
      } else {
        _answers[questionId] = {optionId};
      }
    });
  }

  void _next() {
    if (_isLastStep) {
      _goToProviders();
    } else {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_currentStep == 0) {
      context.pop();
    } else {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToProviders() {
    final summary = _buildAnswersSummary();
    context.push(
      '/service-request'
      '?category=${Uri.encodeComponent(widget.categoryId)}'
      '&name=${Uri.encodeComponent(_config?.categoryName ?? '')}'
      '&notes=${Uri.encodeComponent(summary)}',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final category = _category;

    // Si no hay filtros para esta categoría, ir directo a la solicitud
    if (config == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(
          '/service-request'
          '?category=${Uri.encodeComponent(widget.categoryId)}'
          '&name=${Uri.encodeComponent(serviceCategories.firstWhere((c) => c.id == widget.categoryId, orElse: () => serviceCategories.first).name)}',
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final total = config.questions.length;
    final progress = (_currentStep + 1) / total;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header con gradiente ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  category?.color.withValues(alpha: 0.9) ?? AppColors.primary,
                  category?.color ?? AppColors.primaryDark,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back + título
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _back,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${config.emoji}  ${config.categoryName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subtítulo
                    Text(
                      config.heroSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Barra de progreso
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pregunta ${_currentStep + 1} de $total',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Preguntas (PageView) ──────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: config.questions.length,
              itemBuilder: (context, index) {
                final q = config.questions[index];
                return _QuestionPage(
                  question: q,
                  selectedIds: _answers[q.id] ?? {},
                  onSelect: (optionId) =>
                      _selectOption(q.id, optionId, q.multiSelect),
                );
              },
            ),
          ),

          // ── Botón siguiente / finalizar ───────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Opción de saltar
                if (!_config!.questions[_currentStep].required)
                  TextButton(
                    onPressed: _next,
                    child: const Text('Omitir esta pregunta'),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _currentAnswered ? _next : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: category?.color ?? AppColors.primary,
                      disabledBackgroundColor: AppColors.divider,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLastStep
                              ? 'Ver prestadores disponibles'
                              : 'Siguiente',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _isLastStep
                              ? Icons.search_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Página de pregunta ────────────────────────────────────────────────────────
class _QuestionPage extends StatelessWidget {
  final FilterQuestion question;
  final Set<String> selectedIds;
  final void Function(String optionId) onSelect;

  const _QuestionPage({
    required this.question,
    required this.selectedIds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pregunta
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
              letterSpacing: -0.3,
            ),
          ),
          if (question.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              question.subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (question.multiSelect) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Puedes seleccionar varias opciones',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Opciones
          ...question.options.map((opt) {
            final selected = selectedIds.contains(opt.id);
            return GestureDetector(
              onTap: () => onSelect(opt.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryLighter
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Emoji
                    if (opt.emoji != null) ...[
                      Text(opt.emoji!,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                    ],
                    // Label
                    Expanded(
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Check / Radio
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 22,
                              key: ValueKey('checked'),
                            )
                          : Icon(
                              question.multiSelect
                                  ? Icons.check_box_outline_blank_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: AppColors.textHint,
                              size: 22,
                              key: const ValueKey('unchecked'),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
