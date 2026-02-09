import 'package:flutter/material.dart';

import '../game/save_data.dart';
import '../game/save_manager.dart';

class MainMenu extends StatefulWidget {
  final VoidCallback onNewGame;
  final void Function(SaveData saveData) onLoadGame;

  const MainMenu({
    super.key,
    required this.onNewGame,
    required this.onLoadGame,
  });

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final SaveManager _saveManager = SaveManager();
  List<SaveMetadata>? _saves;
  bool _showSaveList = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaveList();
  }

  Future<void> _loadSaveList() async {
    final saves = await _saveManager.listSaves();
    if (mounted) setState(() => _saves = saves);
  }

  Future<void> _deleteSave(String id) async {
    await _saveManager.delete(id);
    await _loadSaveList();
  }

  Future<void> _onSelectSave(SaveMetadata meta) async {
    setState(() => _loading = true);
    final data = await _saveManager.load(meta.id);
    if (data != null && mounted) {
      widget.onLoadGame(data);
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPlaytime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A1A),
      child: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Color(0xFFFFD166))
            : _showSaveList
                ? _buildSaveList()
                : _buildMainButtons(),
      ),
    );
  }

  Widget _buildMainButtons() {
    final hasSaves = _saves != null && _saves!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        const Text(
          'MINNERS',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD166),
            letterSpacing: 8,
            shadows: [
              Shadow(
                color: Color(0xFF8B4513),
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'A Mining Adventure',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF888888),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 48),

        // New Game button
        _MenuButton(
          label: 'New Game',
          icon: Icons.add,
          color: const Color(0xFF4CAF50),
          onTap: widget.onNewGame,
        ),
        const SizedBox(height: 16),

        // Load Game button
        _MenuButton(
          label: 'Load Game',
          icon: Icons.folder_open,
          color: hasSaves ? const Color(0xFF42A5F5) : const Color(0xFF555555),
          onTap: hasSaves ? () => setState(() => _showSaveList = true) : null,
        ),
      ],
    );
  }

  Widget _buildSaveList() {
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _showSaveList = false),
              ),
              const Text(
                'Load Game',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Save list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _saves!.length,
              itemBuilder: (ctx, i) => _buildSaveCard(_saves![i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveCard(SaveMetadata meta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF444444)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onSelectSave(meta),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Save info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTimestamp(meta.timestamp)}  |  '
                        '${meta.gold}G  |  '
                        '${_formatPlaytime(meta.playtimeSeconds)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFF666666), size: 20),
                  onPressed: () => _showDeleteConfirm(meta),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(SaveMetadata meta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Delete Save?',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${meta.name}"?',
            style: const TextStyle(color: Color(0xFFCCCCCC))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSave(meta.id);
            },
            child:
                const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 240,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: enabled ? color.withValues(alpha: 0.15) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: enabled ? color : const Color(0xFF333333),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: enabled ? color : const Color(0xFF555555),
                    size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.white : const Color(0xFF555555),
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
