import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import 'services/api_service.dart';
import 'services/pdf_export_service.dart';

void main() {
  runApp(const CareerPilotApp());
}

class CareerPilotApp extends StatelessWidget {
  const CareerPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI CareerPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF131B2E),
          surfaceContainerHighest: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: const DashboardShell(),
    );
  }
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  // 1. Resume Gap Analysis State
  final TextEditingController _roleController = TextEditingController(text: 'Python Developer');
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;

  // 2. Mock Interview State
  List<String> _questions = [];
  int _currentQuestionIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  Map<String, dynamic>? _feedbackResult;
  bool _isInterviewLoading = false;

  // Voice State
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // 3. Tailoring & ATS State
  final TextEditingController _tailorRoleController = TextEditingController(text: 'Python Developer');
  final TextEditingController _resumeTextController = TextEditingController();
  final TextEditingController _jdController = TextEditingController();
  bool _isTailorLoading = false;
  Map<String, dynamic>? _tailorResult;

  // 4. Market & Salary Radar State
  final TextEditingController _marketRoleController = TextEditingController(text: 'Python Developer');
  String _selectedExperienceLevel = 'Entry / Mid-Level';
  final TextEditingController _marketLocationController = TextEditingController(text: 'Hyderabad / India');
  bool _isMarketLoading = false;
  Map<String, dynamic>? _marketResult;

  final List<String> _experienceLevels = [
    'Entry Level (0-2 yrs)',
    'Entry / Mid-Level',
    'Mid-Senior (3-5 yrs)',
    'Senior / Lead (6+ yrs)',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _answerController.text = val.recognizedWords;
            });
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone access unavailable or not supported in browser.')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _submitAnalysis() async {
    if (_selectedFile == null || _roleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a role and attach your PDF or image resume')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.analyzeResume(
        targetRole: _roleController.text,
        file: _selectedFile!,
      );
      setState(() => _analysisResult = res['data']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInterviewQuestions() async {
    setState(() => _isInterviewLoading = true);
    try {
      final res = await ApiService.getMockQuestions(_roleController.text, 'Intermediate');
      setState(() {
        _questions = List<String>.from(res['questions'] ?? []);
        _currentQuestionIndex = 0;
        _feedbackResult = null;
        _answerController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isInterviewLoading = false);
    }
  }

  Future<void> _submitInterviewAnswer() async {
    if (_answerController.text.isEmpty || _questions.isEmpty) return;

    if (_isListening) {
      _toggleListening();
    }

    setState(() => _isInterviewLoading = true);
    try {
      final res = await ApiService.evaluateAnswer(
        question: _questions[_currentQuestionIndex],
        userAnswer: _answerController.text,
        targetRole: _roleController.text,
      );
      setState(() => _feedbackResult = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isInterviewLoading = false);
    }
  }

  Future<void> _submitTailor() async {
    if (_resumeTextController.text.isEmpty || _jdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your background summary and the Job Description')),
      );
      return;
    }

    setState(() => _isTailorLoading = true);
    try {
      final res = await ApiService.tailorResume(
        resumeText: _resumeTextController.text,
        jobDescription: _jdController.text,
        targetRole: _tailorRoleController.text,
      );
      setState(() => _tailorResult = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isTailorLoading = false);
    }
  }

  Future<void> _fetchMarketRadar() async {
    if (_marketRoleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a target role for market intelligence')),
      );
      return;
    }

    setState(() => _isMarketLoading = true);
    try {
      final res = await ApiService.getMarketRadar(
        targetRole: _marketRoleController.text,
        experienceLevel: _selectedExperienceLevel,
        location: _marketLocationController.text,
      );
      setState(() => _marketResult = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isMarketLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
              border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CareerPilot',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'AI Copilot Suite',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildNavItem(0, Icons.dashboard_customize_outlined, 'Gap Analysis & Roadmaps'),
                _buildNavItem(1, Icons.mic_external_on_outlined, 'Mock Interview Lab'),
                _buildNavItem(2, Icons.auto_fix_high_outlined, 'ATS Resume Optimizer'),
                _buildNavItem(3, Icons.radar_outlined, 'Live Market & Salary Radar'),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E293B).withValues(alpha: 0.7),
                          const Color(0xFF0F172A).withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          child: const Icon(Icons.bolt, color: Color(0xFF818CF8), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pro Plan Active', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                              Text('Unlimited AI Scans', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),

          // Main View Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedIndex == 0
                  ? _buildResumeAnalysisView()
                  : _selectedIndex == 1
                      ? _buildMockInterviewView()
                      : _selectedIndex == 2
                          ? _buildResumeTailorView()
                          : _buildMarketRadarView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF818CF8) : Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.65),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: RESUME & GAP ANALYSIS ---
  Widget _buildResumeAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'Resume Gap & Career Analysis',
                'Upload your PDF/Image resume to compute real-time job fit and personalized learning pathways.',
              ),
              const SizedBox(height: 28),
              _buildGlassCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _roleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Target Job Role (e.g. Python Developer, ML Engineer)', Icons.work_outline),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickResume,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(_selectedFile == null ? 'Select Resume (PDF / Image)' : 'Attached: ${_selectedFile!.name}'),
                            style: _outlinedBtnStyle(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitAnalysis,
                            icon: const Icon(Icons.auto_awesome),
                            label: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Run Career Fit Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: _primaryBtnStyle(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
              if (_analysisResult != null) ...[
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildGlassCard(
                        child: Column(
                          children: [
                            const Text('Job Alignment Score', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white70)),
                            const SizedBox(height: 20),
                            CircularPercentIndicator(
                              radius: 75.0,
                              lineWidth: 13.0,
                              percent: (((_analysisResult!['match_score'] ?? 0) as num) / 100).clamp(0.0, 1.0),
                              center: Text(
                                "${_analysisResult!['match_score']}%",
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 30.0, color: const Color(0xFF818CF8)),
                              ),
                              progressColor: const Color(0xFF6366F1),
                              backgroundColor: const Color(0xFF1E293B),
                              circularStrokeCap: CircularStrokeCap.round,
                              animation: true,
                              animationDuration: 1200,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
                                SizedBox(width: 8),
                                Text('Verified Strengths', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.from((_analysisResult!['identified_skills'] ?? []).map(
                                (s) => _buildBadge(s.toString(), const Color(0xFF065F46), const Color(0xFF34D399)),
                              )),
                            ),
                            const SizedBox(height: 20),
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 18),
                                SizedBox(width: 8),
                                Text('Critical Skill Gaps to Bridge', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.from((_analysisResult!['missing_skills'] ?? []).map(
                                (s) => _buildBadge(s.toString(), const Color(0xFF7F1D1D), const Color(0xFFF87171)),
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Structured Action Roadmap', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ElevatedButton.icon(
                      onPressed: () {
                        PdfExportService.exportRoadmapPdf(
                          targetRole: _roleController.text,
                          analysisData: _analysisResult!,
                        );
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Export Roadmap PDF'),
                      style: _secondaryBtnStyle(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List<Widget>.from((_analysisResult!['roadmap'] ?? []).asMap().entries.map(
                  (entry) => _buildRoadmapCard(entry.value, entry.key),
                )),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 2: AI MOCK INTERVIEW LAB ---
  Widget _buildMockInterviewView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'AI Technical Mock Interview',
                'Simulate realistic technical screenings with live Speech-to-Text verbal evaluations.',
              ),
              const SizedBox(height: 28),
              if (_questions.isEmpty)
                _buildGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology, size: 48, color: Color(0xFF818CF8)),
                        ),
                        const SizedBox(height: 20),
                        Text('Start Mock Technical Screening', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('Generate 5 targeted technical questions for "${_roleController.text}".', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isInterviewLoading ? null : _loadInterviewQuestions,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: _isInterviewLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Generate 5 Practice Questions'),
                          style: _primaryBtnStyle(),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms)
              else ...[
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF818CF8), fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.grey),
                            onPressed: () {
                              if (_currentQuestionIndex < _questions.length - 1) {
                                setState(() {
                                  _currentQuestionIndex++;
                                  _feedbackResult = null;
                                  _answerController.clear();
                                });
                              }
                            },
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _questions[_currentQuestionIndex],
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _answerController,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Speak using microphone or type your technical answer...', Icons.chat_bubble_outline),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _toggleListening,
                            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                            label: Text(_isListening ? 'Listening...' : 'Speak Answer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isListening ? Colors.redAccent : const Color(0xFF1E293B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton.icon(
                            onPressed: _isInterviewLoading ? null : _submitInterviewAnswer,
                            icon: const Icon(Icons.send_rounded),
                            label: _isInterviewLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Submit & Evaluate Answer'),
                            style: _primaryBtnStyle(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
                if (_feedbackResult != null) ...[
                  const SizedBox(height: 20),
                  _buildGlassCard(
                    borderColor: const Color(0xFF34D399).withValues(alpha: 0.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF065F46),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "Score: ${_feedbackResult!['score']}/10",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF34D399), fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text("Strengths: ${_feedbackResult!['strengths'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF34D399))),
                        const SizedBox(height: 8),
                        Text("Improvement Areas: ${_feedbackResult!['areas_for_improvement'] ?? ''}", style: const TextStyle(color: Colors.white70)),
                        const Divider(height: 28, color: Colors.white12),
                        Text("Model Answer: ${_feedbackResult!['model_answer'] ?? ''}", style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic, height: 1.4)),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0)
                ]
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 3: RESUME TAILOR & ATS OPTIMIZER ---
  Widget _buildResumeTailorView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'AI Resume Bullet Tailor & ATS Optimizer',
                'Align your experience directly to target Job Descriptions with metrics-driven impact points.',
              ),
              const SizedBox(height: 28),
              _buildGlassCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _tailorRoleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Target Job Title', Icons.work_outline),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _jdController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Paste Target Job Description (Requirements & Responsibilities)', Icons.description_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _resumeTextController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Your Current Experience / Project Bullets to Tailor', Icons.badge_outlined),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTailorLoading ? null : _submitTailor,
                        icon: const Icon(Icons.auto_fix_high),
                        label: _isTailorLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Optimize & Generate Tailored Bullets', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: _primaryBtnStyle(),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              if (_tailorResult != null) ...[
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildGlassCard(
                        child: Column(
                          children: [
                            const Text('ATS Match Score', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white70)),
                            const SizedBox(height: 20),
                            CircularPercentIndicator(
                              radius: 70.0,
                              lineWidth: 12.0,
                              percent: (((_tailorResult!['ats_score'] ?? 0) as num) / 100).clamp(0.0, 1.0),
                              center: Text(
                                "${_tailorResult!['ats_score']}%",
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 28.0, color: const Color(0xFF818CF8)),
                              ),
                              progressColor: const Color(0xFF6366F1),
                              backgroundColor: const Color(0xFF1E293B),
                              circularStrokeCap: CircularStrokeCap.round,
                              animation: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Missing Critical Keywords', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.from((_tailorResult!['missing_keywords'] ?? []).map(
                                (k) => _buildBadge(k.toString(), const Color(0xFF7F1D1D), const Color(0xFFF87171)),
                              )),
                            ),
                            const SizedBox(height: 18),
                            const Text('ATS Optimization Advice', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                            const SizedBox(height: 10),
                            ...List<Widget>.from((_tailorResult!['ats_tips'] ?? []).map(
                              (tip) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF60A5FA)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(tip.toString(), style: const TextStyle(fontSize: 13, color: Colors.white70))),
                                  ],
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 28),
                Text('High-Impact Tailored Bullets (Action + Tech + Impact)', style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                ...List<Widget>.from((_tailorResult!['tailored_bullets'] ?? []).map(
                  (bullet) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.bolt, color: Color(0xFF818CF8), size: 22),
                        const SizedBox(width: 14),
                        Expanded(child: Text(bullet.toString(), style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.45))),
                      ],
                    ),
                  ),
                )),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 4: LIVE MARKET & SALARY RADAR ---
  Widget _buildMarketRadarView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'Live Job Market & Compensation Radar',
                'Compute real-time role-specific salary bands, hiring demand, and skill trends.',
              ),
              const SizedBox(height: 28),
              _buildGlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _marketRoleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Target Role (e.g. ML Engineer, SRE)', Icons.work_outline),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedExperienceLevel,
                            dropdownColor: const Color(0xFF1E293B),
                            items: _experienceLevels.map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl, style: const TextStyle(color: Colors.white)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedExperienceLevel = val);
                            },
                            decoration: _inputDecoration('Experience Tier', Icons.military_tech_outlined),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _marketLocationController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Market / Location', Icons.location_on_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isMarketLoading ? null : _fetchMarketRadar,
                        icon: const Icon(Icons.radar),
                        label: _isMarketLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Scan Market Intelligence', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: _primaryBtnStyle(),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              if (_marketResult != null) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: _buildModernStatCard('Minimum Base', _marketResult!['salary']?['min'] ?? 'N/A', Colors.grey)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildModernStatCard('Median Benchmark', _marketResult!['salary']?['median'] ?? 'N/A', const Color(0xFF818CF8), isHighlighted: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildModernStatCard('Top Tier Band', _marketResult!['salary']?['max'] ?? 'N/A', const Color(0xFF34D399))),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Demand Level: ${_marketResult!['market_demand'] ?? 'High'}",
                          style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _marketResult!['hiring_sentiment'] ?? '',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, height: 1.45, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up, color: Color(0xFF34D399), size: 20),
                                SizedBox(width: 8),
                                Text('High-Demand Trending Tech', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF34D399))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.from((_marketResult!['trending_skills'] ?? []).map(
                                (s) => _buildBadge(s.toString(), const Color(0xFF065F46), const Color(0xFF34D399)),
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_down, color: Color(0xFFF87171), size: 20),
                                SizedBox(width: 8),
                                Text('Declining / Legacy Stacks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFF87171))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List<Widget>.from((_marketResult!['declining_skills'] ?? []).map(
                                (s) => _buildBadge(s.toString(), const Color(0xFF7F1D1D), const Color(0xFFF87171)),
                              )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 28),
                Text('Top Hiring Industries', style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List<Widget>.from((_marketResult!['top_industries'] ?? []).map(
                    (ind) => Chip(
                      avatar: const Icon(Icons.domain, size: 16, color: Color(0xFF818CF8)),
                      label: Text(ind.toString()),
                      backgroundColor: const Color(0xFF131B2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  )),
                ).animate().fadeIn(duration: 700.ms),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE UI SYSTEM ---
  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14.5),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildModernStatCard(String label, String amount, Color textColor, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF6366F1).withValues(alpha: 0.12) : const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF6366F1).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isHighlighted ? const Color(0xFF818CF8) : Colors.grey)),
          const SizedBox(height: 12),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapCard(Map<String, dynamic> step, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text("W${step['week'] ?? (index + 1)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step['topic'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text(step['action_item'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 12.5)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13.5),
      prefixIcon: Icon(icon, color: const Color(0xFF818CF8), size: 20),
      filled: true,
      fillColor: const Color(0xFF0F172A).withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
    );
  }

  ButtonStyle _primaryBtnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
    );
  }

  ButtonStyle _secondaryBtnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E293B),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  ButtonStyle _outlinedBtnStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white70,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}