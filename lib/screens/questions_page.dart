import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:game/database/app_database.dart';
import 'package:game/services/excel_service.dart';

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  String _searchQuery = '';
  bool _isLoading = false;

  Future<void> _importFromExcel() async {
    setState(() => _isLoading = true);
    try {
      final count = await ExcelService.pickAndImportQuestions(replaceExisting: true);
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد $count سؤال بنجاح من ملف الـ Excel!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء الاستيراد: ${e.toString().replaceAll('Exception: ', '')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    try {
      final success = await ExcelService.exportQuestionsToExcel();
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تصدير ملف الـ Excel بنجاح!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء التصدير: ${e.toString().replaceAll('Exception: ', '')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showQuestionFormDialog({Question? questionToEdit}) async {
    final isEditing = questionToEdit != null;
    final formKey = GlobalKey<FormState>();

    final questionController =
        TextEditingController(text: questionToEdit?.question ?? '');
    final optAController =
        TextEditingController(text: questionToEdit?.optionA ?? '');
    final optBController =
        TextEditingController(text: questionToEdit?.optionB ?? '');
    final optCController =
        TextEditingController(text: questionToEdit?.optionC ?? '');
    final optDController =
        TextEditingController(text: questionToEdit?.optionD ?? '');
    int selectedAnswerNumber = questionToEdit?.answerNumber ?? 1;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.add_circle,
                      color: const Color(0xFF667eea),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'تعديل السؤال' : 'إضافة سؤال جديد',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: questionController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'نص السؤال *',
                              prefixIcon: const Icon(Icons.help_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? 'يرجى إدخال نص السؤال'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'الخيارات الأربعة (حدد الإجابة الصحيحة بالنقر على الزر):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildOptionFormField(
                            letter: 'A',
                            controller: optAController,
                            isSelected: selectedAnswerNumber == 1,
                            onSelect: () =>
                                setDialogState(() => selectedAnswerNumber = 1),
                          ),
                          const SizedBox(height: 8),
                          _buildOptionFormField(
                            letter: 'B',
                            controller: optBController,
                            isSelected: selectedAnswerNumber == 2,
                            onSelect: () =>
                                setDialogState(() => selectedAnswerNumber = 2),
                          ),
                          const SizedBox(height: 8),
                          _buildOptionFormField(
                            letter: 'C',
                            controller: optCController,
                            isSelected: selectedAnswerNumber == 3,
                            onSelect: () =>
                                setDialogState(() => selectedAnswerNumber = 3),
                          ),
                          const SizedBox(height: 8),
                          _buildOptionFormField(
                            letter: 'D',
                            controller: optDController,
                            isSelected: selectedAnswerNumber == 4,
                            onSelect: () =>
                                setDialogState(() => selectedAnswerNumber = 4),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'الإجابة الصحيحة المحددة: الخيار رقم $selectedAnswerNumber (${_getLetter(selectedAnswerNumber)})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final qText = questionController.text.trim();
                      final optA = optAController.text.trim();
                      final optB = optBController.text.trim();
                      final optC = optCController.text.trim();
                      final optD = optDController.text.trim();

                      if (isEditing) {
                        await appDatabase.updateQuestionData(
                          id: questionToEdit.id,
                          question: qText,
                          optionA: optA,
                          optionB: optB,
                          optionC: optC,
                          optionD: optD,
                          answerNumber: selectedAnswerNumber,
                        );
                      } else {
                        await appDatabase.insertQuestion(
                          QuestionsCompanion(
                            question: Value(qText),
                            optionA: Value(optA),
                            optionB: Value(optB),
                            optionC: Value(optC),
                            optionD: Value(optD),
                            answerNumber: Value(selectedAnswerNumber),
                          ),
                        );
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? 'تم تحديث السؤال بنجاح!'
                                  : 'تمت إضافة السؤال بنجاح!',
                              textAlign: TextAlign.center,
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'حفظ التعديلات' : 'إضافة السؤال',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getLetter(int num) {
    switch (num) {
      case 1:
        return 'A';
      case 2:
        return 'B';
      case 3:
        return 'C';
      case 4:
        return 'D';
      default:
        return 'A';
    }
  }

  Widget _buildOptionFormField({
    required String letter,
    required TextEditingController controller,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Row(
      children: [
        InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    letter,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'الخيار $letter',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (val) => val == null || val.trim().isEmpty
                ? 'يرجى إدخال الخيار $letter'
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _restoreDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة الأسئلة الافتراضية', textAlign: TextAlign.right),
        content: const Text(
          'هل تريد مسح الأسئلة الحالية واستعادة بنك الأسئلة الافتراضي؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('استعادة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await appDatabase.deleteAllQuestions();
      await ExcelService.seedDefaultQuestionsIfEmpty();
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت استعادة الأسئلة الافتراضية بنجاح!', textAlign: TextAlign.center),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح كافة الأسئلة', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف جميع الأسئلة؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await appDatabase.deleteAllQuestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم مسح جميع الأسئلة', textAlign: TextAlign.center),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'بنك الأسئلة والأجوبة (Drift DB)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF667eea),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'استعادة الافتراضي',
              onPressed: _restoreDefaults,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'مسح الكل',
              onPressed: _clearAll,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showQuestionFormDialog(),
          backgroundColor: const Color(0xFF667eea),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'إضافة سؤال',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
          child: Column(
            children: [
              // Top Action Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Action Buttons Row (Import, Export, Add)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _importFromExcel,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.upload_file, color: Colors.white, size: 20),
                              label: const Text(
                                'استيراد Excel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _exportToExcel,
                              icon: const Icon(Icons.download, color: Colors.white, size: 20),
                              label: const Text(
                                'تصدير Excel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0288D1),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showQuestionFormDialog(),
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                              label: const Text(
                                'إضافة سؤال',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF673AB7),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'هيكلية الـ Excel: question, a, b, c, d, anwser_number',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Search field
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'ابحث في الأسئلة أو الخيارات...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Questions List from Stream
              Expanded(
                child: StreamBuilder<List<Question>>(
                  stream: appDatabase.watchAllQuestions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final all = snapshot.data ?? [];
                    final filtered = _searchQuery.isEmpty
                        ? all
                        : all.where((q) {
                            final query = _searchQuery.toLowerCase();
                            return q.question.toLowerCase().contains(query) ||
                                q.optionA.toLowerCase().contains(query) ||
                                q.optionB.toLowerCase().contains(query) ||
                                q.optionC.toLowerCase().contains(query) ||
                                q.optionD.toLowerCase().contains(query);
                          }).toList();

                    if (all.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'لا توجد أسئلة حالياً في قاعدة البيانات',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'يمكنك إضافة سؤال يدوياً، أو استيراد ملف Excel، أو استعادة الأسئلة الافتراضية',
                                style: TextStyle(color: Colors.black54),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _showQuestionFormDialog(),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7)),
                                    child: const Text('إضافة سؤال', style: TextStyle(color: Colors.white)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _restoreDefaults,
                                    child: const Text('استعادة الافتراضي'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Text(
                            'إجمالي الأسئلة: ${filtered.length} من أصل ${all.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildQuestionCard(item, index + 1);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question item, int displayIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.white.withValues(alpha: 0.97),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header with Edit & Delete actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF667eea),
                  child: Text(
                    '$displayIndex',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.question,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 22),
                  tooltip: 'تعديل هذا السؤال',
                  onPressed: () => _showQuestionFormDialog(questionToEdit: item),
                ),
                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                  tooltip: 'حذف هذا السؤال',
                  onPressed: () => appDatabase.deleteQuestionById(item.id),
                ),
              ],
            ),
            const Divider(height: 20),

            // Options Grid (2x2)
            Row(
              children: [
                Expanded(
                  child: _buildOptionItem('A', item.optionA, item.answerNumber == 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionItem('B', item.optionB, item.answerNumber == 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOptionItem('C', item.optionC, item.answerNumber == 3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionItem('D', item.optionD, item.answerNumber == 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(String letter, String text, bool isCorrect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect ? Colors.green.shade600 : Colors.grey.shade300,
          width: isCorrect ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: isCorrect ? Colors.green.shade600 : Colors.grey.shade400,
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                color: isCorrect ? Colors.green.shade900 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCorrect)
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
        ],
      ),
    );
  }
}
