import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/call_history_entry.dart';
import '../services/database_service.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});
  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<CallHistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final entries = await _db.getAllCallHistory();
    if (mounted) setState(() { _entries = entries; _isLoading = false; });
  }

  String _fmtDur(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today ${DateFormat.jm().format(dt)}';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday ${DateFormat.jm().format(dt)}';
    return DateFormat('dd MMM, h:mm a').format(dt);
  }

  Color _statusClr(String s) {
    switch (s) { case 'connected': return AppColors.success; case 'declined': return AppColors.error; default: return AppColors.warning; }
  }

  void _showDetail(CallHistoryEntry e) {
    final ctrl = TextEditingController(text: e.savedName ?? '');
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(e.savedName ?? e.remoteId, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          if (e.savedName != null) ...[const SizedBox(height: 4), Text(e.remoteId, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'monospace'))],
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _chip(e.isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded, e.isIncoming ? 'Incoming' : 'Outgoing'),
            _chip(Icons.timer_outlined, _fmtDur(e.durationSeconds)),
            _chip(Icons.info_outline, e.status.replaceAll('_', ' '), color: _statusClr(e.status)),
          ]),
          const SizedBox(height: 20),
          TextField(controller: ctrl, style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: 'Save a contact name...', hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: () async {
              final n = ctrl.text.trim();
              if (n.isNotEmpty && e.id != null) { await _db.updateSavedName(e.remoteId, n); await _loadHistory(); }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }

  Widget _chip(IconData ic, String lb, {Color? color}) => Column(children: [
    Icon(ic, color: color ?? AppColors.textSecondary, size: 22), const SizedBox(height: 4),
    Text(lb, style: TextStyle(color: color ?? AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
  ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundSubtle),
      child: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Row(children: [
          Icon(Icons.history_rounded, color: AppColors.accent, size: 24), const SizedBox(width: 10),
          const Text('Call History', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_entries.isNotEmpty) Text('${_entries.length} calls', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ])),
        Expanded(child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _entries.isEmpty ? _emptyState()
          : RefreshIndicator(onRefresh: _loadHistory, color: AppColors.accent,
              child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _entries.length, itemBuilder: (_, i) => _tile(_entries[i])))),
      ])),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.call_outlined, size: 64, color: AppColors.textMuted), const SizedBox(height: 16),
    Text('No calls yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w500)),
    const SizedBox(height: 8),
    Text('Your VoIP call history will appear here', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
  ]));

  Widget _tile(CallHistoryEntry e) => GestureDetector(
    onTap: () => _showDetail(e),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: _statusClr(e.status).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(e.isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded, color: _statusClr(e.status), size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.savedName ?? e.remoteId, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(_fmtDate(e.startTime), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          e.status == 'connected'
            ? Text(_fmtDur(e.durationSeconds), style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w600))
            : Text(e.status.replaceAll('_', ' '), style: TextStyle(color: _statusClr(e.status), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
        ]),
      ]),
    ),
  );
}
