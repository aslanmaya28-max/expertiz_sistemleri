/// EVIDENCE DASHBOARD SCREEN (ADMIN)
/// 
/// FAZ-1.0 / P1 — Admin Panel Evidence Integration
/// 
/// ⚖️ PURPOSE:
/// Demonstrates production-ready integration of EvidenceCard
/// in Admin Panel with real data from Supabase RPC
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/forensic_theme.dart';
import '../../widgets/evidence_card.dart';
import '../../core/layout/base_scaffold.dart';
import '../../core/constants/roles.dart';

/// Evidence Dashboard Screen
/// 
/// Forensic UX Note: This is the reference implementation for
/// Evidence Card integration. Personnel and Customer panels
/// follow the same pattern with different RPC calls.
class EvidenceDashboardScreen extends StatefulWidget {
  const EvidenceDashboardScreen({super.key});

  @override
  State<EvidenceDashboardScreen> createState() => _EvidenceDashboardScreenState();
}

class _EvidenceDashboardScreenState extends State<EvidenceDashboardScreen> {
  /// Future for RPC call
  late Future<List<Map<String, dynamic>>> _evidenceFuture;

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  /// Load evidence from Supabase RPC
  /// 
  /// Forensic UX Note: Using RPC function for optimized
  /// query with reasoning extraction done server-side
  void _loadEvidence() {
    _evidenceFuture = Supabase.instance.client.rpc(
      'get_admin_evidence_stats',
      params: {
        'limit_count': 50,
        'offset_count': 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      role: UserRole.admin,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Expanded(
            child: _buildEvidenceGrid(),
          ),
        ],
      ),
    );
  }

  /// Build header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(ForensicTheme.spaceLg),
      decoration: BoxDecoration(
        color: ForensicTheme.forensicSlate,
        border: Border(
          bottom: BorderSide(
            // FIXED: Replaced withOpacity with withValues
            color: ForensicTheme.textDim.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard, color: ForensicTheme.neonCyan, size: 32),
          const SizedBox(width: ForensicTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EVIDENCE DASHBOARD',
                  style: ForensicTheme.headline,
                ),
                const SizedBox(height: ForensicTheme.spaceXxs),
                Text(
                  'Immutable Ledger Records - Admin View',
                  style: ForensicTheme.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: ForensicTheme.neonCyan,
            onPressed: () {
              setState(() {
                _loadEvidence();
              });
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  /// Build evidence grid with FutureBuilder
  /// 
  /// Forensic UX Note: This is the reference pattern for
  /// all panels. Personnel and Customer use identical structure.
  Widget _buildEvidenceGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _evidenceFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        
        // Error state
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        
        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }
        
        // Success - display evidence cards
        final evidenceList = snapshot.data!;
        return _buildEvidenceList(evidenceList);
      },
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ForensicTheme.neonCyan,
          ),
          const SizedBox(height: ForensicTheme.spaceMd),
          Text(
            'Loading evidence from immutable ledger...',
            style: ForensicTheme.body,
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForensicTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ForensicTheme.atomicRed,
            ),
            const SizedBox(height: ForensicTheme.spaceMd),
            Text(
              'Failed to load evidence',
              style: ForensicTheme.title,
            ),
            const SizedBox(height: ForensicTheme.spaceSm),
            Text(
              error,
              style: ForensicTheme.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ForensicTheme.spaceLg),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadEvidence();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: ForensicTheme.textDim,
          ),
          const SizedBox(height: ForensicTheme.spaceMd),
          Text(
            'No evidence records found',
            style: ForensicTheme.title,
          ),
          const SizedBox(height: ForensicTheme.spaceSm),
          Text(
            'Evidence will appear here once AI decisions are recorded',
            style: ForensicTheme.caption,
          ),
        ],
      ),
    );
  }

  /// Build evidence list/grid
  /// 
  /// Forensic UX Note: Uses adaptive layout:
  /// - Desktop (1200px+): 2 columns
  /// - Tablet (600-1200px): 1 column
  /// - Mobile (<600px): 1 column
  Widget _buildEvidenceList(List<Map<String, dynamic>> evidenceList) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine cross axis count based on screen width
        final crossAxisCount = constraints.maxWidth > ForensicTheme.breakpointDesktop
            ? 2
            : 1;
        
        return GridView.builder(
          padding: const EdgeInsets.all(ForensicTheme.spaceMd),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.2,
            crossAxisSpacing: ForensicTheme.spaceMd,
            mainAxisSpacing: ForensicTheme.spaceMd,
          ),
          itemCount: evidenceList.length,
          itemBuilder: (context, index) {
            final evidence = evidenceList[index];
            return EvidenceCard(
              evidenceId: evidence['id']?.toString() ?? '',
              timestamp: DateTime.parse(evidence['timestamp']).toUtc(),
              sha256Hash: evidence['hash'] ?? '',
              isVerified: evidence['is_verified'] ?? false,
              observation: evidence['observation'] ?? '',
              assumption: evidence['assumption'] ?? '',
              limitation: evidence['limitation'] ?? '',
              reportId: evidence['report_id']?.toString(),
              analystId: evidence['analyst_id']?.toString(),
            );
          },
        );
      },
    );
  }
}