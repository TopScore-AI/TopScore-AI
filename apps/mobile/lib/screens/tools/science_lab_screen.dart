import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tutor_client/chat_screen.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class _Experiment {
  final String id;
  final String title;
  final String subtitle;
  final String difficulty; // Easy / Medium / Hard
  final Color color;
  final IconData icon;
  final String prompt;
  final List<String> steps;

  const _Experiment({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.difficulty,
    required this.color,
    required this.icon,
    required this.prompt,
    required this.steps,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ScienceLabScreen extends StatefulWidget {
  const ScienceLabScreen({super.key});

  @override
  State<ScienceLabScreen> createState() => _ScienceLabScreenState();
}

class _ScienceLabScreenState extends State<ScienceLabScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;
  final TextEditingController _customController = TextEditingController();
  Set<String> _favorites = {};
  String _difficultyFilter = 'All';

  static const _difficulties = ['All', 'Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _favorites = (prefs.getStringList('lab_favorites') ?? []).toSet());
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(id)) {
      _favorites.remove(id);
    } else {
      _favorites.add(id);
    }
    });
    await prefs.setStringList('lab_favorites', _favorites.toList());
  }

  // ---------------------------------------------------------------------------
  // Experiment data
  // ---------------------------------------------------------------------------
  static const _chemistry = [
    _Experiment(id: 'chem1', title: 'Sodium + Water', subtitle: 'Alkali Metal Reactions', difficulty: 'Medium', color: Color(0xFFE53935), icon: FontAwesomeIcons.fire,
      prompt: 'Simulate dropping Sodium into water step-by-step. Describe the reaction, products, observations, and safety hazards.',
      steps: ['Place water in a beaker', 'Add a small piece of sodium', 'Observe the vigorous reaction', 'Identify products: NaOH + H₂']),
    _Experiment(id: 'chem2', title: 'Acid-Base Titration', subtitle: 'Neutralization with Phenolphthalein', difficulty: 'Medium', color: Color(0xFF1E88E5), icon: FontAwesomeIcons.droplet,
      prompt: 'Simulate a titration of NaOH with HCl using phenolphthalein indicator. Show the endpoint color change.',
      steps: ['Fill burette with HCl', 'Add NaOH + indicator to flask', 'Add acid drop by drop', 'Record endpoint (pink→colorless)']),
    _Experiment(id: 'chem3', title: 'Electrolysis of Water', subtitle: 'Splitting H₂O', difficulty: 'Easy', color: Color(0xFFFDD835), icon: FontAwesomeIcons.bolt,
      prompt: 'Explain electrolysis of water. Show the setup, electrode reactions, and volume ratio of gases produced.',
      steps: ['Set up Hofmann voltameter', 'Pass DC current', 'Collect H₂ at cathode', 'Collect O₂ at anode (2:1 ratio)']),
    _Experiment(id: 'chem4', title: 'Flame Tests', subtitle: 'Metal Ion Identification', difficulty: 'Easy', color: Color(0xFFFF7043), icon: FontAwesomeIcons.fireBurner,
      prompt: 'Show flame test colors for Li, Na, K, Ca, Cu, Ba. Explain why each metal produces a different color.',
      steps: ['Clean platinum wire', 'Dip in metal salt solution', 'Hold in Bunsen flame', 'Observe characteristic color']),
    _Experiment(id: 'chem5', title: 'Rusting Investigation', subtitle: 'Conditions for Oxidation', difficulty: 'Easy', color: Color(0xFF8D6E63), icon: FontAwesomeIcons.link,
      prompt: 'Set up 3 test tubes to investigate conditions for rusting: air+water, dry air, boiled water+oil.',
      steps: ['Tube 1: nail + air + water', 'Tube 2: nail + dry air only', 'Tube 3: nail + boiled water + oil', 'Observe after 3 days']),
    _Experiment(id: 'chem6', title: 'Chromatography', subtitle: 'Separating Mixtures', difficulty: 'Easy', color: Color(0xFF7B1FA2), icon: FontAwesomeIcons.palette,
      prompt: 'Simulate paper chromatography to separate ink dyes. Explain Rf values and how to identify components.',
      steps: ['Draw ink spot on paper', 'Place in solvent', 'Allow solvent to rise', 'Calculate Rf = distance spot / distance solvent']),
    _Experiment(id: 'chem7', title: 'Haber Process', subtitle: 'Industrial Ammonia Synthesis', difficulty: 'Hard', color: Color(0xFF00897B), icon: FontAwesomeIcons.industry,
      prompt: 'Explain the Haber Process for making ammonia. Include conditions, catalyst, yield, and Le Chatelier\'s principle.',
      steps: ['Mix N₂ and H₂ (1:3 ratio)', 'Pass over iron catalyst at 450°C', 'Apply 200 atm pressure', 'Condense and recycle unreacted gases']),
  ];

  static const _physics = [
    _Experiment(id: 'phys1', title: 'Simple Pendulum', subtitle: 'Simple Harmonic Motion', difficulty: 'Easy', color: Color(0xFF8E24AA), icon: FontAwesomeIcons.stopwatch,
      prompt: 'Simulate a pendulum. Show how length affects period. Calculate T = 2π√(L/g) for different lengths.',
      steps: ['Set up pendulum of length L', 'Displace by small angle', 'Measure 10 oscillations', 'Calculate T = total time / 10']),
    _Experiment(id: 'phys2', title: "Ohm's Law", subtitle: 'V = IR Verification', difficulty: 'Easy', color: Color(0xFFFF8F00), icon: FontAwesomeIcons.plug,
      prompt: 'Build a virtual circuit to verify Ohm\'s Law. Vary voltage, measure current, plot V-I graph.',
      steps: ['Connect resistor in series with ammeter', 'Vary voltage using rheostat', 'Record V and I values', 'Plot V-I graph (slope = R)']),
    _Experiment(id: 'phys3', title: 'Refraction of Light', subtitle: 'Snell\'s Law', difficulty: 'Medium', color: Color(0xFF00ACC1), icon: FontAwesomeIcons.glasses,
      prompt: 'Shine a ray of light through a glass block. Measure angles of incidence and refraction. Calculate refractive index.',
      steps: ['Draw outline of glass block', 'Shine ray at angle i', 'Mark refracted ray inside block', 'Calculate n = sin(i)/sin(r)']),
    _Experiment(id: 'phys4', title: "Hooke's Law", subtitle: 'Spring Extension', difficulty: 'Easy', color: Color(0xFF00897B), icon: FontAwesomeIcons.ruler,
      prompt: 'Add weights to a spring and measure extension. Plot F-x graph and find spring constant k.',
      steps: ['Hang spring from clamp', 'Add 100g masses one at a time', 'Measure extension each time', 'Plot F vs x (slope = k)']),
    _Experiment(id: 'phys5', title: 'Archimedes Principle', subtitle: 'Upthrust & Density', difficulty: 'Medium', color: Color(0xFF3949AB), icon: FontAwesomeIcons.ship,
      prompt: 'Measure upthrust on an object submerged in water. Verify upthrust = weight of fluid displaced.',
      steps: ['Weigh object in air', 'Weigh object submerged in water', 'Upthrust = W_air - W_water', 'Compare with weight of displaced water']),
    _Experiment(id: 'phys6', title: 'Specific Heat Capacity', subtitle: 'Thermal Energy', difficulty: 'Medium', color: Color(0xFFE53935), icon: FontAwesomeIcons.temperatureHalf,
      prompt: 'Determine specific heat capacity of a metal block using an electrical heater. Use Q = mcΔT.',
      steps: ['Measure mass of metal block', 'Insert heater and thermometer', 'Supply known power for time t', 'Calculate c = Pt / mΔT']),
    _Experiment(id: 'phys7', title: 'Photoelectric Effect', subtitle: 'Wave-Particle Duality', difficulty: 'Hard', color: Color(0xFF6D4C41), icon: FontAwesomeIcons.sun,
      prompt: 'Explain the photoelectric effect. Show how frequency and intensity affect electron emission. Relate to Einstein\'s equation.',
      steps: ['Shine UV light on metal surface', 'Vary frequency of light', 'Measure stopping voltage', 'Plot stopping voltage vs frequency']),
  ];

  static const _biology = [
    _Experiment(id: 'bio1', title: 'Photosynthesis', subtitle: 'Light & Dark Reactions', difficulty: 'Medium', color: Color(0xFF43A047), icon: FontAwesomeIcons.leaf,
      prompt: 'Simulate photosynthesis inside a chloroplast. Show light reactions, Calvin cycle, and factors affecting rate.',
      steps: ['Set up pondweed in water', 'Vary light intensity', 'Count oxygen bubbles per minute', 'Plot rate vs light intensity']),
    _Experiment(id: 'bio2', title: 'Mitosis', subtitle: 'Cell Division Stages', difficulty: 'Medium', color: Color(0xFFE91E63), icon: FontAwesomeIcons.dna,
      prompt: 'Walk through all stages of mitosis: prophase, metaphase, anaphase, telophase. Show chromosome behavior at each stage.',
      steps: ['Prophase: chromosomes condense', 'Metaphase: align at equator', 'Anaphase: chromatids separate', 'Telophase: two nuclei form']),
    _Experiment(id: 'bio3', title: 'Osmosis in Potato', subtitle: 'Cell Transport', difficulty: 'Easy', color: Color(0xFF29B6F6), icon: FontAwesomeIcons.glassWater,
      prompt: 'Place potato strips in solutions of different concentrations. Measure mass change to determine water potential.',
      steps: ['Cut equal potato strips', 'Weigh each strip', 'Place in 0%, 5%, 10%, 20% sucrose', 'Reweigh after 30 min']),
    _Experiment(id: 'bio4', title: 'Food Tests', subtitle: 'Nutrient Identification', difficulty: 'Easy', color: Color(0xFFFF7043), icon: FontAwesomeIcons.utensils,
      prompt: 'Simulate Benedict\'s, Biuret, iodine, and ethanol emulsion tests. Identify which nutrients are present in each food sample.',
      steps: ['Benedict\'s test: reducing sugars (blue→brick red)', 'Biuret test: proteins (blue→purple)', 'Iodine test: starch (yellow→blue-black)', 'Emulsion test: lipids (white emulsion)']),
    _Experiment(id: 'bio5', title: 'Enzyme Activity', subtitle: 'Effect of pH & Temperature', difficulty: 'Hard', color: Color(0xFF7B1FA2), icon: FontAwesomeIcons.flask,
      prompt: 'Investigate how pH and temperature affect enzyme activity using catalase and hydrogen peroxide.',
      steps: ['Prepare H₂O₂ in test tubes', 'Add catalase at different pH/temps', 'Measure O₂ produced (froth height)', 'Plot rate vs pH and temperature']),
    _Experiment(id: 'bio6', title: 'Double Circulation', subtitle: 'Heart & Blood Flow', difficulty: 'Medium', color: Color(0xFFE53935), icon: FontAwesomeIcons.heartPulse,
      prompt: 'Trace blood flow through the double circulatory system. Explain pulmonary and systemic circuits.',
      steps: ['Right ventricle → pulmonary artery', 'Lungs: CO₂ out, O₂ in', 'Pulmonary vein → left atrium', 'Left ventricle → aorta → body']),
  ];



  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _identifyEquipment() async {
    try {
      final XFile? photo = kIsWeb
          ? await _picker.pickImage(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
          initialImage: photo,
          initialMessage: 'Identify this lab equipment and list 3 safety rules for using it.',
        )));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  void _startSimulation(_Experiment exp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: exp.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: FaIcon(exp.icon, color: exp.color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(exp.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps overview:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ...exp.steps.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(color: exp.color, shape: BoxShape.circle),
                  child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value, style: GoogleFonts.inter(fontSize: 13))),
              ]),
            )),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.security_rounded, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text('Safety goggles required', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange)),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                initialMessage: 'Simulate a virtual science experiment: ${exp.title}. ${exp.prompt} Guide me step-by-step with vivid descriptions.',
              )));
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Simulation'),
            style: FilledButton.styleFrom(backgroundColor: exp.color),
          ),
        ],
      ),
    );
  }

  void _launchCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    _customController.clear();
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      initialMessage: 'I want to perform a custom experiment: "$text". Simulate this scenario step-by-step. Describe setup, process, and results. If dangerous, explain why.',
    )));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: const Color(0xFF6C63FF),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Stack(children: [
                  Positioned(right: -20, top: -20, child: FaIcon(FontAwesomeIcons.flask, size: 140, color: Colors.white.withValues(alpha: 0.08))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Virtual Science Lab', style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Simulate. Experiment. Discover.', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                    ]),
                  ),
                ]),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 14),
              tabs: const [Tab(text: 'Chemistry'), Tab(text: 'Physics'), Tab(text: 'Biology'), Tab(text: '★ Saved')],
            ),
          ),
        ],
        body: Column(
          children: [
            // Difficulty filter chips
            _buildFilterRow(theme, isDark),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTab(_chemistry, theme, isDark),
                  _buildTab(_physics, theme, isDark),
                  _buildTab(_biology, theme, isDark),
                  _buildFavoritesTab(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _identifyEquipment,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_rounded),
        label: Text('Scan Equipment', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFilterRow(ThemeData theme, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _difficulties.map((d) {
          final selected = _difficultyFilter == d;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8),
            child: FilterChip(
              label: Text(d, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
              selected: selected,
              onSelected: (_) => setState(() => _difficultyFilter = d),
              selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              checkmarkColor: theme.colorScheme.primary,
              side: BorderSide(color: selected ? theme.colorScheme.primary : theme.dividerColor),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTab(List<_Experiment> experiments, ThemeData theme, bool isDark) {
    final filtered = _difficultyFilter == 'All'
        ? experiments
        : experiments.where((e) => e.difficulty == _difficultyFilter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _buildCustomInput(theme, isDark),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('No $_difficultyFilter experiments', style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ))
        else
          ...filtered.map((exp) => _buildExperimentCard(exp, theme, isDark)),
      ],
    );
  }

  Widget _buildFavoritesTab(ThemeData theme, bool isDark) {
    final all = [..._chemistry, ..._physics, ..._biology];
    final favs = all.where((e) => _favorites.contains(e.id)).toList();
    if (favs.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.star_border_rounded, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('No saved experiments yet', style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 4),
        Text('Tap ★ on any experiment to save it', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.3))),
      ]));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: favs.map((exp) => _buildExperimentCard(exp, theme, isDark)).toList(),
    );
  }

  Widget _buildCustomInput(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        const Icon(Icons.science_outlined, color: Color(0xFF6C63FF), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _customController,
            decoration: InputDecoration(
              hintText: 'Describe a custom experiment...',
              hintStyle: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.35), fontSize: 14),
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 14),
            onSubmitted: (_) => _launchCustom(),
          ),
        ),
        IconButton(icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF), size: 20), onPressed: _launchCustom),
      ]),
    );
  }

  Widget _buildExperimentCard(_Experiment exp, ThemeData theme, bool isDark) {
    final isFav = _favorites.contains(exp.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: exp.color.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _startSimulation(exp),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: exp.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: FaIcon(exp.icon, color: exp.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(exp.title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15))),
                _DifficultyBadge(exp.difficulty),
              ]),
              const SizedBox(height: 3),
              Text(exp.subtitle, style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 6),
              // Step count
              Row(children: [
                Icon(Icons.list_alt_rounded, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text('${exp.steps.length} steps', style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              ]),
            ])),
            Column(children: [
              IconButton(
                icon: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded, color: isFav ? Colors.amber : theme.colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
                onPressed: () => _toggleFavorite(exp.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: exp.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: exp.color, size: 18),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Difficulty badge widget
// ---------------------------------------------------------------------------
class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge(this.difficulty);

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty) {
      'Easy' => const Color(0xFF43A047),
      'Medium' => const Color(0xFFFB8C00),
      'Hard' => const Color(0xFFE53935),
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(difficulty, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
