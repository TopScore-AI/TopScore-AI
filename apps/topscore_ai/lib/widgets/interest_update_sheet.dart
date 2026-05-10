import '../../constants/colors.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_spinner.dart';

class InterestUpdateSheet extends StatefulWidget {
  final String userId;
  const InterestUpdateSheet({super.key, required this.userId});

  @override
  State<InterestUpdateSheet> createState() => _InterestUpdateSheetState();
}

class _InterestUpdateSheetState extends State<InterestUpdateSheet> {
  final List<String> _selectedInterests = [];
  bool _isSaving = false;

  final List<String> _interestOptions = [
    'Technology & Coding',
    'Medicine & Health',
    'Engineering',
    'Arts & Design',
    'Business & Finance',
    'Law & Justice',
    'Sports & Fitness',
    'Media & Writing',
    'Agriculture & Nature',
    'Teaching & Education',
    'Music & Performance',
    'Public Service',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing interests so users can edit, not start from scratch
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user?.interests != null) {
      _selectedInterests.addAll(user!.interests!);
    }
  }

  Future<void> _saveInterests() async {
    if (_selectedInterests.isEmpty) return;

    if (widget.userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please sign in to save your interests.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update Firestore with merge:true to handle cases where doc might not exist yet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
        'interests': _selectedInterests,
        'careerMode': 'interest_based', // Flag to switch UI mode
      }, SetOptions(merge: true));

      // Refresh local user model in provider
      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).reloadUser();
        if (mounted) {
          Navigator.pop(context); // Close sheet
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.7) 
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Update Your Profile",
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We've updated Career Compass! Select your interests to get personalized career guidance.",
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),

          // Flexible Grid for Interests
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    selectedColor: const Color(
                      0xFF6C63FF,
                    ).withValues(alpha: 0.2),
                    checkmarkColor: AppColors.aiAccent,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                    labelStyle: GoogleFonts.nunito(
                      color: isSelected
                          ? AppColors.aiAccent
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedInterests.isEmpty || _isSaving
                  ? null
                  : _saveInterests,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.aiAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const AppSpinner(color: Colors.white)
                  : Text(
                      "Save & Continue",
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
