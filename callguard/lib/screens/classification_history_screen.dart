import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/classification_entry.dart';
import '../services/database_service.dart';

class ClassificationHistoryScreen extends StatefulWidget {
  const ClassificationHistoryScreen({super.key});
  @override
  State<ClassificationHistoryScreen> createState() => _ClassificationHistoryScreenState();
}

class _ClassificationHistoryScreenState extends State<ClassificationHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<ClassificationEntry> _entries = [];
  bool _isLoading = true;
  int? _expandedIndex;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final e = await _db.getAllClassifications();
    if (mounted) setState(() { _entries = e; _isLoading = false; });
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today ${DateFormat.jm().format(dt)}';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday ${DateFormat.jm().format(dt)}';
    return DateFormat('dd MMM yyyy, h:mm a').format(dt);
  }

  Future<void> _delete(int id) async {
    await _db.deleteClassification(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundSubtle),
      child: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Row(children: [
          Icon(Icons.document_scanner_rounded, color: AppColors.accent, size: 24), const SizedBox(width: 10),
          const Text('Scan History', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_entries.isNotEmpty) Text('${_entries.length} scans', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ])),
        Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _entries.isEmpty ? _emptyState()
          : RefreshIndicator(onRefresh: _load, color: AppColors.accent,
              child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _entries.length, itemBuilder: (_, i) => _card(i)))),
      ])),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted), const SizedBox(height: 16),
    Text('No scans yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w500)),
    const SizedBox(height: 8),
    Text('Classification results will appear here', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
  ]));

  Widget _card(int index) {
    final e = _entries[index];
    final isFraud = e.verdict == 'FRAUD';
    final isExpanded = _expandedIndex == index;
    final accentColor = isFraud ? Colors.red : Colors.green;

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isExpanded ? accentColor.withOpacity(0.3) : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(isFraud ? '🔴 FRAUD' : '🟢 LEGIT',
                style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(width: 10),
            Text('${(e.confidenceScore * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(e.inputType == 'recording' ? Icons.mic_rounded : Icons.upload_file_rounded,
              color: AppColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textMuted, size: 20),
          ]),
          const SizedBox(height: 8),
          // Timestamp + filename
          Text(_fmtDate(e.timestamp), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (e.fileName != null) ...[
            const SizedBox(height: 2),
            Text('📁 ${e.fileName}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],

          // Expanded content
          if (isExpanded) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),

            // Transcript
            Text('TRANSCRIPT', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: SingleChildScrollView(child: Text(e.transcript,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5))),
            ),
            const SizedBox(height: 14),

            // Matched keywords
            if (e.matchedKeywords.isNotEmpty) ...[
              Text('MATCHED KEYWORDS', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: e.matchedKeywords.map((w) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.25))),
                child: Text(w, style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500)),
              )).toList()),
              const SizedBox(height: 14),
            ],

            // Unmatched words
            if (e.unmatchedWords.isNotEmpty) ...[
              Text('UNMATCHED WORDS', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: e.unmatchedWords.map((w) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                child: Text(w, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              )).toList()),
              const SizedBox(height: 14),
            ],

            // Delete button
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () { if (e.id != null) _delete(e.id!); },
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              label: const Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 13)),
            )),
          ],
        ]),
      ),
    );
  }
}
