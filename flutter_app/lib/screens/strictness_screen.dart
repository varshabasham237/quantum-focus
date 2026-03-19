import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/strictness_model.dart';
import '../services/strictness_service.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';

class StrictnessScreen extends StatefulWidget {
  const StrictnessScreen({super.key});

  @override
  State<StrictnessScreen> createState() => _StrictnessScreenState();
}

class _StrictnessScreenState extends State<StrictnessScreen> {
  final StrictnessService _strictnessService = StrictnessService(ApiService());
  bool _isLoading = true;
  StrictnessStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final status = await _strictnessService.getStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'NORMAL':
        return AppTheme.accentEmerald;
      case 'WARNING_1':
        return Colors.orangeAccent;
      case 'WARNING_2':
        return Colors.deepOrange;
      case 'LOCKDOWN':
        return AppTheme.accentRose;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Adaptive Strictness'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _status == null
              ? const Center(
                  child: Text('Failed to load strictness data', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 24),
                      _buildPenaltiesList(),
                      const SizedBox(height: 24),
                      _buildExplanation(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final color = _getLevelColor(_status!.level);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _status!.warnings >= 3 ? Icons.lock : Icons.shield,
            size: 64,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            _status!.level.replaceAll('_', ' '),
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Warnings: ${_status!.warnings} / 3',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
          if (_status!.lastEvaluated != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'Last Evaluated: ${_status!.lastEvaluated}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildPenaltiesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Penalties',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_status!.activePenalties.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.accentEmerald),
                SizedBox(width: 16),
                Text(
                  'No active penalties. Great job!',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          )
        else
          ..._status!.activePenalties.map((penalty) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRose),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        penalty,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildExplanation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: TextStyle(
              color: AppTheme.accentEmerald,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'QuantumFocus evaluates your productivity daily. If your focus score drops too low, you receive a warning. Too many warnings lead to heavy app blocking and loss of Free Mode privileges. Maintain consistent study habits to reduce warnings!',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}
