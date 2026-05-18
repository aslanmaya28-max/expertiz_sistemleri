/// OPERATIONAL HISTORY PANEL
/// 
/// PHASE 6.3 - Enterprise Audit Trail
/// 
/// 🎯 PURPOSE:
/// Provides real-time operational history for admins to track all
/// seal operations, bulk actions, and system events with full audit trail.
/// 
/// 🚀 KEY FEATURES:
/// - Real-time audit log streaming
/// - Filterable by action type and user
/// - Color-coded severity indicators
/// - Export functionality for compliance
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/forensic_theme.dart';
import '../../providers/report_state_provider.dart';
import '../../models/audit_action.dart';

/// Operational History Panel
/// 
/// Shows audit logs and operational history
class OperationalHistoryPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const OperationalHistoryPanel({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<OperationalHistoryPanel> createState() => _OperationalHistoryPanelState();
}

class _OperationalHistoryPanelState extends ConsumerState<OperationalHistoryPanel> {
  String _selectedFilter = 'all';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(operationalLogsProvider);

    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      constraints: const BoxConstraints(maxWidth: 500, minWidth: 350),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ForensicTheme.deepSpaceBlue.withValues(alpha: 0.98),
            ForensicTheme.deepSpaceBlue.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Filters
          _buildFilters(),
          
          // Logs List
          Expanded(
            child: logsAsync.when(
              data: (logs) => _buildLogsList(logs),
              loading: () => _buildLoading(),
              error: (error, stack) => _buildError(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceMd),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ForensicTheme.textDim.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: ForensicTheme.neonCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPERATIONAL HISTORY',
                  style: ForensicTheme.title.copyWith(
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Real-time audit trail',
                  style: ForensicTheme.caption.copyWith(
                    color: ForensicTheme.textDim,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close),
              color: ForensicTheme.textDim,
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForensicTheme.spaceMd,
        vertical: ForensicTheme.spaceSm,
      ),
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip('all', 'All'),
          _buildFilterChip('seal', 'Seals'),
          _buildFilterChip('bulk', 'Bulk'),
          _buildFilterChip('reject', 'Rejects'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      label: Text(
        label,
        style: ForensicTheme.caption.copyWith(
          color: isSelected
              ? ForensicTheme.textWhite
              : ForensicTheme.textDim,
          fontSize: 11,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
      backgroundColor: ForensicTheme.textDim.withValues(alpha: 0.1),
      selectedColor: ForensicTheme.neonCyan,
      checkmarkColor: ForensicTheme.textWhite,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildLogsList(List<Map<String, dynamic>> logs) {
    final filteredLogs = _filterLogs(logs);

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: ForensicTheme.textDim.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No operational history found',
              style: ForensicTheme.body.copyWith(
                color: ForensicTheme.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(ForensicTheme.spaceSm),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = _parseAction(log['action'] as String?);
    final entityType = log['entity_type'] as String? ?? 'unknown';
    final userName = log['user_name'] as String? ?? 'Unknown';
    final createdAt = log['created_at'] as String?;
    final metadata = log['metadata'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getActionColor(action).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getActionColor(action).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                _getActionIcon(action),
                color: _getActionColor(action),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getActionLabel(action),
                  style: ForensicTheme.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _getActionColor(action),
                  ),
                ),
              ),
              Text(
                _formatTimestamp(createdAt),
                style: ForensicTheme.caption.copyWith(
                  color: ForensicTheme.textDim,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Details
          Row(
            children: [
              Icon(
                Icons.person,
                size: 12,
                color: ForensicTheme.textDim,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  userName,
                  style: ForensicTheme.caption.copyWith(
                    color: ForensicTheme.textDim,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(
                Icons.description,
                size: 12,
                color: ForensicTheme.textDim,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entityType.toUpperCase(),
                  style: ForensicTheme.caption.copyWith(
                    color: ForensicTheme.textDim,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // Metadata
          if (metadata != null && metadata.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (metadata['bulk_operation'] == true)
                  _buildMetadataChip('BULK', ForensicTheme.warningAmber),
                if (metadata['critical'] == true)
                  _buildMetadataChip('CRITICAL', ForensicTheme.atomicRed),
                if (metadata['partial_failure'] == true)
                  _buildMetadataChip('PARTIAL', ForensicTheme.warningAmber),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: ForensicTheme.caption.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ForensicTheme.neonCyan,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading operational history...',
            style: ForensicTheme.body.copyWith(
              color: ForensicTheme.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: ForensicTheme.atomicRed,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load history',
            style: ForensicTheme.body.copyWith(
              color: ForensicTheme.atomicRed,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: ForensicTheme.caption.copyWith(
              color: ForensicTheme.textDim,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =====================================================
  // HELPER METHODS
  // =====================================================

  List<Map<String, dynamic>> _filterLogs(List<Map<String, dynamic>> logs) {
    if (_selectedFilter == 'all') return logs;
    
    return logs.where((log) {
      final action = log['action'] as String?;
      
      if (_selectedFilter == 'seal') {
        return action == 'report_approved';
      } else if (_selectedFilter == 'bulk') {
        final metadata = log['metadata'] as Map<String, dynamic>? ?? {};
        return metadata['bulk_operation'] == true;
      } else if (_selectedFilter == 'reject') {
        return action == 'report_rejected';
      }
      
      return true;
    }).toList();
  }

  AuditAction _parseAction(String? actionStr) {
    // Convert database action string to AuditAction enum
    try {
      return AuditAction.values.firstWhere(
        (e) => e.toDatabaseValue == actionStr,
        orElse: () => AuditAction.reportUpdated,
      );
    } catch (e) {
      return AuditAction.reportUpdated;
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.reportApproved:
        return ForensicTheme.obsidianEmerald;
      case AuditAction.reportRejected:
        return ForensicTheme.atomicRed;
      case AuditAction.reportDeleted:
        return ForensicTheme.atomicRed;
      case AuditAction.userDeleted:
      case AuditAction.userRoleChanged:
        return ForensicTheme.warningAmber;
      default:
        return ForensicTheme.neonCyan;
    }
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.reportApproved:
        return Icons.check_circle;
      case AuditAction.reportRejected:
        return Icons.cancel;
      case AuditAction.reportDeleted:
        return Icons.delete;
      case AuditAction.userDeleted:
        return Icons.person_remove;
      case AuditAction.userRoleChanged:
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  String _getActionLabel(AuditAction action) {
    return action.displayName.toUpperCase();
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}