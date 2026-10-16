import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:provider/single_child_widget.dart';


import 'package:cloud_firestore/cloud_firestore.dart' as fs; // <-- PUSH
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging, RemoteMessage; // <-- PUSH
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
    AndroidFlutterLocalNotificationsPlugin,
    AndroidInitializationSettings,
    AndroidNotificationChannel,
    AndroidNotificationDetails,
    BigTextStyleInformation,
    DarwinInitializationSettings,
    DarwinNotificationDetails,
    FlutterLocalNotificationsPlugin,
    Importance,
    InitializationSettings,
    NotificationDetails,
    Priority; // <-- PUSH
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';


import 'firebase_options.dart';

// ============================================================
// THEME COLORS  (white background, blue + pink icon palette)
// ============================================================

class AppColors {
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const pink = Color(0xFFEC4899);
  static const softBlue = Color(0xFFEFF6FF);
  static const softPink = Color(0xFFFDF2F8);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
}

/// Lets a notification tap open a screen from anywhere. // <-- PUSH
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show build/runtime errors on screen instead of a blank page
  ErrorWidget.builder = (details) => Material(
    color: Colors.white,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(details.exceptionAsString(),
            style: TextStyle(color: Colors.red.shade700)),
      ),
    ),
  );

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Firebase failed to start:\n\n$e',
                textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
    return;
  }

  // ---- PUSH NOTIFICATIONS ----
  try {
    if (_pushSupported) {
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
      await NotificationService.init();
    }
  } catch (e) {
    debugPrint('Push setup failed: $e'); // app still runs without push
  }

  runApp(MultiProvider(
    providers: AppProviders.build(),
    child: const VocabularyAIApp(),
  ));
}

// ============================================================
// APP
// ============================================================

class VocabularyAIApp extends StatelessWidget {
  const VocabularyAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.blue,
      secondary: AppColors.pink,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
      onSurface: AppColors.text,
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey, // <-- PUSH
      title: 'Vocabulary AI-ML App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: scheme,
        fontFamily: 'Roboto',
        iconTheme: const IconThemeData(color: AppColors.blue),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
              color: AppColors.blue, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              color: AppColors.blue, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(
              color: AppColors.blue, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              color: AppColors.pink, fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.blue),
          actionsIconTheme: IconThemeData(color: AppColors.pink),
          titleTextStyle: TextStyle(
              color: AppColors.blue, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.softBlue,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.blue
                  : AppColors.pink)),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.softBlue,
          selectedIconTheme: IconThemeData(color: AppColors.blue),
          unselectedIconTheme: IconThemeData(color: AppColors.pink),
          selectedLabelTextStyle: TextStyle(
              color: AppColors.blue, fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelTextStyle:
          TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.softBlue,
          selectedColor: AppColors.softPink,
          side: const BorderSide(color: AppColors.border),
          labelStyle: const TextStyle(color: AppColors.text),
          iconTheme: const IconThemeData(color: AppColors.pink),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blue,
            side: const BorderSide(color: AppColors.border),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.pink),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.blue,
          linearTrackColor: AppColors.softBlue,
          circularTrackColor: AppColors.softBlue,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.blue,
          thumbColor: AppColors.pink,
          inactiveTrackColor: AppColors.softBlue,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.pink : Colors.grey),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.border),
        listTileTheme: const ListTileThemeData(iconColor: AppColors.blue),
        expansionTileTheme: const ExpansionTileThemeData(
          iconColor: AppColors.pink,
          collapsedIconColor: AppColors.blue,
          shape: Border(),
          collapsedShape: Border(),
        ),
      ),
      home: const AuthGate(child: VocabularyHome()),
    );
  }
}

// ============================================================
// LOCAL SERVER API
// ============================================================

class VocabularyApi {
  /// Override at run time:
  /// flutter run --dart-define=VOCAB_URL=http://192.168.1.20:8000
  static const _override = String.fromEnvironment('VOCAB_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://192.168.1.41:8000'; // emulator -> PC
    return 'http://localhost:8000'; // iOS simulator, desktop
  }

  /// EXTRACT: raw JSON records straight from server.py (no cleaning here).
  static Future<List<Map<String, dynamic>>> fetchRawWords() async {
    final res = await http
        .get(Uri.parse('$baseUrl/words'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw 'Server returned ${res.statusCode}';
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    final list =
    decoded is Map ? (decoded['words'] as List? ?? []) : decoded as List;
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

// ============================================================
// VOCABULARY MODEL
// ============================================================

class VocabularyWord {
  final dynamic id;
  final String word;
  final String letter;
  final String difficultCefrStyle;
  final String difficulty;
  final String partsOfSpeech;
  final String definition;
  final String meaning;
  final List<String> synonyms;
  final String example;
  final String gmatRelevance;
  final String ieltsRelevance;
  final String usage;
  final String currentStatus;
  final String yearFocus;
  final List<String> sourceReference;
  final String sourceNote;

  VocabularyWord({
    required this.id,
    required this.word,
    required this.letter,
    required this.difficultCefrStyle,
    required this.difficulty,
    required this.partsOfSpeech,
    required this.definition,
    required this.meaning,
    required this.synonyms,
    required this.example,
    required this.gmatRelevance,
    required this.ieltsRelevance,
    required this.usage,
    required this.currentStatus,
    required this.yearFocus,
    required this.sourceReference,
    required this.sourceNote,
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    return VocabularyWord(
      id: json['id'],
      word: '${json['word'] ?? ''}',
      letter: '${json['letter'] ?? ''}',
      difficultCefrStyle:
      '${json['difficult_cefr_style'] ?? json['difficulty_cefr_style'] ?? ''}',
      difficulty: '${json['difficulty'] ?? ''}',
      partsOfSpeech:
      '${json['parts_of_speech'] ?? json['part_of_speech'] ?? ''}',
      definition: '${json['definition'] ?? ''}',
      meaning: '${json['meaning'] ?? ''}',
      synonyms: _stringList(json['synonyms']),
      example: '${json['example'] ?? ''}',
      gmatRelevance:
      '${json['gmat_relavance'] ?? json['gmat_relevance'] ?? ''}',
      ieltsRelevance:
      '${json['ielts_relavance'] ?? json['ielts_relevance'] ?? ''}',
      usage: '${json['usage'] ?? ''}',
      currentStatus: '${json['current_status'] ?? ''}',
      yearFocus: '${json['year_focus'] ?? ''}',
      sourceReference: _stringList(json['source_reference']),
      sourceNote: '${json['source_note'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'letter': letter,
    'difficult_cefr_style': difficultCefrStyle,
    'difficulty': difficulty,
    'parts_of_speech': partsOfSpeech,
    'definition': definition,
    'meaning': meaning,
    'synonyms': synonyms,
    'example': example,
    'gmat_relavance': gmatRelevance,
    'ielts_relavance': ieltsRelevance,
    'usage': usage,
    'current_status': currentStatus,
    'year_focus': yearFocus,
    'source_reference': sourceReference,
    'source_note': sourceNote,
  };

  /// TRANSFORM helper: trims text, normalises case, de-duplicates synonyms.
  VocabularyWord cleaned() {
    final w = word.trim();
    final seen = <String>{};
    final syn = <String>[];
    for (final s in synonyms) {
      final t = s.trim();
      if (t.isNotEmpty && seen.add(t.toLowerCase())) syn.add(t);
    }
    final l = letter.trim().isNotEmpty
        ? letter.trim().toUpperCase()
        : (w.isNotEmpty ? w[0].toUpperCase() : '');
    return VocabularyWord(
      id: id,
      word: w,
      letter: l,
      difficultCefrStyle: difficultCefrStyle.trim().toUpperCase(),
      difficulty: difficulty.trim(),
      partsOfSpeech: partsOfSpeech.trim(),
      definition: definition.trim(),
      meaning: meaning.trim(),
      synonyms: syn,
      example: example.trim(),
      gmatRelevance: gmatRelevance.trim(),
      ieltsRelevance: ieltsRelevance.trim(),
      usage: usage.trim(),
      currentStatus: currentStatus.trim(),
      yearFocus: yearFocus.trim(),
      sourceReference: sourceReference.map((e) => e.trim()).toList(),
      sourceNote: sourceNote.trim(),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => '$e').toList();
    if (value is String && value.trim().isNotEmpty) return [value];
    return [];
  }
}

// ============================================================
// ETL PIPELINE  (Extract -> Transform -> Load)
// ============================================================

class EtlReport {
  final String name;
  final String source;
  final int extracted;
  final int rejected;
  final int duplicates;
  final int loaded;
  final int milliseconds;
  final DateTime at;

  EtlReport({
    required this.name,
    required this.source,
    required this.extracted,
    required this.rejected,
    required this.duplicates,
    required this.loaded,
    required this.milliseconds,
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

class EtlWordsResult {
  final List<VocabularyWord> words;
  final EtlReport report;
  EtlWordsResult(this.words, this.report);
}

/// Vocabulary pipeline
///  EXTRACT   : GET /words from server.py (falls back to offline cache)
///  TRANSFORM : validate, trim, normalise, drop duplicates / empty rows
///  LOAD      : hand clean words to the app + write offline cache
class WordEtl {
  static const _cacheKey = 'vocab_words_cache_v1';

  static Future<EtlWordsResult> run() async {
    final sw = Stopwatch()..start();

    // ---- EXTRACT ----
    List<Map<String, dynamic>> raw;
    String source;
    try {
      raw = await VocabularyApi.fetchRawWords();
      source = 'server';
    } catch (e) {
      raw = await _readCache();
      if (raw.isEmpty) rethrow;
      source = 'offline cache';
    }

    // ---- TRANSFORM ----
    final seen = <String>{};
    final clean = <VocabularyWord>[];
    int rejected = 0;
    int duplicates = 0;
    for (final m in raw) {
      final w = VocabularyWord.fromJson(m).cleaned();
      if (w.word.isEmpty ||
          (w.definition.isEmpty && w.meaning.isEmpty)) {
        rejected++;
        continue;
      }
      if (!seen.add(w.word.toLowerCase())) {
        duplicates++;
        continue;
      }
      clean.add(w);
    }

    // ---- LOAD ----
    if (source == 'server' && clean.isNotEmpty) {
      await _writeCache(clean);
    }
    sw.stop();

    return EtlWordsResult(
      clean,
      EtlReport(
        name: 'Vocabulary',
        source: source,
        extracted: raw.length,
        rejected: rejected,
        duplicates: duplicates,
        loaded: clean.length,
        milliseconds: sw.elapsedMilliseconds,
      ),
    );
  }

  static Future<void> _writeCache(List<VocabularyWord> words) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(words.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// Student dataset pipeline
///  EXTRACT   : saved assessment history
///  TRANSFORM : drop invalid rows / duplicates, clamp outliers, build features
///  LOAD      : replace the stored training samples used by the ML model
class DatasetEtl {
  static Future<EtlReport> rebuildFromHistory() async {
    final sw = Stopwatch()..start();

    // ---- EXTRACT ----
    final records = await StudentStorage.loadAssessments();

    // ---- TRANSFORM ----
    final seen = <int>{};
    final samples = <PerformanceSample>[];
    int rejected = 0;
    int duplicates = 0;
    final ordered = records.reversed.toList(); // oldest first
    for (final r in ordered) {
      if (r.total <= 0 || r.score < 0 || r.score > r.total) {
        rejected++;
        continue;
      }
      if (!seen.add(r.date.millisecondsSinceEpoch)) {
        duplicates++;
        continue;
      }
      samples.add(PerformanceSample.fromRecord(r));
    }

    // ---- LOAD ----
    await StudentStorage.replaceSamples(samples);
    sw.stop();

    return EtlReport(
      name: 'Student dataset',
      source: 'assessment history',
      extracted: records.length,
      rejected: rejected,
      duplicates: duplicates,
      loaded: samples.length,
      milliseconds: sw.elapsedMilliseconds,
    );
  }
}

// ============================================================
// TEST MODELS
// ============================================================

enum QuestionType { definition, meaning, example, synonym }

class TestQuestion {
  final VocabularyWord word;
  final QuestionType type;
  final List<String> options;
  final String correctAnswer;

  TestQuestion({
    required this.word,
    required this.type,
    required this.options,
    required this.correctAnswer,
  });

  String get questionText {
    switch (type) {
      case QuestionType.definition:
        return 'Which word matches this definition?\n\n${word.definition}';
      case QuestionType.meaning:
        return 'What is the meaning of "${word.word}"?';
      case QuestionType.example:
        return 'Which word best completes this context?\n\n"${word.example}"';
      case QuestionType.synonym:
        return 'Which option is closest in meaning to "${word.word}"?';
    }
  }
}

class TestAnswer {
  final TestQuestion question;
  final String selectedAnswer;
  final bool correct;
  final int seconds;

  TestAnswer({
    required this.question,
    required this.selectedAnswer,
    required this.correct,
    required this.seconds,
  });
}

class AssessmentRecord {
  final DateTime date;
  final int score;
  final int total;
  final double averageTime;
  final int voiceScore;
  final String level;

  AssessmentRecord({
    required this.date,
    required this.score,
    required this.total,
    required this.averageTime,
    required this.voiceScore,
    required this.level,
  });

  double get percentage => total == 0 ? 0 : score / total * 100;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'score': score,
    'total': total,
    'averageTime': averageTime,
    'voiceScore': voiceScore,
    'level': level,
  };

  factory AssessmentRecord.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return AssessmentRecord(
      date: DateTime.tryParse('${json['date']}') ?? DateTime.now(),
      score: i(json['score']),
      total: i(json['total']),
      averageTime: n(json['averageTime']),
      voiceScore: i(json['voiceScore']),
      level: '${json['level'] ?? 'Developing'}',
    );
  }
}

// ============================================================
// PERSISTENT STUDENT PERFORMANCE + LOCAL ML
// ============================================================

class PerformanceSample {
  final double accuracy;
  final double speed;
  final double voiceScore;
  final double target;

  PerformanceSample({
    required this.accuracy,
    required this.speed,
    required this.voiceScore,
    required this.target,
  });

  /// Feature engineering used by both the live app and the ETL pipeline.
  factory PerformanceSample.fromRecord(AssessmentRecord r) {
    final accuracy = (r.percentage / 100).clamp(0.0, 1.0).toDouble();
    final t = r.averageTime.clamp(0.0, 120.0).toDouble(); // outlier clamp
    final speed = t <= 0 ? 1.0 : (1 / (1 + t / 15)).clamp(0.0, 1.0).toDouble();
    final voice = (r.voiceScore / 100).clamp(0.0, 1.0).toDouble();
    final target = ((accuracy * .65) + (speed * .15) + (voice * .20))
        .clamp(0.0, 1.0)
        .toDouble();
    return PerformanceSample(
        accuracy: accuracy, speed: speed, voiceScore: voice, target: target);
  }

  Map<String, dynamic> toJson() => {
    'accuracy': accuracy,
    'speed': speed,
    'voiceScore': voiceScore,
    'target': target,
  };

  factory PerformanceSample.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return PerformanceSample(
      accuracy: n(json['accuracy']).clamp(0.0, 1.0).toDouble(),
      speed: n(json['speed']).clamp(0.0, 1.0).toDouble(),
      voiceScore: n(json['voiceScore']).clamp(0.0, 1.0).toDouble(),
      target: n(json['target']).clamp(0.0, 1.0).toDouble(),
    );
  }
}

class TrainingResult {
  final List<double> trainLoss = [];
  final List<double> valLoss = [];
  int epochs = 0;
  int trainSize = 0;
  int valSize = 0;

  double get finalTrain => trainLoss.isEmpty ? 0 : trainLoss.last;
  double get finalVal => valLoss.isEmpty ? 0 : valLoss.last;
}

class StudentPerformanceML {
  double bias = 0;
  double accuracyWeight = 1.4;
  double speedWeight = .35;
  double voiceWeight = .55;
  int trainingSteps = 0;

  double _sigmoid(double x) {
    if (x < -30) return 0;
    if (x > 30) return 1;
    return 1 / (1 + exp(-x));
  }

  double _speedFeature(double averageTime) {
    if (averageTime <= 0) return 1;
    return 1 / (1 + averageTime / 15);
  }

  double predict({
    required double accuracy,
    required double averageTime,
    required double voiceScore,
  }) {
    final a = (accuracy / 100).clamp(0.0, 1.0);
    final s = _speedFeature(averageTime);
    final v = (voiceScore / 100).clamp(0.0, 1.0);
    final z = bias + accuracyWeight * a + speedWeight * s + voiceWeight * v;
    return (_sigmoid(z) * 100).clamp(0.0, 100.0).toDouble();
  }

  double _predictSample(PerformanceSample s) => _sigmoid(bias +
      accuracyWeight * s.accuracy +
      speedWeight * s.speed +
      voiceWeight * s.voiceScore);

  /// Mean squared error on a dataset.
  double loss(List<PerformanceSample> data) {
    if (data.isEmpty) return 0;
    double sum = 0;
    for (final s in data) {
      final e = s.target - _predictSample(s);
      sum += e * e;
    }
    return sum / data.length;
  }

  void train(PerformanceSample sample, {double learningRate = .08}) {
    final prediction = _predictSample(sample);
    final error = sample.target - prediction;
    bias += learningRate * error;
    accuracyWeight += learningRate * error * sample.accuracy;
    speedWeight += learningRate * error * sample.speed;
    voiceWeight += learningRate * error * sample.voiceScore;
    trainingSteps++;
  }

  void trainMany(List<PerformanceSample> samples) {
    for (final sample in samples) {
      train(sample);
    }
  }

  /// Full multi-epoch training with an 80/20 train/validation split.
  Future<TrainingResult> fit(
      List<PerformanceSample> data, {
        int epochs = 50,
        double learningRate = .08,
        void Function(int epoch, TrainingResult result)? onEpoch,
      }) async {
    final rnd = Random(7);
    final all = List<PerformanceSample>.from(data)..shuffle(rnd);
    final split = all.length >= 10 ? (all.length * .8).floor() : all.length;
    final trainSet = all.sublist(0, split);
    final valSet = split < all.length ? all.sublist(split) : trainSet;

    final result = TrainingResult()
      ..trainSize = trainSet.length
      ..valSize = valSet.length;

    for (int e = 1; e <= epochs; e++) {
      trainSet.shuffle(rnd);
      for (final s in trainSet) {
        train(s, learningRate: learningRate);
      }
      result.epochs = e;
      result.trainLoss.add(loss(trainSet));
      result.valLoss.add(loss(valSet));
      if (e % 2 == 0 || e == epochs) {
        onEpoch?.call(e, result);
        await Future<void>.delayed(Duration.zero); // let the UI repaint
      }
    }
    return result;
  }

  void reset() {
    bias = 0;
    accuracyWeight = 1.4;
    speedWeight = .35;
    voiceWeight = .55;
    trainingSteps = 0;
  }

  Map<String, dynamic> toJson() => {
    'bias': bias,
    'accuracyWeight': accuracyWeight,
    'speedWeight': speedWeight,
    'voiceWeight': voiceWeight,
    'trainingSteps': trainingSteps,
  };

  void loadFromJson(Map<String, dynamic> json) {
    double n(dynamic v, double fallback) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
    bias = n(json['bias'], bias);
    accuracyWeight = n(json['accuracyWeight'], accuracyWeight);
    speedWeight = n(json['speedWeight'], speedWeight);
    voiceWeight = n(json['voiceWeight'], voiceWeight);
    trainingSteps = (json['trainingSteps'] is num)
        ? (json['trainingSteps'] as num).toInt()
        : int.tryParse('${json['trainingSteps']}') ?? trainingSteps;
  }
}

/// Storage keys are prefixed with the signed-in user's uid, so students
/// sharing one device do not see each other's data.
class StudentStorage {
  static String _k(String base) =>
      '${base}_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}';

  static String get _historyKey => _k('vocabulary_assessment_history');
  static String get _samplesKey => _k('student_performance_samples');
  static String get _modelKey => _k('student_ml_model');

  static Future<void> saveAssessment(AssessmentRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadAssessments();
    list.insert(0, record);
    final trimmed = list.take(100).map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, trimmed);
  }

  static Future<List<AssessmentRecord>> loadAssessments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final result = <AssessmentRecord>[];
    for (final item in raw) {
      try {
        result.add(AssessmentRecord.fromJson(
            Map<String, dynamic>.from(jsonDecode(item))));
      } catch (_) {}
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static Future<void> savePerformanceSample(PerformanceSample sample) async {
    final prefs = await SharedPreferences.getInstance();
    final samples = await loadPerformanceSamples();
    samples.add(sample);
    await replaceSamples(samples, prefs: prefs);
  }

  static Future<void> replaceSamples(List<PerformanceSample> samples,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final trimmed =
    samples.length > 500 ? samples.sublist(samples.length - 500) : samples;
    await p.setStringList(
        _samplesKey, trimmed.map((e) => jsonEncode(e.toJson())).toList());
  }

  static Future<List<PerformanceSample>> loadPerformanceSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_samplesKey) ?? [];
    final result = <PerformanceSample>[];
    for (final item in raw) {
      try {
        result.add(PerformanceSample.fromJson(
            Map<String, dynamic>.from(jsonDecode(item))));
      } catch (_) {}
    }
    return result;
  }

  static Future<void> saveModel(StudentPerformanceML model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, jsonEncode(model.toJson()));
  }

  static Future<StudentPerformanceML> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final model = StudentPerformanceML();
    final raw = prefs.getString(_modelKey);
    if (raw != null) {
      try {
        model.loadFromJson(Map<String, dynamic>.from(jsonDecode(raw)));
      } catch (_) {}
    }
    return model;
  }

  static Future<void> clearStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_samplesKey);
    await prefs.remove(_modelKey);
  }
}

// ============================================================
// HOME
// ============================================================

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavItem(this.label, this.icon, this.selectedIcon);
}

class VocabularyHome extends StatefulWidget {
  const VocabularyHome({super.key});

  @override
  State<VocabularyHome> createState() => _VocabularyHomeState();
}

class _VocabularyHomeState extends State<VocabularyHome> {
  int selectedIndex = 0;

  List<VocabularyWord> words = [];
  bool loading = true;
  String? error;
  EtlReport? wordReport;

  final List<AssessmentRecord> history = [];
  StudentPerformanceML studentML = StudentPerformanceML();
  double currentMastery = 0;
  int totalTrainingSamples = 0;

  static const _nav = [
    _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavItem('Test', Icons.quiz_outlined, Icons.quiz),
    _NavItem('Voice', Icons.mic_none, Icons.mic),
    _NavItem('Notes', Icons.sticky_note_2_outlined, Icons.sticky_note_2),
    _NavItem('ML Training', Icons.psychology_outlined, Icons.psychology),
    _NavItem('Studio', Icons.hub_outlined, Icons.hub), // <-- STUDIO
    _NavItem('Scores', Icons.download_outlined, Icons.download),
    _NavItem('AI Coach', Icons.auto_awesome_outlined, Icons.auto_awesome),
  ];

  @override
  void initState() {
    super.initState();
    loadVocabulary();
    loadStudentData();
  }

  Future<void> loadStudentData() async {
    try {
      final savedHistory = await StudentStorage.loadAssessments();
      final samples = await StudentStorage.loadPerformanceSamples();
      final model = await StudentStorage.loadModel();
      if (model.trainingSteps == 0 && samples.isNotEmpty) {
        model.trainMany(samples);
        await StudentStorage.saveModel(model);
      }
      if (!mounted) return;
      setState(() {
        history
          ..clear()
          ..addAll(savedHistory);
        studentML = model;
        totalTrainingSamples = samples.length;
      });
      _recomputeMastery();
    } catch (_) {}
  }

  void _recomputeMastery() {
    if (!mounted) return;
    final latest = history.isNotEmpty ? history.first : null;
    setState(() {
      currentMastery = latest == null
          ? 0
          : studentML.predict(
        accuracy: latest.percentage,
        averageTime: latest.averageTime,
        voiceScore: latest.voiceScore.toDouble(),
      );
    });
  }

  /// Runs the vocabulary ETL pipeline (server -> clean -> cache).
  Future<void> loadVocabulary() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await WordEtl.run();
      if (!mounted) return;
      setState(() {
        words = result.words;
        wordReport = result.report;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  /// Called by the ML tab after training / reset / dataset rebuild.
  Future<void> onModelChanged() async {
    final samples = await StudentStorage.loadPerformanceSamples();
    if (!mounted) return;
    setState(() => totalTrainingSamples = samples.length);
    _recomputeMastery();
  }

  Future<void> addHistory(AssessmentRecord record) async {
    final sample = PerformanceSample.fromRecord(record);
    studentML.train(sample);
    await StudentStorage.saveAssessment(record);
    await StudentStorage.savePerformanceSample(sample);
    await StudentStorage.saveModel(studentML);
    if (!mounted) return;
    setState(() {
      history.insert(0, record);
      if (history.length > 100) history.removeLast();
      totalTrainingSamples++;
    });
    _recomputeMastery();

    // ---- PUSH: send report + analysis notification ----
    unawaited(AssessmentNotifier.publish(
      record,
      mastery: currentMastery,
      previous: history.length > 1 ? history[1] : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Running ETL from ${VocabularyApi.baseUrl} ...',
                  style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vocabulary AI')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: AppColors.pink),
                const SizedBox(height: 16),
                Text(
                    'Cannot reach the vocabulary server\n${VocabularyApi.baseUrl}/words',
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: loadVocabulary,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      DashboardPage(
        words: words,
        mastery: currentMastery,
        trainingSamples: totalTrainingSamples,
        dataSource: wordReport?.source ?? 'server',
        onTest: () => setState(() => selectedIndex = 1),
        onRefresh: loadVocabulary,
      ),
      TestLauncher(words: words, onCompleted: addHistory),
      VoiceTutorPage(words: words, onCompleted: addHistory),
      NotesPage(words: words),
      MLTrainingPage(
        model: studentML,
        wordReport: wordReport,
        onRefreshWords: loadVocabulary,
        onModelChanged: onModelChanged,
      ),
      StudioHubPage(
        words: words,
        history: history,
        model: studentML,
        wordReport: wordReport,
        onReloadWords: loadVocabulary,
        onModelChanged: onModelChanged,
      ), // <-- STUDIO
      ScoresPage(history: history),
      AiHubPage(words: words, history: history, mastery: currentMastery),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;

      if (wide) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final n in _nav)
                      NavigationRailDestination(
                        icon: Icon(n.icon),
                        selectedIcon: Icon(n.selectedIcon),
                        label: Text(n.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        );
      }

      // Phones: bottom navigation bar
      return Scaffold(
        body: pages[selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (i) => setState(() => selectedIndex = i),
          destinations: [
            for (final n in _nav)
              NavigationDestination(
                icon: Icon(n.icon),
                selectedIcon: Icon(n.selectedIcon),
                label: n.label,
              ),
          ],
        ),
      );
    });
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatelessWidget {
  final List<VocabularyWord> words;
  final VoidCallback onTest;
  final VoidCallback onRefresh;
  final double mastery;
  final int trainingSamples;
  final String dataSource;

  const DashboardPage({
    super.key,
    required this.words,
    required this.onTest,
    required this.onRefresh,
    required this.mastery,
    required this.trainingSamples,
    required this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary AI-ML',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              tooltip: 'Re-run ETL (reload words)',
              onPressed: onRefresh,
              icon: const Icon(Icons.sync)),
          IconButton(
              tooltip: 'Start Test',
              onPressed: onTest,
              icon: const Icon(Icons.play_circle)),
          IconButton(
              tooltip: 'Sign out',
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 380 ? 12.0 : 20.0;
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              const BrandBanner(
                title: 'Learn. Speak. Master.',
                subtitle: 'Pink + blue vocabulary hub',
                height: 150,
              ),
              const SizedBox(height: 16),
              _hero(),
              const SizedBox(height: 20),
              _stats(),
              const SizedBox(height: 16),
              _performanceCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
          const SizedBox(height: 16),
          const Text('AI Vocabulary Hub',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            '${words.length} words • GMAT • IELTS • Academic • Contemporary English',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text('Data source: $dataSource',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.blue),
              onPressed: onTest,
              icon: const Icon(Icons.quiz, color: AppColors.pink),
              label: const Text('Start Vocabulary Test',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    final advanced = words
        .where((e) =>
    e.difficultCefrStyle.toUpperCase() == 'C1' ||
        e.difficultCefrStyle.toUpperCase() == 'C2')
        .length;
    final gmat =
        words.where((e) => e.gmatRelevance.toLowerCase() == 'high').length;
    final ielts =
        words.where((e) => e.ieltsRelevance.toLowerCase() == 'high').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width < 700 ? (width - 12) / 2 : 180.0;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _statCard('Total Words', '${words.length}', Icons.menu_book,
                cardWidth, AppColors.blue),
            _statCard('Advanced', '$advanced', Icons.trending_up, cardWidth,
                AppColors.pink),
            _statCard(
                'GMAT High', '$gmat', Icons.school, cardWidth, AppColors.blue),
            _statCard('IELTS High', '$ielts', Icons.language, cardWidth,
                AppColors.pink),
          ],
        );
      },
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, double width, Color color) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _performanceCard() {
    final m = mastery.clamp(0.0, 100.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 330) {
              return Column(children: [
                _masteryCircle(m),
                const SizedBox(height: 16),
                _performanceText(),
              ]);
            }
            return Row(children: [
              _masteryCircle(m),
              const SizedBox(width: 16),
              Expanded(child: _performanceText()),
            ]);
          },
        ),
      ),
    );
  }

  Widget _masteryCircle(double m) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
              value: m / 100, strokeWidth: 7, color: AppColors.pink),
          Center(
            child: Text('${m.round()}%',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _performanceText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Student Performance ML',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text('$trainingSamples training samples',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        const Text('Open the ML Training tab to train the model',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

// ============================================================
// TEST LAUNCHER
// ============================================================

class TestLauncher extends StatelessWidget {
  final List<VocabularyWord> words;
  final Function(AssessmentRecord) onCompleted;

  const TestLauncher(
      {super.key, required this.words, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Assessment')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    const Icon(Icons.assignment,
                        size: 70, color: AppColors.pink),
                    const SizedBox(height: 20),
                    const Text('AI Vocabulary Test',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text('${min(words.length, 10)} questions • 10 minutes',
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 25),
                    const Text('Question types',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('• Definition recognition\n'
                        '• Meaning recognition\n'
                        '• Context questions\n'
                        '• Synonym questions\n'
                        '• Adaptive difficulty\n'
                        '• Response-time analysis'),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                      onPressed: words.length < 4
                          ? null
                          : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TestPage(
                              words: words, onCompleted: onCompleted),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('BEGIN TEST')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TEST PAGE
// ============================================================

class TestPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final Function(AssessmentRecord) onCompleted;

  const TestPage({super.key, required this.words, required this.onCompleted});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final Random random = Random();
  late List<TestQuestion> questions;
  final Map<int, String> answers = {};
  final Map<int, int> questionTimes = {};

  int currentIndex = 0;
  int remainingSeconds = 600;
  int questionStartedAt = 0;
  bool submitted = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    questions = _generateQuestions();
    questionStartedAt = DateTime.now().millisecondsSinceEpoch;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) _submit();
    });
  }

  List<TestQuestion> _generateQuestions() {
    final pool = List<VocabularyWord>.from(widget.words)..shuffle(random);
    final selected = pool.take(min(10, pool.length)).toList();
    final result = <TestQuestion>[];

    for (final word in selected) {
      final type =
      QuestionType.values[random.nextInt(QuestionType.values.length)];
      List<String> options;
      String correct;

      switch (type) {
        case QuestionType.definition:
          options = _makeOptions(word, (w) => w.word);
          correct = word.word;
        case QuestionType.meaning:
          options = _makeOptions(word, (w) => w.meaning);
          correct = word.meaning;
        case QuestionType.example:
          options = _makeOptions(word, (w) => w.word);
          correct = word.word;
        case QuestionType.synonym:
          String pick(VocabularyWord w) =>
              w.synonyms.isNotEmpty ? w.synonyms.first : w.word;
          options = _makeOptions(word, pick);
          correct = pick(word);
      }

      result.add(TestQuestion(
          word: word, type: type, options: options, correctAnswer: correct));
    }
    return result;
  }

  List<String> _makeOptions(
      VocabularyWord correct, String Function(VocabularyWord) selector) {
    final candidates =
    widget.words.where((w) => w.word != correct.word).toList()
      ..shuffle(random);
    final values = <String>[selector(correct)];
    for (final candidate in candidates) {
      final value = selector(candidate);
      if (value.trim().isEmpty) continue;
      if (!values.contains(value)) values.add(value);
      if (values.length >= 4) break;
    }
    while (values.length < 4) {
      values.add('Not enough information ${values.length}');
    }
    values.shuffle(random);
    return values;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _select(String answer) {
    final elapsed =
    ((DateTime.now().millisecondsSinceEpoch - questionStartedAt) / 1000)
        .round();
    answers[currentIndex] = answer;
    questionTimes[currentIndex] = elapsed;

    if (currentIndex == questions.length - 1) {
      _submit();
    } else {
      setState(() {
        currentIndex++;
        questionStartedAt = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  void _submit() {
    if (submitted) return;
    submitted = true;
    timer?.cancel();
    final results = <TestAnswer>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final selected = answers[i] ?? 'Not answered';
      results.add(TestAnswer(
        question: q,
        selectedAnswer: selected,
        correct: selected == q.correctAnswer,
        seconds: questionTimes[i] ?? 0,
      ));
    }

    final score = results.where((e) => e.correct).length;
    final averageTime = results.isEmpty
        ? 0
        : results.map((e) => e.seconds).reduce((a, b) => a + b) /
        results.length;
    final percentage = questions.isEmpty ? 0 : score / questions.length * 100;

    final record = AssessmentRecord(
      date: DateTime.now(),
      score: score,
      total: questions.length,
      averageTime: averageTime.toDouble(),
      voiceScore: 0,
      level: _level(percentage),
    );

    widget.onCompleted(record);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => ResultsPage(results: results, record: record)),
    );
  }

  String _level(num percentage) {
    if (percentage >= 90) return 'Advanced';
    if (percentage >= 75) return 'Upper Intermediate';
    if (percentage >= 60) return 'Intermediate';
    if (percentage >= 40) return 'Developing';
    return 'Foundation';
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Not enough vocabulary entries.')));
    }

    final question = questions[currentIndex];
    final minutes =
    (max(0, remainingSeconds) ~/ 60).toString().padLeft(2, '0');
    final seconds =
    (max(0, remainingSeconds) % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${currentIndex + 1}/${questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Chip(
                avatar: const Icon(Icons.timer, size: 18),
                label: Text('$minutes:$seconds')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LinearProgressIndicator(
              value: (currentIndex + 1) / questions.length),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.type.name.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.pink, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(question.questionText,
                      style: const TextStyle(fontSize: 19, height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...question.options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _optionButton(option),
          )),
        ],
      ),
    );
  }

  Widget _optionButton(String option) {
    return OutlinedButton(
      onPressed: () => _select(option),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(18),
        minimumSize: const Size(double.infinity, 60),
        foregroundColor: AppColors.text,
      ),
      child: Text(option, style: const TextStyle(fontSize: 15)),
    );
  }
}

// ============================================================
// RESULTS
// ============================================================

class ResultsPage extends StatelessWidget {
  final List<TestAnswer> results;
  final AssessmentRecord record;

  const ResultsPage({super.key, required this.results, required this.record});

  double get accuracy => record.percentage;

  double get mastery {
    final speedFactor = record.averageTime <= 8
        ? 10
        : record.averageTime <= 15
        ? 5
        : -5;
    return max(0, min(100, accuracy + speedFactor)).toDouble();
  }

  String get feedback {
    if (accuracy >= 90) {
      return 'Excellent vocabulary mastery. Continue with advanced and context-heavy questions.';
    }
    if (accuracy >= 75) {
      return 'Strong performance. Focus on subtle meanings, synonyms and contextual usage.';
    }
    if (accuracy >= 60) {
      return 'Developing proficiency. Review incorrect answers and practise active recall.';
    }
    return 'Build your foundation by reviewing definitions, meanings and examples before retesting.';
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = results.where((e) => !e.correct).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Results')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _scoreCard(),
          const SizedBox(height: 20),
          _analytics(),
          const SizedBox(height: 20),
          _feedbackCard(),
          const SizedBox(height: 20),
          Text('Mistake Analysis',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (mistakes.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No mistakes. Excellent!')))
          else
            ...mistakes.map(_mistakeCard),
          const SizedBox(height: 20),
          Text('Question Review',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...results.map(_reviewCard),
        ],
      ),
    );
  }

  Widget _scoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Text('YOUR SCORE',
                style: TextStyle(color: AppColors.muted, letterSpacing: 2)),
            const SizedBox(height: 10),
            Text('${record.score}/${record.total}',
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.bold)),
            Text('${accuracy.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 24, color: AppColors.pink)),
            const SizedBox(height: 12),
            Chip(label: Text(record.level)),
          ],
        ),
      ),
    );
  }

  Widget _analytics() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _metric('Accuracy', '${accuracy.toStringAsFixed(1)}%', Icons.percent,
            AppColors.blue),
        _metric('Avg Time', '${record.averageTime.toStringAsFixed(1)} sec',
            Icons.timer, AppColors.pink),
        _metric('AI Mastery', '${mastery.toStringAsFixed(1)}%',
            Icons.auto_awesome, AppColors.blue),
        _metric('Mistakes', '${results.where((e) => !e.correct).length}',
            Icons.error_outline, AppColors.pink),
      ],
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedbackCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.smart_toy, color: AppColors.pink),
            const SizedBox(width: 12),
            Expanded(
                child: Text(feedback, style: const TextStyle(height: 1.5))),
          ],
        ),
      ),
    );
  }

  Widget _mistakeCard(TestAnswer answer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer.question.word.word,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your answer: ${answer.selectedAnswer}',
                style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 5),
            Text('Correct answer: ${answer.question.correctAnswer}',
                style: TextStyle(color: Colors.green.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard(TestAnswer answer) {
    return Card(
      child: ExpansionTile(
        title: Text(answer.question.word.word),
        subtitle: Text(answer.correct
            ? 'Correct • ${answer.seconds}s'
            : 'Incorrect • ${answer.seconds}s'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(answer.question.word.definition),
                const SizedBox(height: 10),
                Text(answer.question.word.example),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VOICE TUTOR
// ============================================================

class VoiceTutorPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final Future<void> Function(AssessmentRecord) onCompleted;

  const VoiceTutorPage(
      {super.key, required this.words, required this.onCompleted});

  @override
  State<VoiceTutorPage> createState() => _VoiceTutorPageState();
}

class _VoiceTutorPageState extends State<VoiceTutorPage> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  final Random random = Random();

  VocabularyWord? currentWord;
  bool speechAvailable = false;
  bool listening = false;
  String transcript = '';
  double recognitionConfidence = 0;
  int speakingSeconds = 0;
  Timer? speakingTimer;
  int voiceScore = 0;
  double wordMatch = 0;
  double similarity = 0;
  String tutorFeedback =
      'Press the speaker button to hear the word, then say it aloud.';

  @override
  void initState() {
    super.initState();
    if (widget.words.isNotEmpty) {
      currentWord = widget.words[random.nextInt(widget.words.length)];
    }
    _initializeVoice();
    _initializeTts();
  }

  Future<void> _initializeVoice() async {
    try {
      speechAvailable = await speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' && listening) _finishListening();
        },
        onError: (error) {
          if (mounted) {
            setState(() =>
            tutorFeedback = 'Speech recognition error: ${error.errorMsg}');
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() =>
        tutorFeedback = 'Unable to initialise speech recognition.');
      }
    }
  }

  Future<void> _initializeTts() async {
    try {
      // Android: use Google's TTS engine (much clearer than the OEM default)
      if (!kIsWeb && Platform.isAndroid) {
        final engines = await tts.getEngines;
        if (engines is List && engines.contains('com.google.android.tts')) {
          await tts.setEngine('com.google.android.tts');
        }
      }

      // iOS: play through the speaker at full quality
      if (!kIsWeb && Platform.isIOS) {
        await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker],
        );
      }

      await tts.setLanguage('en-US');

      // Pick the best-sounding en-US voice available on this device
      final voices = await tts.getVoices;
      if (voices is List) {
        final enVoices = voices
            .whereType<Map>()
            .where((v) =>
        '${v['locale']}'.toLowerCase().replaceAll('_', '-') == 'en-us')
            .toList();

        Map? best;
        // Prefer network / neural / enhanced voices
        for (final key in [
          'network',
          'neural',
          'enhanced',
          'premium',
          'wavenet'
        ]) {
          best = enVoices.cast<Map?>().firstWhere(
                (v) => '${v!['name']}'.toLowerCase().contains(key),
            orElse: () => null,
          );
          if (best != null) break;
        }
        best ??= enVoices.isNotEmpty ? enVoices.first : null;

        if (best != null) {
          await tts.setVoice({
            'name': '${best['name']}',
            'locale': '${best['locale']}',
          });
        }
      }
    } catch (_) {}

    await tts.setSpeechRate(.42); // slower = clearer for learners
    await tts.setPitch(1.1); // slightly higher removes the "husky" low tone
    await tts.setVolume(1.0);
    await tts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  Future<void> _speakWord() async {
    if (currentWord == null) return;
    await _speak(currentWord!.word);
  }

  Future<void> _speakLesson() async {
    if (currentWord == null) return;
    final w = currentWord!;
    await _speak(
        '${w.word}. ${w.definition}. Meaning: ${w.meaning}. Example: ${w.example}.');
  }

  Future<void> _startListening() async {
    if (!speechAvailable) await _initializeVoice();
    if (!speechAvailable) {
      setState(() => tutorFeedback =
      'Speech recognition is not available on this device.');
      return;
    }

    transcript = '';
    recognitionConfidence = 0;
    voiceScore = 0;
    wordMatch = 0;
    similarity = 0;
    speakingSeconds = 0;

    speakingTimer?.cancel();
    speakingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && listening) setState(() => speakingSeconds++);
    });

    setState(() {
      listening = true;
      tutorFeedback = 'Listening... say the word clearly.';
    });

    await speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          transcript = result.recognizedWords;
          recognitionConfidence = result.confidence;
        });
        if (result.finalResult) _finishListening();
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  Future<void> _finishListening() async {
    if (!listening) return;
    speakingTimer?.cancel();
    await speech.stop();
    if (!mounted) return;
    setState(() => listening = false);
    _calculateVoiceScore();
  }

  void _calculateVoiceScore() {
    if (currentWord == null) return;
    final target = _normalize(currentWord!.word);
    final spoken = _normalize(transcript);

    if (spoken.isEmpty) {
      setState(() {
        voiceScore = 0;
        tutorFeedback = 'No speech was detected. Please try again.';
      });
      return;
    }

    final targetWords = target.split(' ');
    final spokenWords = spoken.split(' ');
    int matches = 0;
    for (final w in targetWords) {
      if (spokenWords.contains(w)) matches++;
    }

    wordMatch = targetWords.isEmpty ? 0 : matches / targetWords.length * 100;
    similarity = _stringSimilarity(target, spoken);
    final confidenceScore =
    recognitionConfidence > 0 ? recognitionConfidence * 100 : 50;

    voiceScore =
        ((wordMatch * .55) + (similarity * .25) + (confidenceScore * .20))
            .round();
    voiceScore = max(0, min(100, voiceScore));

    if (voiceScore >= 90) {
      tutorFeedback =
      'Excellent pronunciation recognition. Your response closely matched the target.';
    } else if (voiceScore >= 75) {
      tutorFeedback =
      'Good attempt. Repeat the word once more for greater consistency.';
    } else if (voiceScore >= 60) {
      tutorFeedback = 'Developing. Speak more slowly and clearly, then repeat.';
    } else {
      tutorFeedback =
      'Keep practising. Listen to the model pronunciation and try again.';
    }

    setState(() {});
    _saveVoiceAssessment();
  }

  Future<void> _saveVoiceAssessment() async {
    final seconds = max(1, speakingSeconds);
    final level = voiceScore >= 90
        ? 'Excellent'
        : voiceScore >= 75
        ? 'Good'
        : voiceScore >= 60
        ? 'Developing'
        : 'Needs Practice';
    await widget.onCompleted(AssessmentRecord(
      date: DateTime.now(),
      score: voiceScore,
      total: 100,
      averageTime: seconds.toDouble(),
      voiceScore: voiceScore,
      level: level,
    ));
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _stringSimilarity(String a, String b) {
    if (a == b) return 100;
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a, b);
    return (1 - distance / max(a.length, b.length)) * 100;
  }

  int _levenshtein(String a, String b) {
    final m =
    List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) {
      m[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      m[0][j] = j;
    }
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        m[i][j] = min(
            min(m[i - 1][j] + 1, m[i][j - 1] + 1), m[i - 1][j - 1] + cost);
      }
    }
    return m[a.length][b.length];
  }

  void _nextWord() {
    if (widget.words.isEmpty) return;
    setState(() {
      currentWord = widget.words[random.nextInt(widget.words.length)];
      transcript = '';
      voiceScore = 0;
      wordMatch = 0;
      similarity = 0;
      recognitionConfidence = 0;
      tutorFeedback = 'New word selected. Listen first, then speak.';
    });
  }

  @override
  void dispose() {
    speakingTimer?.cancel();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = currentWord;
    if (word == null) {
      return const Scaffold(
          body: Center(child: Text('No vocabulary available.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Tutor'),
        actions: [
          IconButton(
              tooltip: 'New Word',
              onPressed: _nextWord,
              icon: const Icon(Icons.shuffle)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _wordHero(word),
          const SizedBox(height: 16),
          _voiceControls(),
          const SizedBox(height: 16),
          _transcriptCard(),
          const SizedBox(height: 16),
          _scoreCard(),
          const SizedBox(height: 16),
          _detailsCard(word),
        ],
      ),
    );
  }

  Widget _wordHero(VocabularyWord word) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            const Text('SAY THIS WORD',
                style: TextStyle(color: AppColors.muted, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text(word.word,
                style:
                const TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Chip(label: Text(word.difficultCefrStyle)),
                Chip(label: Text(word.difficulty)),
                Chip(label: Text(word.partsOfSpeech)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _voiceControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _speakWord,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Hear Word'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _speakLesson,
                    icon: const Icon(Icons.record_voice_over,
                        color: AppColors.pink),
                    label: const Text('AI Lesson'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor:
                    listening ? AppColors.pink : AppColors.blue),
                onPressed: listening ? _finishListening : _startListening,
                icon: Icon(listening ? Icons.stop : Icons.mic),
                label: Text(listening ? 'STOP LISTENING' : 'START SPEAKING'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcriptCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Speech Recognition',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
                transcript.isEmpty
                    ? 'Your spoken response will appear here...'
                    : transcript,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text('Speaking time: ${speakingSeconds}s',
                style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('VOICE SCORE',
                style: TextStyle(letterSpacing: 2, color: AppColors.muted)),
            const SizedBox(height: 10),
            Text('$voiceScore',
                style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: AppColors.pink)),
            const Text('/ 100', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            _scoreBar('Word Match', wordMatch),
            _scoreBar('Recognition Confidence', recognitionConfidence * 100),
            _scoreBar('Text Similarity', similarity),
            const SizedBox(height: 14),
            Text(tutorFeedback,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(String title, double value) {
    final safe = value.clamp(0.0, 100.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title)),
            Text('${safe.toStringAsFixed(0)}%'),
          ]),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: safe / 100),
        ],
      ),
    );
  }

  Widget _detailsCard(VocabularyWord word) {
    return Card(
      child: ExpansionTile(
        title: const Text('Vocabulary Information'),
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word.definition),
                const SizedBox(height: 10),
                Text(word.meaning),
                const SizedBox(height: 10),
                Text('Example: ${word.example}'),
                const SizedBox(height: 10),
                Text('Synonyms: ${word.synonyms.join(', ')}'),
                const SizedBox(height: 10),
                Text('Usage: ${word.usage}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN (Firebase Auth)
// ============================================================

/// Shows LoginPage until a Firebase user is signed in, then shows [child].
class AuthGate extends StatelessWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginPage() : child;
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _hidePassword = true;
  bool _loading = false;
  String? _error;

  // Client-side brute-force throttle (Firebase also rate-limits server side).
  int _failures = 0;
  DateTime? _lockedUntil;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final s = _lockedUntil!.difference(DateTime.now()).inSeconds;
      setState(() => _error = 'Too many attempts. Try again in ${s}s.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      if (_register) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: email, password: _password.text);
        await cred.user?.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(
            email: email, password: _password.text);
      }
      _failures = 0;
    } on FirebaseAuthException catch (e) {
      _failures++;
      if (_failures >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _failures = 0;
      }
      setState(() => _error = _message(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {}
    if (!mounted) return;
    // Same message either way, so accounts can't be enumerated.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('If that account exists, a reset email was sent.')));
  }

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  String _message(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 56, color: AppColors.pink),
                        const SizedBox(height: 12),
                        Text(_register ? 'Create account' : 'Welcome back',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: AppColors.blue),
                              border: OutlineInputBorder()),
                          validator: (v) => _validEmail((v ?? '').trim())
                              ? null
                              : 'Enter a valid email',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon:
                            const Icon(Icons.key, color: AppColors.pink),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword),
                            ),
                          ),
                          validator: (v) {
                            final p = v ?? '';
                            if (p.length < 8) return 'Minimum 8 characters';
                            if (_register &&
                                !(RegExp(r'[A-Za-z]').hasMatch(p) &&
                                    RegExp(r'\d').hasMatch(p))) {
                              return 'Use letters and numbers';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: TextStyle(color: Colors.red.shade700)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                                : Text(_register ? 'SIGN UP' : 'SIGN IN'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                          child: Text(_register
                              ? 'Have an account? Sign in'
                              : 'New here? Create account'),
                        ),
                        if (!_register)
                          TextButton(
                              onPressed: _resetPassword,
                              child: const Text('Forgot password?')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// NOTES
// ============================================================

/// Separate "Notes" section: searchable, expandable list of all words.
class NotesPage extends StatefulWidget {
  final List<VocabularyWord> words;
  const NotesPage({super.key, required this.words});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String search = '';
  String letter = 'All';

  List<VocabularyWord> get filtered {
    final q = search.toLowerCase().trim();
    final list = widget.words.where((w) {
      final okLetter = letter == 'All' || w.letter.toUpperCase() == letter;
      final okSearch = q.isEmpty ||
          w.word.toLowerCase().contains(q) ||
          w.meaning.toLowerCase().contains(q) ||
          w.synonyms.any((s) => s.toLowerCase().contains(q));
      return okLetter && okSearch;
    }).toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.words
        .map((e) => e.letter.toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final items = filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search, color: AppColors.pink),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final l in ['All', ...letters])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(l),
                      selected: letter == l,
                      onSelected: (_) => setState(() => letter = l),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${items.length} words',
                  style: const TextStyle(color: AppColors.muted)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final w = items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ExpansionTile(
                      title: Text(w.word,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${w.partsOfSpeech} • ${w.difficultCefrStyle}',
                          style: const TextStyle(color: AppColors.muted)),
                      childrenPadding: const EdgeInsets.all(16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('Definition', w.definition),
                        _row('Meaning', w.meaning),
                        _row('Synonyms', w.synonyms.join(', ')),
                        _row('Example', w.example),
                        _row('Usage', w.usage),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.pink, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

// ============================================================
// ML TRAINING TAB  (model machine training + ETL monitor)
// ============================================================

class MLTrainingPage extends StatefulWidget {
  final StudentPerformanceML model;
  final EtlReport? wordReport;
  final Future<void> Function() onRefreshWords;
  final Future<void> Function() onModelChanged;

  const MLTrainingPage({
    super.key,
    required this.model,
    required this.wordReport,
    required this.onRefreshWords,
    required this.onModelChanged,
  });

  @override
  State<MLTrainingPage> createState() => _MLTrainingPageState();
}

class _EtlStage {
  final String label;
  final IconData icon;
  final String detail;
  const _EtlStage(this.label, this.icon, this.detail);
}

class _MLTrainingPageState extends State<MLTrainingPage> {
  List<PerformanceSample> samples = [];
  bool loadingSamples = true;

  double epochs = 60;
  double learningRate = .08;
  bool useSynthetic = false;

  bool training = false;
  int doneEpochs = 0;
  TrainingResult? result;

  EtlReport? datasetReport;
  bool etlBusy = false;

  // Prediction playground
  double pAccuracy = 70;
  double pTime = 10;
  double pVoice = 60;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    final s = await StudentStorage.loadPerformanceSamples();
    if (!mounted) return;
    setState(() {
      samples = s;
      loadingSamples = false;
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<PerformanceSample> _synthetic(int n) {
    final rnd = Random();
    return List.generate(n, (_) {
      final a = rnd.nextDouble();
      final s = rnd.nextDouble();
      final v = rnd.nextDouble();
      final t = (a * .65 + s * .15 + v * .20 + (rnd.nextDouble() - .5) * .05)
          .clamp(0.0, 1.0)
          .toDouble();
      return PerformanceSample(
          accuracy: a, speed: s, voiceScore: v, target: t);
    });
  }

  Future<void> _train() async {
    final data = List<PerformanceSample>.from(samples);
    if (useSynthetic) data.addAll(_synthetic(200));
    if (data.length < 3) {
      _toast('Need at least 3 samples. Take a test or enable synthetic data.');
      return;
    }
    setState(() {
      training = true;
      doneEpochs = 0;
      result = null;
    });
    try {
      final r = await widget.model.fit(
        data,
        epochs: epochs.round(),
        learningRate: learningRate,
        onEpoch: (e, res) {
          if (mounted) {
            setState(() {
              doneEpochs = e;
              result = res;
            });
          }
        },
      );
      await StudentStorage.saveModel(widget.model);
      await widget.onModelChanged();
      unawaited(ModelRegistry.registerLive(widget.model, r, data.length)); // <-- STUDIO
      if (!mounted) return;
      setState(() => result = r);
      _toast('Training complete. Model saved.');
    } catch (e) {
      _toast('Training failed: $e');
    } finally {
      if (mounted) setState(() => training = false);
    }
  }

  Future<void> _resetModel() async {
    widget.model.reset();
    await StudentStorage.saveModel(widget.model);
    await widget.onModelChanged();
    if (!mounted) return;
    setState(() => result = null);
    _toast('Model reset to default weights.');
  }

  Future<void> _rebuildDataset() async {
    setState(() => etlBusy = true);
    try {
      final r = await DatasetEtl.rebuildFromHistory();
      await _loadSamples();
      await widget.onModelChanged();
      if (!mounted) return;
      setState(() => datasetReport = r);
      _toast('Dataset rebuilt: ${r.loaded} samples loaded.');
    } catch (e) {
      _toast('ETL failed: $e');
    } finally {
      if (mounted) setState(() => etlBusy = false);
    }
  }

  Future<void> _reloadWords() async {
    setState(() => etlBusy = true);
    try {
      await widget.onRefreshWords();
    } finally {
      if (mounted) setState(() => etlBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Training'),
        actions: [
          IconButton(
              tooltip: 'Sign out',
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: loadingSamples
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(m),
          const SizedBox(height: 14),
          _weightsCard(m),
          const SizedBox(height: 14),
          _controlsCard(),
          const SizedBox(height: 14),
          _lossCard(),
          const SizedBox(height: 14),
          _playgroundCard(m),
          const SizedBox(height: 14),
          _etlCard(),
        ],
      ),
    );
  }

  // ---- header ----
  Widget _header(StudentPerformanceML m) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
            colors: [AppColors.blue, AppColors.pink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.psychology, color: Colors.white, size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text('Model Machine Training',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Logistic-regression mastery model • 3 features: accuracy, speed, voice',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('${m.trainingSteps} steps'),
            _pill('${samples.length} real samples'),
            _pill('Local on-device'),
          ]),
        ],
      ),
    );
  }

  Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t,
        style: const TextStyle(color: Colors.white, fontSize: 12)),
  );

  // ---- weights ----
  Widget _weightsCard(StudentPerformanceML m) {
    Widget row(String name, double v, IconData icon, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(name)),
        Text(v.toStringAsFixed(4),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Learned weights',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            row('Bias', m.bias, Icons.tune, AppColors.blue),
            row('Accuracy weight', m.accuracyWeight, Icons.percent,
                AppColors.pink),
            row('Speed weight', m.speedWeight, Icons.speed, AppColors.blue),
            row('Voice weight', m.voiceWeight, Icons.mic, AppColors.pink),
          ],
        ),
      ),
    );
  }

  // ---- controls ----
  Widget _controlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Train model',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Epochs: ${epochs.round()}'),
            Slider(
              value: epochs,
              min: 10,
              max: 200,
              divisions: 19,
              onChanged: training ? null : (v) => setState(() => epochs = v),
            ),
            Text('Learning rate: ${learningRate.toStringAsFixed(3)}'),
            Slider(
              value: learningRate,
              min: .005,
              max: .3,
              onChanged:
              training ? null : (v) => setState(() => learningRate = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add 200 synthetic samples'),
              subtitle: const Text(
                  'Helps when you have few real assessments',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              value: useSynthetic,
              onChanged:
              training ? null : (v) => setState(() => useSynthetic = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: training ? null : _train,
                icon: const Icon(Icons.model_training),
                label: Text(training
                    ? 'Training... $doneEpochs/${epochs.round()}'
                    : 'TRAIN MODEL'),
              ),
            ),
            if (training) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: doneEpochs / epochs.round()),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: training ? null : _resetModel,
                icon: const Icon(Icons.restart_alt, color: AppColors.pink),
                label: const Text('Reset model'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- loss chart ----
  Widget _lossCard() {
    final r = result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Training curve (MSE loss)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: const [
              Icon(Icons.circle, size: 10, color: AppColors.blue),
              SizedBox(width: 6),
              Text('Train', style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, size: 10, color: AppColors.pink),
              SizedBox(width: 6),
              Text('Validation', style: TextStyle(fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              width: double.infinity,
              child: r == null || r.trainLoss.isEmpty
                  ? const Center(
                  child: Text('Train the model to see the loss curve.',
                      style: TextStyle(color: AppColors.muted)))
                  : CustomPaint(
                  painter: LossPainter(r.trainLoss, r.valLoss)),
            ),
            if (r != null && r.trainLoss.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip(label: Text('Epochs ${r.epochs}')),
                Chip(label: Text('Train MSE ${r.finalTrain.toStringAsFixed(5)}')),
                Chip(label: Text('Val MSE ${r.finalVal.toStringAsFixed(5)}')),
                Chip(label: Text('${r.trainSize} train / ${r.valSize} val')),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ---- prediction playground ----
  Widget _playgroundCard(StudentPerformanceML m) {
    final p = m.predict(
        accuracy: pAccuracy, averageTime: pTime, voiceScore: pVoice);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Try the model',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Accuracy: ${pAccuracy.round()}%'),
            Slider(
                value: pAccuracy,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => pAccuracy = v)),
            Text('Average time per question: ${pTime.toStringAsFixed(0)}s'),
            Slider(
                value: pTime,
                min: 1,
                max: 60,
                onChanged: (v) => setState(() => pTime = v)),
            Text('Voice score: ${pVoice.round()}'),
            Slider(
                value: pVoice,
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => pVoice = v)),
            const SizedBox(height: 6),
            Center(
              child: Text('Predicted mastery: ${p.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pink)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- ETL ----
  Widget _etlCard() {
    final w = widget.wordReport;
    final d = datasetReport;

    final wordStages = w == null
        ? const [
      _EtlStage('Extract', Icons.cloud_download, 'not run yet'),
      _EtlStage('Transform', Icons.auto_fix_high, 'not run yet'),
      _EtlStage('Load', Icons.save_alt, 'not run yet'),
    ]
        : [
      _EtlStage('Extract', Icons.cloud_download,
          '${w.extracted} records from ${w.source}'),
      _EtlStage('Transform', Icons.auto_fix_high,
          '${w.rejected} rejected, ${w.duplicates} duplicates, text cleaned'),
      _EtlStage('Load', Icons.save_alt,
          '${w.loaded} words to app + offline cache'),
    ];

    final dataStages = d == null
        ? [
      _EtlStage('Extract', Icons.history,
          '${samples.length} samples stored'),
      const _EtlStage(
          'Transform', Icons.auto_fix_high, 'run to rebuild'),
      const _EtlStage('Load', Icons.save_alt, 'run to rebuild'),
    ]
        : [
      _EtlStage('Extract', Icons.history,
          '${d.extracted} assessments from history'),
      _EtlStage('Transform', Icons.auto_fix_high,
          '${d.rejected} rejected, ${d.duplicates} duplicates, features scaled 0-1'),
      _EtlStage('Load', Icons.save_alt,
          '${d.loaded} training samples stored'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ETL pipelines',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            const Text('1. Vocabulary data',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.blue)),
            const SizedBox(height: 8),
            _pipelineRow(wordStages),
            if (w != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Last run ${w.milliseconds} ms',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: etlBusy ? null : _reloadWords,
                icon: const Icon(Icons.sync, color: AppColors.pink),
                label: const Text('Run vocabulary ETL'),
              ),
            ),
            const Divider(height: 28),
            const Text('2. Student training dataset',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.pink)),
            const SizedBox(height: 8),
            _pipelineRow(dataStages),
            if (d != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Last run ${d.milliseconds} ms',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: etlBusy ? null : _rebuildDataset,
                icon: const Icon(Icons.storage, color: AppColors.blue),
                label: const Text('Rebuild dataset from history'),
              ),
            ),
            if (etlBusy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pipelineRow(List<_EtlStage> stages) {
    final children = <Widget>[];
    for (int i = 0; i < stages.length; i++) {
      final s = stages[i];
      final color = i.isEven ? AppColors.blue : AppColors.pink;
      children.add(Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: i.isEven ? AppColors.softBlue : AppColors.softPink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(s.icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(s.label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: color)),
              const SizedBox(height: 4),
              Text(s.detail,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, height: 1.3)),
            ],
          ),
        ),
      ));
      if (i < stages.length - 1) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_right, size: 18, color: AppColors.pink),
        ));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class LossPainter extends CustomPainter {
  final List<double> train;
  final List<double> val;
  LossPainter(this.train, this.val);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (train.isEmpty) return;

    final all = [...train, ...val];
    final maxV = all.reduce(max);
    final top = maxV <= 0 ? 1.0 : maxV;

    void line(List<double> d, Color c) {
      if (d.length < 2) return;
      final path = Path();
      for (int i = 0; i < d.length; i++) {
        final x = size.width * i / (d.length - 1);
        final y = size.height * (1 - d[i] / top);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round);
    }

    line(train, AppColors.blue);
    line(val, AppColors.pink);
  }

  @override
  bool shouldRepaint(covariant LossPainter old) => true;
}

// ============================================================
// SCORES: PDF / GOOGLE DRIVE (share sheet) / EMAIL (Gmail compose)
// ============================================================

class ReportService {
  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Future<Uint8List> buildPdf(
      List<AssessmentRecord> history, String student) async {
    final doc = pw.Document();
    final avg = history.isEmpty
        ? 0.0
        : history.map((e) => e.percentage).reduce((a, b) => a + b) /
        history.length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('Vocabulary Assessment Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Student: $student'),
        pw.Text('Generated: ${_d(DateTime.now())}'),
        pw.Text('Assessments: ${history.length}   '
            'Average: ${avg.toStringAsFixed(1)}%'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Score', '%', 'Avg time (s)', 'Voice', 'Level'],
          data: [
            for (final r in history)
              [
                _d(r.date),
                '${r.score}/${r.total}',
                r.percentage.toStringAsFixed(1),
                r.averageTime.toStringAsFixed(1),
                '${r.voiceScore}',
                r.level,
              ]
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    return doc.save();
  }

  static String buildCsv(List<AssessmentRecord> history) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final rows = <String>[
      'Date,Score,Total,Percentage,AvgTimeSec,Voice,Level'
    ];
    for (final r in history) {
      rows.add([
        _d(r.date),
        r.score,
        r.total,
        r.percentage.toStringAsFixed(1),
        r.averageTime.toStringAsFixed(1),
        r.voiceScore,
        q(r.level),
      ].join(','));
    }
    return rows.join('\n');
  }

  static Future<String> _saveTemp(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> download(Uint8List pdf) =>
      Printing.sharePdf(bytes: pdf, filename: 'vocabulary_report.pdf');

  /// Opens the system share pop-up with the score sheet; choose "Drive"
  /// and pick the account to upload to.
  static Future<void> uploadToDrive(List<AssessmentRecord> history) async {
    final path = await _saveTemp(
        'Vocabulary_Assessment_Scores.csv', utf8.encode(buildCsv(history)));
    await Share.shareXFiles(
      [XFile(path, mimeType: 'text/csv')],
      subject: 'Vocabulary Assessment Scores',
    );
  }

  /// Opens the share pop-up with the PDF attached. Choose Gmail to get a
  /// compose window with the PDF attached and the subject filled in.
  /// The typed address is copied to the clipboard to paste into "To".
  static Future<void> emailPdf(String to, Uint8List pdf) async {
    if (to.contains(RegExp(r'[\r\n,;<>]'))) throw 'Invalid email address.';
    await Clipboard.setData(ClipboardData(text: to));
    final path = await _saveTemp('vocabulary_report.pdf', pdf);
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf')],
      subject: 'Vocabulary Assessment Report',
      text: 'Please find the vocabulary assessment report attached.\n\nTo: $to',
    );
  }
}

class ScoresPage extends StatefulWidget {
  final List<AssessmentRecord> history;
  const ScoresPage({super.key, required this.history});

  @override
  State<ScoresPage> createState() => _ScoresPageState();
}

class _ScoresPageState extends State<ScoresPage> {
  final _email = TextEditingController();
  bool _busy = false;

  String get _student => FirebaseAuth.instance.currentUser?.email ?? 'Student';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() task) async {
    if (widget.history.isEmpty) {
      _toast('No assessments to export yet.');
      return;
    }
    setState(() => _busy = true);
    try {
      final msg = await task();
      if (msg != null) _toast(msg);
    } catch (e) {
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _downloadPdf() => _run(() async {
    await ReportService.download(
        await ReportService.buildPdf(widget.history, _student));
    return null;
  });

  Future<void> _uploadSheet() => _run(() async {
    await ReportService.uploadToDrive(widget.history);
    return null;
  });

  Future<void> _sendEmail() {
    final to = _email.text.trim();
    if (!RegExp(r'^[^@\s,;<>]+@[^@\s,;<>]+\.[^@\s,;<>]+$').hasMatch(to)) {
      _toast('Enter a valid email address.');
      return Future.value();
    }
    return _run(() async {
      await ReportService.emailPdf(
          to, await ReportService.buildPdf(widget.history, _student));
      return '$to copied. Paste it in the To field if Gmail left it empty.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.history;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Scores'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in as $_student',
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _busy ? null : _downloadPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download PDF'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _uploadSheet,
                    icon: const Icon(Icons.cloud_upload, color: AppColors.pink),
                    label: const Text('Upload sheet to Google Drive'),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Send PDF to email',
                      prefixIcon:
                      Icon(Icons.email_outlined, color: AppColors.blue),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _sendEmail,
                    icon: const Icon(Icons.send, color: AppColors.pink),
                    label: const Text('Email PDF (choose Gmail)'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('${h.length} assessments',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final r in h)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: AppColors.softPink,
                      foregroundColor: AppColors.pink,
                      child: Text('${r.score}')),
                  title:
                  Text('${r.percentage.toStringAsFixed(1)}% • ${r.level}'),
                  subtitle: Text(
                      '${ReportService._d(r.date)} • Avg ${r.averageTime.toStringAsFixed(1)}s'),
                  trailing:
                  r.voiceScore > 0 ? Text('Voice ${r.voiceScore}') : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ============================================================================
// ============================================================================
//  PUSH NOTIFICATION MODULE  (Firebase Cloud Messaging + Firestore)
//  Sends the assessment report + analysis as a push notification.
//  Tap the notification -> opens NotificationReportScreen.
// ============================================================================
// ============================================================================

/// false (default): the app shows the notification itself right after the test,
///                  so everything works with NO server and NO paid plan.
/// true           : a Cloud Function sends a real FCM push (works even when the
///                  app is closed). Run with:  flutter run --dart-define=CLOUD_PUSH=true
const bool kSendViaCloudFunction = bool.fromEnvironment('CLOUD_PUSH');

/// Notifications work on Android and iOS only (not web / desktop).
bool get _pushSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Must be a top-level function. Runs when the app is in the background or closed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background push received: ${message.messageId}');
}

// ------------------------------------------------------------------
// Notification service: permission, token, foreground/background taps
// ------------------------------------------------------------------
class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static String? token;
  static bool _ready = false;
  static StreamSubscription<User?>? _authSub;

  /// Last report kept in memory so the report screen still opens
  /// when Firestore is unavailable.
  static Map<String, dynamic>? lastLocalReport;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'assessment_channel',
    'Assessment Reports',
    description: 'Assessment report and analysis notifications',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (!_pushSupported) return;

    // 1. Permission (Android 13+ and iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Local notifications (used for foreground + offline/local mode)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final id = resp.payload;
        if (id != null && id.isNotEmpty) _openReport(id);
      },
    );
    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_channel);
    await androidImpl?.requestNotificationsPermission();

    await _fcm.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);

    // 3. FCM token
    try {
      token = await _fcm.getToken();
      debugPrint('FCM TOKEN: $token');
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
    _fcm.onTokenRefresh.listen((t) {
      token = t;
      _saveToken();
    });

    // Save the token for whoever signs in (the user logs in AFTER app start)
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveToken();
    });

    // 4. Push received while the app is open (Android needs a local alert)
    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      final n = m.notification;
      if (n == null || !Platform.isAndroid) return; // iOS shows it natively
      _showLocal(
        title: n.title ?? 'Assessment report',
        body: n.body ?? '',
        payload: m.data['reportId'] ?? '',
      );
    });

    // 5. Tap while the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final id = m.data['reportId'];
      if (id != null && '$id'.isNotEmpty) _openReport('$id');
    });

    // 6. Tap while the app was closed
    final initial = await _fcm.getInitialMessage();
    final initialId = initial?.data['reportId'];
    if (initialId != null && '$initialId'.isNotEmpty) {
      Future.delayed(
          const Duration(seconds: 2), () => _openReport('$initialId'));
    }

    _ready = true;
  }

  /// Stores this device's token under users/{uid} so a server can find it.
  static Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final t = token;
    if (user == null || t == null) return;
    try {
      await fs.FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'fcmTokens': fs.FieldValue.arrayUnion([t]),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));
    } catch (e) {
      debugPrint('Token save failed (check Firestore rules): $e');
    }
  }

  static Future<void> _showLocal({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_ready && !_pushSupported) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Simple local notification used by Studio (registry, monitoring, workflow).
  static Future<void> notify(String title, String body) async {
    try {
      if (!_pushSupported || !_ready) return;
      await _showLocal(title: title, body: body, payload: '');
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }

  static void _openReport(String reportId) {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
          builder: (_) => NotificationReportScreen(reportId: reportId)),
    );
  }

  static Future<void> dispose() async => _authSub?.cancel();
}

// ------------------------------------------------------------------
// Builds the analysis, saves the report, triggers the notification
// ------------------------------------------------------------------
class AssessmentNotifier {
  /// Call this after every finished test / voice assessment.
  /// It never throws, so it can never break the existing app flow.
  static Future<void> publish(
      AssessmentRecord record, {
        required double mastery,
        AssessmentRecord? previous,
      }) async {
    if (!_pushSupported) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final report = _buildReport(record, mastery, previous, user?.email);
      NotificationService.lastLocalReport = report;
      unawaited(AuditLog.add('Report notification',
          '${record.score}/${record.total} (${record.level})')); // <-- STUDIO

      // 1. Save to Firestore (a Cloud Function can watch this collection)
      String reportId = 'local';
      try {
        final doc = await fs.FirebaseFirestore.instance
            .collection('assessment_reports')
            .add({
          ...report,
          'uid': user?.uid,
          'fcmToken': NotificationService.token,
          'createdAt': fs.FieldValue.serverTimestamp(),
        });
        reportId = doc.id;
      } catch (e) {
        debugPrint('Report not saved to Firestore: $e');
      }

      // 2. Local mode: show the notification right now
      if (!kSendViaCloudFunction) {
        await NotificationService._showLocal(
          title: report['title'] as String,
          body: report['body'] as String,
          payload: reportId,
        );
      }
    } catch (e) {
      debugPrint('Notification publish failed: $e');
    }
  }

  static Map<String, dynamic> _buildReport(AssessmentRecord r, double mastery,
      AssessmentRecord? previous, String? email) {
    final acc = r.percentage;
    final isVoice = r.voiceScore > 0 && r.total == 100;

    final speed = r.averageTime <= 8
        ? 'fast'
        : r.averageTime <= 15
        ? 'steady'
        : 'slow';

    String trend = 'First assessment recorded.';
    double? delta;
    if (previous != null) {
      delta = acc - previous.percentage;
      trend = delta > 0.5
          ? 'Up ${delta.toStringAsFixed(1)} points from last time.'
          : delta < -0.5
          ? 'Down ${(-delta).toStringAsFixed(1)} points from last time.'
          : 'Same as last time.';
    }

    final feedback = acc >= 90
        ? 'Excellent vocabulary mastery. Try advanced, context-heavy questions.'
        : acc >= 75
        ? 'Strong performance. Focus on subtle meanings and synonyms.'
        : acc >= 60
        ? 'Developing. Review incorrect answers and practise recall.'
        : 'Revisit definitions, meanings and examples, then retest.';

    final tips = <String>[
      if (acc < 75) 'Review the words you got wrong before the next test.',
      if (speed == 'slow') 'Answer faster: aim for under 15 seconds per question.',
      if (!isVoice && r.voiceScore == 0)
        'Try the Voice tab to improve pronunciation.',
      if (isVoice && r.voiceScore < 75)
        'Listen to the model pronunciation and repeat each word.',
      if (acc >= 90) 'Move on to harder GMAT / IELTS words.',
    ];

    final kind = isVoice ? 'Voice assessment' : 'Vocabulary test';
    return {
      'title': 'Assessment report ready',
      'body': '$kind: ${r.score}/${r.total} (${acc.toStringAsFixed(0)}%) '
          '• ${r.level}. $trend Predicted mastery ${mastery.toStringAsFixed(0)}%.',
      'kind': kind,
      'student': email ?? 'Student',
      'score': r.score,
      'total': r.total,
      'percentage': double.parse(acc.toStringAsFixed(1)),
      'level': r.level,
      'averageTime': double.parse(r.averageTime.toStringAsFixed(1)),
      'voiceScore': r.voiceScore,
      'mastery': double.parse(mastery.toStringAsFixed(1)),
      'speed': speed,
      'trend': trend,
      'trendDelta': delta == null ? null : double.parse(delta.toStringAsFixed(1)),
      'feedback': feedback,
      'recommendations': tips,
      'date': r.date.toIso8601String(),
    };
  }
}

// ------------------------------------------------------------------
// Screen opened when the notification is tapped
// ------------------------------------------------------------------
class NotificationReportScreen extends StatelessWidget {
  final String reportId;
  const NotificationReportScreen({super.key, required this.reportId});

  Future<Map<String, dynamic>?> _load() async {
    if (reportId == 'local' || reportId.isEmpty) {
      return NotificationService.lastLocalReport;
    }
    try {
      final snap = await fs.FirebaseFirestore.instance
          .collection('assessment_reports')
          .doc(reportId)
          .get();
      return snap.data() ?? NotificationService.lastLocalReport;
    } catch (_) {
      return NotificationService.lastLocalReport;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Report')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (d == null) {
            return const Center(child: Text('Report not found'));
          }
          final tips = List<String>.from(d['recommendations'] ?? const []);
          num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('${d['kind'] ?? 'Assessment'}',
                          style: const TextStyle(
                              color: AppColors.muted, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Text('${d['score']}/${d['total']}',
                          style: const TextStyle(
                              fontSize: 46, fontWeight: FontWeight.bold)),
                      Text('${d['percentage']}%',
                          style: const TextStyle(
                              fontSize: 22, color: AppColors.pink)),
                      const SizedBox(height: 10),
                      Chip(label: Text('${d['level']}')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _stat(Icons.psychology, 'ML mastery', '${d['mastery']}%'),
                _stat(Icons.timer_outlined, 'Avg time',
                    '${n(d['averageTime']).toStringAsFixed(1)}s (${d['speed']})'),
                _stat(Icons.mic_none, 'Voice', '${d['voiceScore']}'),
                _stat(Icons.trending_up, 'Trend', '${d['trend']}'),
              ]),
              const SizedBox(height: 20),
              Text('Analysis', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${d['feedback']}'),
                ),
              ),
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Recommendations',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final t in tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.lightbulb_outline,
                            color: AppColors.pink),
                        title: Text(t),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return SizedBox(
      width: 165,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.blue),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================================
// ============================================================================
//  AI-ML STUDIO MODULE
//  Workflow + PoC, demo data + requirements, demo model training, model
//  registry, monitoring, CRUD analysis, governance + security, release checks.
//  Uses only packages your app already has (http, shared_preferences, firebase).
// ============================================================================
// ============================================================================

// ------------------------------------------------------------------
// Small helpers
// ------------------------------------------------------------------
double _nv(dynamic v, [double d = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? d;

double _c01(double v) => v.isNaN ? 0.0 : (v < 0 ? 0.0 : (v > 1 ? 1.0 : v));

String _fmt(double v, [int d = 3]) => v.toStringAsFixed(d);

String _stamp(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

double _sigm(double x) {
  if (x < -30) return 0;
  if (x > 30) return 1;
  return 1 / (1 + exp(-x));
}

void _studioToast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

Widget _secTitle(BuildContext c, String t) => Padding(
  padding: const EdgeInsets.only(top: 22, bottom: 8),
  child: Text(t, style: Theme.of(c).textTheme.titleLarge),
);

Widget _pill(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: c.withAlpha(28),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: c.withAlpha(90)),
  ),
  child: Text(t,
      style:
      TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
);

Widget _infoCard(Widget child) => Card(
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Flexible(
          child: Text(k, style: const TextStyle(color: AppColors.muted))),
      const SizedBox(width: 12),
      Flexible(
          child: Text(v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600))),
    ],
  ),
);

Color _stageColor(String s) => s == 'Production'
    ? AppColors.blue
    : (s == 'Staging' ? AppColors.pink : AppColors.muted);

Color _statusColor(String s) => s == 'OK'
    ? const Color(0xFF16A34A)
    : (s == 'WARNING'
    ? const Color(0xFFF59E0B)
    : (s == 'ALERT' ? const Color(0xFFDC2626) : AppColors.muted));

/// Per-user key/value storage for Studio data.
class StudioStore {
  static String key(String base) =>
      '${base}_${FirebaseAuth.instance.currentUser?.uid ?? 'anon'}';

  static Future<String?> getString(String base) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(key(base));
  }

  static Future<void> setString(String base, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key(base), value);
  }

  static Future<void> remove(String base) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key(base));
  }

  static Future<List<Map<String, dynamic>>> readList(String base) async {
    try {
      final raw = await getString(base);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> writeList(
      String base, List<Map<String, dynamic>> list) =>
      setString(base, jsonEncode(list));
}

// ------------------------------------------------------------------
// Governance: audit log + consent
// ------------------------------------------------------------------
class AuditEvent {
  final DateTime at;
  final String action;
  final String detail;
  AuditEvent(this.at, this.action, this.detail);

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'action': action, 'detail': detail};

  factory AuditEvent.fromJson(Map<String, dynamic> j) => AuditEvent(
      DateTime.tryParse('${j['at']}') ?? DateTime.now(),
      '${j['action'] ?? ''}',
      '${j['detail'] ?? ''}');
}

class AuditLog {
  static const _key = 'studio_audit_log';

  static Future<void> add(String action, String detail) async {
    try {
      final list = await StudioStore.readList(_key);
      list.insert(0, AuditEvent(DateTime.now(), action, detail).toJson());
      await StudioStore.writeList(_key, list.take(200).toList());
    } catch (_) {}
  }

  static Future<List<AuditEvent>> load() async {
    final raw = await StudioStore.readList(_key);
    return raw.map(AuditEvent.fromJson).toList();
  }

  static Future<void> clear() => StudioStore.remove(_key);
}

class Governance {
  static Future<bool> consent() async =>
      (await StudioStore.getString('studio_consent')) != 'false';

  static Future<void> setConsent(bool v) async {
    await StudioStore.setString('studio_consent', v ? 'true' : 'false');
    await AuditLog.add('Consent changed',
        v ? 'Training on my data: allowed' : 'Training on my data: blocked');
  }
}

// ------------------------------------------------------------------
// Demo dataset + data profiling
// ------------------------------------------------------------------
class DemoData {
  static const _key = 'studio_demo_dataset';

  static List<PerformanceSample> generate(int n,
      {int seed = 42, double accShift = 0, double targetShift = 0}) {
    final rnd = Random(seed);
    return List.generate(n, (_) {
      final a = _c01(0.30 + rnd.nextDouble() * 0.65 + accShift);
      final s = _c01(0.20 + rnd.nextDouble() * 0.75);
      final v = _c01(rnd.nextDouble());
      final t = _c01(a * .65 +
          s * .15 +
          v * .20 +
          (rnd.nextDouble() - .5) * .06 +
          targetShift);
      return PerformanceSample(accuracy: a, speed: s, voiceScore: v, target: t);
    });
  }

  static Future<List<PerformanceSample>> load() async {
    final raw = await StudioStore.readList(_key);
    return raw.map(PerformanceSample.fromJson).toList();
  }

  static Future<void> save(List<PerformanceSample> d) =>
      StudioStore.writeList(_key, d.map((e) => e.toJson()).toList());

  static Future<void> clear() => StudioStore.remove(_key);
}

class FeatureStat {
  final String name;
  final double min, max, mean, std;
  final int invalid;
  FeatureStat(this.name, this.min, this.max, this.mean, this.std, this.invalid);
}

class DataProfile {
  final int rows;
  final List<FeatureStat> stats;
  DataProfile(this.rows, this.stats);

  int get invalid => stats.fold<int>(0, (a, b) => a + b.invalid);

  FeatureStat stat(String name) => stats.firstWhere((s) => s.name == name);

  static DataProfile of(List<PerformanceSample> d) {
    FeatureStat build(String name, double Function(PerformanceSample) f) {
      if (d.isEmpty) return FeatureStat(name, 0, 0, 0, 0, 0);
      final vals = d.map(f).toList();
      var invalid = 0;
      for (final v in vals) {
        if (v.isNaN || v < 0 || v > 1) invalid++;
      }
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      final variance =
          vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
              vals.length;
      return FeatureStat(
        name,
        vals.reduce((a, b) => a < b ? a : b),
        vals.reduce((a, b) => a > b ? a : b),
        mean,
        sqrt(variance),
        invalid,
      );
    }

    return DataProfile(d.length, [
      build('accuracy', (s) => s.accuracy),
      build('speed', (s) => s.speed),
      build('voiceScore', (s) => s.voiceScore),
      build('target', (s) => s.target),
    ]);
  }
}

// ------------------------------------------------------------------
// Demo ML models (pure Dart, no extra packages)
// ------------------------------------------------------------------
abstract class MlModel {
  String get type;
  double predict(double a, double s, double v);
  Map<String, dynamic> toParams();
}

class LogisticModel implements MlModel {
  final double bias, aw, sw, vw;
  LogisticModel(this.bias, this.aw, this.sw, this.vw);

  factory LogisticModel.fromML(StudentPerformanceML m) => LogisticModel(
      m.bias, m.accuracyWeight, m.speedWeight, m.voiceWeight);

  @override
  String get type => 'logistic';

  @override
  double predict(double a, double s, double v) =>
      _sigm(bias + aw * a + sw * s + vw * v);

  @override
  Map<String, dynamic> toParams() => {
    'bias': bias,
    'accuracyWeight': aw,
    'speedWeight': sw,
    'voiceWeight': vw,
  };
}

class KnnModel implements MlModel {
  final int k;
  final List<List<double>> points; // [accuracy, speed, voice, target]
  KnnModel(this.k, this.points);

  factory KnnModel.fromTrain(List<PerformanceSample> train,
      {int k = 5, int maxPoints = 150}) {
    final step = max(1, (train.length / maxPoints).ceil());
    final pts = <List<double>>[];
    for (var i = 0; i < train.length; i += step) {
      final s = train[i];
      pts.add([s.accuracy, s.speed, s.voiceScore, s.target]);
    }
    return KnnModel(k, pts);
  }

  @override
  String get type => 'knn';

  @override
  double predict(double a, double s, double v) {
    if (points.isEmpty) return 0.5;
    final d = <MapEntry<double, double>>[];
    for (final p in points) {
      final da = p[0] - a;
      final ds = p[1] - s;
      final dv = p[2] - v;
      d.add(MapEntry(da * da + ds * ds + dv * dv, p[3]));
    }
    d.sort((x, y) => x.key.compareTo(y.key));
    final n = min(k, d.length);
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      sum += d[i].value;
    }
    return sum / n;
  }

  @override
  Map<String, dynamic> toParams() => {'k': k, 'points': points};
}

MlModel? modelFromEntry(RegistryEntry e) {
  try {
    final p = e.params;
    if (e.type == 'logistic') {
      return LogisticModel(_nv(p['bias']), _nv(p['accuracyWeight']),
          _nv(p['speedWeight']), _nv(p['voiceWeight']));
    }
    if (e.type == 'knn') {
      final pts = (p['points'] as List)
          .map((r) => (r as List).map((x) => _nv(x)).toList())
          .toList();
      return KnnModel((_nv(p['k'], 5)).round(), pts);
    }
  } catch (_) {}
  return null;
}

class EvalMetrics {
  final double mae, rmse, r2;
  final int n;
  EvalMetrics(this.mae, this.rmse, this.r2, this.n);

  static EvalMetrics of(MlModel m, List<PerformanceSample> d) {
    if (d.isEmpty) return EvalMetrics(0, 0, 0, 0);
    double mean = 0;
    for (final s in d) {
      mean += s.target;
    }
    mean /= d.length;
    double ae = 0, se = 0, tot = 0;
    for (final s in d) {
      final p = m.predict(s.accuracy, s.speed, s.voiceScore);
      final e = s.target - p;
      ae += e.abs();
      se += e * e;
      tot += (s.target - mean) * (s.target - mean);
    }
    return EvalMetrics(
        ae / d.length, sqrt(se / d.length), tot == 0 ? 0 : 1 - se / tot, d.length);
  }
}

List<List<PerformanceSample>> _split(List<PerformanceSample> data,
    {int seed = 7}) {
  final all = List<PerformanceSample>.from(data)..shuffle(Random(seed));
  if (all.length < 5) return [all, all];
  final cut = max(1, (all.length * .8).floor());
  return [all.sublist(0, cut), all.sublist(cut)];
}

class TrainedCandidate {
  final String name;
  final MlModel model;
  final EvalMetrics val;
  final EvalMetrics train;
  final int trainSize;
  final int valSize;
  final double refMean;
  final double refStd;
  TrainedCandidate(this.name, this.model, this.val, this.train, this.trainSize,
      this.valSize, this.refMean, this.refStd);
}

class DemoTrainer {
  static Future<List<TrainedCandidate>> trainBoth(List<PerformanceSample> data,
      {int epochs = 60}) async {
    final parts = _split(data);
    final train = parts[0];
    final val = parts[1];
    final ref = DataProfile.of(train).stat('accuracy');

    final ml = StudentPerformanceML();
    await ml.fit(train, epochs: epochs, learningRate: .08);
    final lg = LogisticModel.fromML(ml);
    final knn = KnnModel.fromTrain(train);

    return [
      TrainedCandidate('mastery-logistic', lg, EvalMetrics.of(lg, val),
          EvalMetrics.of(lg, train), train.length, val.length, ref.mean, ref.std),
      TrainedCandidate('mastery-knn', knn, EvalMetrics.of(knn, val),
          EvalMetrics.of(knn, train), train.length, val.length, ref.mean, ref.std),
    ];
  }
}

// ------------------------------------------------------------------
// Model registry (versions, stages, metrics, checksum)
// ------------------------------------------------------------------
class RegistryEntry {
  final String id;
  final String name;
  final String type;
  final int version;
  String stage; // Staging | Production | Archived
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> params;
  final DateTime trainedAt;
  final int samples;
  final String checksum;
  final String source;

  RegistryEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.version,
    required this.stage,
    required this.metrics,
    required this.params,
    required this.trainedAt,
    required this.samples,
    required this.checksum,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'version': version,
    'stage': stage,
    'metrics': metrics,
    'params': params,
    'trainedAt': trainedAt.toIso8601String(),
    'samples': samples,
    'checksum': checksum,
    'source': source,
  };

  factory RegistryEntry.fromJson(Map<String, dynamic> j) => RegistryEntry(
    id: '${j['id']}',
    name: '${j['name']}',
    type: '${j['type']}',
    version: _nv(j['version'], 1).round(),
    stage: '${j['stage'] ?? 'Staging'}',
    metrics: Map<String, dynamic>.from(j['metrics'] as Map? ?? {}),
    params: Map<String, dynamic>.from(j['params'] as Map? ?? {}),
    trainedAt: DateTime.tryParse('${j['trainedAt']}') ?? DateTime.now(),
    samples: _nv(j['samples']).round(),
    checksum: '${j['checksum'] ?? ''}',
    source: '${j['source'] ?? ''}',
  );
}

class ModelRegistry {
  static const _key = 'studio_model_registry';

  static Future<List<RegistryEntry>> load() async {
    final raw = await StudioStore.readList(_key);
    final list = raw.map(RegistryEntry.fromJson).toList();
    list.sort((a, b) => b.trainedAt.compareTo(a.trainedAt));
    return list;
  }

  static Future<void> _save(List<RegistryEntry> l) =>
      StudioStore.writeList(_key, l.map((e) => e.toJson()).toList());

  static Future<RegistryEntry?> production() async {
    final l = await load();
    for (final e in l) {
      if (e.stage == 'Production') return e;
    }
    return null;
  }

  static Future<RegistryEntry> register({
    required String name,
    required String type,
    required Map<String, dynamic> metrics,
    required Map<String, dynamic> params,
    required int samples,
    required String source,
  }) async {
    final list = await load();
    final v = list
        .where((e) => e.name == name)
        .fold<int>(0, (m, e) => max(m, e.version)) +
        1;
    final e = RegistryEntry(
      id: 'm${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      type: type,
      version: v,
      stage: 'Staging',
      metrics: metrics,
      params: params,
      trainedAt: DateTime.now(),
      samples: samples,
      checksum: _fnv(jsonEncode(params)).toRadixString(16),
      source: source,
    );
    list.insert(0, e);
    await _save(list);
    unawaited(_mirror(e));
    await AuditLog.add('Model registered', '${e.name} v${e.version} ($source)');
    return e;
  }

  static Future<RegistryEntry> registerCandidate(
      TrainedCandidate c, String source) {
    return register(
      name: c.name,
      type: c.model.type,
      metrics: {
        'mae': c.val.mae,
        'rmse': c.val.rmse,
        'r2': c.val.r2,
        'trainMae': c.train.mae,
        'refMean': c.refMean,
        'refStd': c.refStd,
      },
      params: c.model.toParams(),
      samples: c.trainSize + c.valSize,
      source: source,
    );
  }

  static Future<void> setStage(String id, String stage) async {
    final list = await load();
    RegistryEntry? target;
    for (final e in list) {
      if (e.id == id) target = e;
    }
    if (target == null) return;
    for (final e in list) {
      if (e.id == id) {
        e.stage = stage;
      } else if (stage == 'Production' && e.stage == 'Production') {
        e.stage = 'Archived';
      }
    }
    await _save(list);
    unawaited(_mirror(target));
    await AuditLog.add(
        'Model stage -> $stage', '${target.name} v${target.version}');
    if (stage == 'Production') {
      await NotificationService.notify('Model promoted',
          '${target.name} v${target.version} is now in Production.');
    }
  }

  static Future<void> delete(String id) async {
    final list = await load();
    final gone = list.where((e) => e.id == id).toList();
    list.removeWhere((e) => e.id == id);
    await _save(list);
    for (final e in gone) {
      await AuditLog.add('Model deleted', '${e.name} v${e.version}');
    }
  }

  /// Called by the ML Training tab after each training run.
  static Future<void> registerLive(
      StudentPerformanceML m, TrainingResult r, int samples) async {
    try {
      final data = await StudentStorage.loadPerformanceSamples();
      final lg = LogisticModel.fromML(m);
      final ev = data.isEmpty ? null : EvalMetrics.of(lg, data);
      final st = DataProfile.of(data).stat('accuracy');
      final fallback = sqrt(r.finalVal);
      final e = await register(
        name: 'mastery-logistic-live',
        type: 'logistic',
        metrics: {
          'mae': ev?.mae ?? fallback,
          'rmse': ev?.rmse ?? fallback,
          'r2': ev?.r2 ?? 0.0,
          'trainLoss': r.finalTrain,
          'valLoss': r.finalVal,
          'refMean': st.mean,
          'refStd': st.std,
        },
        params: lg.toParams(),
        samples: samples,
        source: 'ML Training tab',
      );
      await NotificationService.notify('Model registered',
          '${e.name} v${e.version} saved to the registry (Staging).');
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    await StudioStore.remove(_key);
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      final q = await fs.FirebaseFirestore.instance
          .collection('model_registry')
          .where('uid', isEqualTo: u.uid)
          .get();
      for (final d in q.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
  }

  static Future<void> _mirror(RegistryEntry e) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      await fs.FirebaseFirestore.instance
          .collection('model_registry')
          .doc('${u.uid}_${e.id}')
          .set({
        ...e.toJson(),
        'uid': u.uid,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

class ModelCard {
  static String build(RegistryEntry e) {
    final b = StringBuffer()
      ..writeln('MODEL CARD')
      ..writeln('Name: ${e.name}  (v${e.version}, ${e.stage})')
      ..writeln('Type: ${e.type}')
      ..writeln('Trained: ${_stamp(e.trainedAt)}  on ${e.samples} samples')
      ..writeln('Source: ${e.source}')
      ..writeln('Checksum: ${e.checksum}')
      ..writeln()
      ..writeln('Intended use: estimate a student\'s vocabulary mastery (0-1)')
      ..writeln('from accuracy, answer speed and voice score.')
      ..writeln('Not for: grading, admissions or any high-stakes decision.')
      ..writeln()
      ..writeln('Metrics (hold-out):')
      ..writeln('  MAE  ${_fmt(_nv(e.metrics['mae']))}')
      ..writeln('  RMSE ${_fmt(_nv(e.metrics['rmse']))}')
      ..writeln('  R2   ${_fmt(_nv(e.metrics['r2']))}')
      ..writeln()
      ..writeln('Data: no names, emails or other personal details are used')
      ..writeln('as features. Stored per user id.')
      ..writeln()
      ..writeln('Limitations: small data, simple model, trained on demo or')
      ..writeln('self-reported practice data. Re-check for drift regularly.');
    return b.toString();
  }
}

// ------------------------------------------------------------------
// Monitoring: error, drift, latency
// ------------------------------------------------------------------
class MonitorReport {
  final String status; // OK | WARNING | ALERT | NO MODEL
  final String model;
  final double? baselineMae, liveMae, driftZ, latencyUs;
  final int liveCount;
  final List<String> findings;
  MonitorReport({
    required this.status,
    required this.model,
    required this.liveCount,
    required this.findings,
    this.baselineMae,
    this.liveMae,
    this.driftZ,
    this.latencyUs,
  });
}

class ModelMonitor {
  static Future<MonitorReport> evaluate(List<AssessmentRecord> history) {
    final live = history.take(30).map(PerformanceSample.fromRecord).toList();
    return evaluateSamples(live);
  }

  static Future<MonitorReport> evaluateSamples(
      List<PerformanceSample> live) async {
    final prod = await ModelRegistry.production();
    if (prod == null) {
      return MonitorReport(
        status: 'NO MODEL',
        model: 'none',
        liveCount: live.length,
        findings: ['No Production model. Register one and promote it in the Registry.'],
      );
    }
    final model = modelFromEntry(prod);
    if (model == null) {
      return MonitorReport(
        status: 'NO MODEL',
        model: '${prod.name} v${prod.version}',
        liveCount: live.length,
        findings: ['The Production model could not be loaded.'],
      );
    }

    final findings = <String>[];
    final baseline = _nv(prod.metrics['mae']);
    double? liveMae;
    double? z;

    if (live.length >= 3) {
      var ae = 0.0;
      var am = 0.0;
      for (final s in live) {
        ae += (s.target - model.predict(s.accuracy, s.speed, s.voiceScore)).abs();
        am += s.accuracy;
      }
      liveMae = ae / live.length;
      final liveMean = am / live.length;
      final refMean = _nv(prod.metrics['refMean'], 0.5);
      final refStd = max(_nv(prod.metrics['refStd'], 0.2), 0.05);
      z = (liveMean - refMean) / refStd;
    } else {
      findings.add(
          'Only ${live.length} live assessments. At least 3 are needed for monitoring.');
    }

    final sw = Stopwatch()..start();
    var sink = 0.0;
    for (var i = 0; i < 2000; i++) {
      sink += model.predict(.5, .5, .5);
    }
    sw.stop();
    if (sink.isNaN) findings.add('The model returned an invalid value (NaN).');
    final latency = sw.elapsedMicroseconds / 2000;

    var status = 'OK';
    if (liveMae != null) {
      if (liveMae > baseline * 2 + 0.02) {
        status = 'ALERT';
        findings.add(
            'Live error ${_fmt(liveMae)} is more than double the training error ${_fmt(baseline)}.');
      } else if (liveMae > baseline * 1.5 + 0.01) {
        status = 'WARNING';
        findings.add(
            'Live error ${_fmt(liveMae)} is rising above the training error ${_fmt(baseline)}.');
      }
    }
    if (z != null) {
      if (z.abs() > 2) {
        status = 'ALERT';
        findings.add(
            'Input drift: live accuracy moved ${_fmt(z, 1)} standard deviations from training data.');
      } else if (z.abs() > 1 && status == 'OK') {
        status = 'WARNING';
        findings.add(
            'Mild input drift: live accuracy moved ${_fmt(z, 1)} standard deviations.');
      }
    }
    if (findings.isEmpty) {
      findings.add('All checks passed. No drift or error increase detected.');
    }

    return MonitorReport(
      status: status,
      model: '${prod.name} v${prod.version}',
      liveCount: live.length,
      findings: findings,
      baselineMae: baseline,
      liveMae: liveMae,
      driftZ: z,
      latencyUs: latency,
    );
  }

  static Future<void> notifyIfNeeded(MonitorReport r) async {
    if (r.status != 'ALERT' && r.status != 'WARNING') return;
    await AuditLog.add('Monitoring ${r.status}', r.findings.first);
    if (r.status == 'ALERT') {
      await NotificationService.notify(
          'Model monitoring alert', r.findings.first);
    }
  }
}

// ------------------------------------------------------------------
// Full demo workflow: data -> train -> register -> deploy -> monitor
// ------------------------------------------------------------------
class MlWorkflow {
  static Future<List<String>> runDemo(List<AssessmentRecord> history,
      {void Function(String)? onStep}) async {
    final log = <String>[];
    void step(String m) {
      log.add(m);
      onStep?.call(m);
    }

    step('1/6  Generating 500 demo records...');
    final data = DemoData.generate(500);
    await DemoData.save(data);

    final prof = DataProfile.of(data);
    step('2/6  Data check: ${prof.rows} rows, ${prof.invalid} invalid values.');

    step('3/6  Training logistic + kNN models...');
    final cands = await DemoTrainer.trainBoth(data);
    for (final c in cands) {
      step('       ${c.name}: MAE ${_fmt(c.val.mae)}, R2 ${_fmt(c.val.r2)}');
    }

    step('4/6  Registering both models (Staging)...');
    final entries = <RegistryEntry>[];
    for (final c in cands) {
      entries.add(await ModelRegistry.registerCandidate(c, 'Demo workflow'));
    }

    var best = 0;
    for (var i = 1; i < cands.length; i++) {
      if (cands[i].val.mae < cands[best].val.mae) best = i;
    }
    step('5/6  Promoting ${entries[best].name} v${entries[best].version} to Production...');
    await ModelRegistry.setStage(entries[best].id, 'Production');

    step('6/6  Monitoring the Production model...');
    final live = history.length >= 3
        ? history.take(30).map(PerformanceSample.fromRecord).toList()
        : DemoData.generate(30, seed: 99);
    final rep = await ModelMonitor.evaluateSamples(live);
    step('       Status: ${rep.status}');
    await NotificationService.notify('ML workflow complete',
        'Best model: ${entries[best].name}. Monitoring status: ${rep.status}.');
    await AuditLog.add('Demo workflow', 'Completed. Monitoring ${rep.status}');
    step('Done.');
    return log;
  }
}

// ------------------------------------------------------------------
// CRUD client for the Python server (+ self-test and analysis)
// ------------------------------------------------------------------
class CrudStat {
  final String op;
  final bool ok;
  final int ms;
  final String detail;
  final String body;
  final DateTime at;
  CrudStat(this.op, this.ok, this.ms, this.detail, this.body)
      : at = DateTime.now();
}

class VocabCrud {
  static final List<CrudStat> log = [];
  static const _json = {'Content-Type': 'application/json'};

  static String get _base => '${VocabularyApi.baseUrl}/words';

  static Future<CrudStat> _run(
      String op, Future<http.Response> Function() call) async {
    final sw = Stopwatch()..start();
    CrudStat stat;
    try {
      final res = await call().timeout(const Duration(seconds: 10));
      sw.stop();
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      var detail = 'HTTP ${res.statusCode}';
      if (!ok) {
        final b = utf8.decode(res.bodyBytes);
        detail += ': ${b.length > 80 ? b.substring(0, 80) : b}';
      }
      stat = CrudStat(op, ok, sw.elapsedMilliseconds, detail,
          utf8.decode(res.bodyBytes));
    } catch (e) {
      sw.stop();
      stat = CrudStat(op, false, sw.elapsedMilliseconds, '$e', '');
    }
    log.insert(0, stat);
    if (log.length > 100) log.removeLast();
    unawaited(AuditLog.add(
        'CRUD $op', stat.ok ? 'ok (${stat.ms} ms)' : 'failed: ${stat.detail}'));
    return stat;
  }

  static Future<CrudStat> list() =>
      _run('READ', () => http.get(Uri.parse(_base)));

  static Future<CrudStat> read(dynamic id) =>
      _run('READ', () => http.get(Uri.parse('$_base/$id')));

  static Future<CrudStat> create(Map<String, dynamic> body) => _run(
      'CREATE',
          () => http.post(Uri.parse(_base), headers: _json, body: jsonEncode(body)));

  static Future<CrudStat> update(dynamic id, Map<String, dynamic> body) =>
      _run(
          'UPDATE',
              () => http.put(Uri.parse('$_base/$id'),
              headers: _json, body: jsonEncode(body)));

  static Future<CrudStat> delete(dynamic id) =>
      _run('DELETE', () => http.delete(Uri.parse('$_base/$id')));

  static dynamic idFrom(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map) {
        if (d['id'] != null) return d['id'];
        final w = d['word'];
        if (w is Map && w['id'] != null) return w['id'];
        final x = d['data'];
        if (x is Map && x['id'] != null) return x['id'];
      }
    } catch (_) {}
    return null;
  }

  /// Creates, reads, updates and deletes a temporary record.
  static Future<List<CrudStat>> selfTest() async {
    final out = <CrudStat>[];
    final name = 'zz_crud_test_${DateTime.now().millisecondsSinceEpoch}';
    final body = <String, dynamic>{
      'word': name,
      'letter': 'Z',
      'definition': 'Temporary record created by the CRUD self-test.',
      'meaning': 'test',
      'example': 'This is only a test.',
      'difficulty': 'Easy',
      'synonyms': ['test'],
    };

    final c = await create(body);
    out.add(c);
    if (!c.ok) return out;

    dynamic id = idFrom(c.body);
    if (id == null) {
      final l = await list();
      out.add(l);
      if (l.ok) {
        try {
          final d = jsonDecode(l.body);
          final arr = d is Map ? (d['words'] as List? ?? []) : (d as List);
          for (final e in arr) {
            if (e is Map && e['word'] == name) id = e['id'];
          }
        } catch (_) {}
      }
    }
    if (id == null) {
      out.add(CrudStat('READ', false, 0,
          'The server did not return an id for the new record.', ''));
      return out;
    }

    out.add(await read(id));
    out.add(await update(id, {...body, 'meaning': 'test (updated)'}));
    out.add(await delete(id));
    return out;
  }
}

// ============================================================================
//  STUDIO UI
// ============================================================================

class StudioHubPage extends StatelessWidget {
  final List<VocabularyWord> words;
  final List<AssessmentRecord> history;
  final StudentPerformanceML model;
  final EtlReport? wordReport;
  final Future<void> Function() onReloadWords;
  final Future<void> Function() onModelChanged;

  const StudioHubPage({
    super.key,
    required this.words,
    required this.history,
    required this.model,
    required this.wordReport,
    required this.onReloadWords,
    required this.onModelChanged,
  });

  void _open(BuildContext c, Widget page) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final tiles = <_HubTile>[
      _HubTile(
        Icons.account_tree_outlined,
        'ML workflow & proof of concept',
        'Pipeline stages, live status, one-tap demo run',
            () => _open(
            context,
            WorkflowPage(
                words: words,
                history: history,
                model: model,
                wordReport: wordReport)),
      ),
      _HubTile(
        Icons.dataset_outlined,
        'Data & requirements',
        'Demo dataset, data profile, quality checks',
            () => _open(context, const DataStudioPage()),
      ),
      _HubTile(
        Icons.model_training,
        'Train demo models',
        'Logistic vs kNN, metrics, register best',
            () => _open(context, const TrainStudioPage()),
      ),
      _HubTile(
        Icons.inventory_2_outlined,
        'Model registry',
        'Versions, stages, promote / roll back, model card',
            () => _open(context, const RegistryPage()),
      ),
      _HubTile(
        Icons.monitor_heart_outlined,
        'Monitoring',
        'Error, drift and latency with push alerts',
            () => _open(context, MonitorPage(history: history)),
      ),
      _HubTile(
        Icons.sync_alt,
        'CRUD analysis (Python + Flutter)',
        'Create, read, update, delete + self-test',
            () => _open(
            context, CrudPage(words: words, onReloadWords: onReloadWords)),
      ),
      _HubTile(
        Icons.shield_outlined,
        'Governance & security',
        'Consent, audit log, checks, delete my data',
            () => _open(context, GovernancePage(onModelChanged: onModelChanged)),
      ),
      _HubTile(
        Icons.rocket_launch_outlined,
        'Release & code review',
        'Play Store testing, readiness checks',
            () => _open(
            context,
            ReleasePage(words: words, model: model, wordReport: wordReport)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('AI-ML Studio')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Study & review app: ML operations',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Everything needed to build, test, deploy and watch the vocabulary '
                    'AI model: data, training, registry, monitoring, governance and release checks.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          )),
          const SizedBox(height: 14),
          for (var i = 0; i < tiles.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor:
                    i.isEven ? AppColors.softBlue : AppColors.softPink,
                    child: Icon(tiles[i].icon,
                        color: i.isEven ? AppColors.blue : AppColors.pink),
                  ),
                  title: Text(tiles[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(tiles[i].subtitle),
                  trailing:
                  const Icon(Icons.chevron_right, color: AppColors.pink),
                  onTap: tiles[i].onTap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubTile {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  _HubTile(this.icon, this.title, this.subtitle, this.onTap);
}

// ------------------------------------------------------------------
// Reusable checklist that remembers ticks
// ------------------------------------------------------------------
class ChecklistItem {
  final String id;
  final String title;
  final String detail;
  const ChecklistItem(this.id, this.title, this.detail);
}

class PersistentChecklist extends StatefulWidget {
  final String storeKey;
  final List<ChecklistItem> items;
  const PersistentChecklist(
      {super.key, required this.storeKey, required this.items});

  @override
  State<PersistentChecklist> createState() => _PersistentChecklistState();
}

class _PersistentChecklistState extends State<PersistentChecklist> {
  final Set<String> done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await StudioStore.getString(widget.storeKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).map((e) => '$e');
        if (mounted) setState(() => done.addAll(list));
      }
    } catch (_) {}
  }

  Future<void> _toggle(String id, bool on) async {
    setState(() => on ? done.add(id) : done.remove(id));
    await StudioStore.setString(widget.storeKey, jsonEncode(done.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final count = widget.items.where((i) => done.contains(i.id)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : count / total,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$count / $total',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            for (final i in widget.items)
              CheckboxListTile(
                value: done.contains(i.id),
                onChanged: (v) => _toggle(i.id, v ?? false),
                activeColor: AppColors.pink,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(i.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(i.detail),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Workflow & proof of concept
// ------------------------------------------------------------------
class _Stage {
  final String title;
  final String detail;
  final bool done;
  final IconData icon;
  _Stage(this.title, this.detail, this.done, this.icon);
}

class WorkflowPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final List<AssessmentRecord> history;
  final StudentPerformanceML model;
  final EtlReport? wordReport;
  const WorkflowPage({
    super.key,
    required this.words,
    required this.history,
    required this.model,
    required this.wordReport,
  });

  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  List<_Stage> stages = [];
  RegistryEntry? prod;
  bool loading = true;
  bool running = false;
  final List<String> log = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reg = await ModelRegistry.load();
    final demo = await DemoData.load();
    final samples = await StudentStorage.loadPerformanceSamples();
    final p = await ModelRegistry.production();
    final mon = p == null ? null : await ModelMonitor.evaluate(widget.history);
    final r = widget.wordReport;
    if (!mounted) return;
    setState(() {
      prod = p;
      stages = [
        _Stage(
            'Data requirements & collection',
            '${widget.words.length} vocabulary words, ${samples.length} student samples, ${demo.length} demo rows',
            widget.words.isNotEmpty,
            Icons.storage_outlined),
        _Stage(
            'ETL pipeline (extract, transform, load)',
            r == null
                ? 'Not run yet'
                : 'Source ${r.source}: ${r.extracted} extracted, ${r.loaded} loaded, ${r.rejected} rejected',
            r != null,
            Icons.filter_alt_outlined),
        _Stage(
            'Feature engineering',
            'accuracy, speed, voice score -> mastery target',
            samples.isNotEmpty || demo.isNotEmpty,
            Icons.tune),
        _Stage(
            'Model training',
            '${widget.model.trainingSteps} live training steps, ${reg.length} registered models',
            widget.model.trainingSteps > 0 || reg.isNotEmpty,
            Icons.model_training),
        _Stage(
            'Evaluation',
            reg.isEmpty
                ? 'No metrics yet'
                : 'Latest MAE ${_fmt(_nv(reg.first.metrics['mae']))}',
            reg.any((e) => e.metrics.containsKey('mae')),
            Icons.fact_check_outlined),
        _Stage('Model registry', '${reg.length} versions stored', reg.isNotEmpty,
            Icons.inventory_2_outlined),
        _Stage(
            'Deployment (Production stage)',
            p == null ? 'No Production model' : '${p.name} v${p.version}',
            p != null,
            Icons.rocket_launch_outlined),
        _Stage(
            'Monitoring',
            mon == null ? 'Needs a Production model' : 'Status ${mon.status}',
            mon != null && mon.status != 'NO MODEL',
            Icons.monitor_heart_outlined),
      ];
      loading = false;
    });
  }

  Future<void> _runDemo() async {
    setState(() {
      running = true;
      log.clear();
    });
    try {
      await MlWorkflow.runDemo(widget.history, onStep: (m) {
        if (mounted) setState(() => log.add(m));
      });
      await _load();
    } catch (e) {
      if (mounted) _studioToast(context, 'Workflow failed: $e');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = stages.where((s) => s.done).length;
    final p = prod;
    final mae = p == null ? null : _nv(p.metrics['mae']);

    return Scaffold(
      appBar: AppBar(title: const Text('ML workflow & PoC')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workflow progress: $doneCount of ${stages.length}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: stages.isEmpty ? 0 : doneCount / stages.length,
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: running ? null : _runDemo,
                icon: const Icon(Icons.play_arrow),
                label: Text(running
                    ? 'Running...'
                    : 'Run full demo workflow'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Generates demo data, trains two models, registers them, '
                    'promotes the best, monitors it and sends a push notification.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          )),
          if (log.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoCard(SelectableText(log.join('\n'),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12))),
          ],
          _secTitle(context, 'Pipeline stages'),
          for (final s in stages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(s.icon,
                      color: s.done ? AppColors.blue : AppColors.pink),
                  title: Text(s.title,
                      style:
                      const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.detail),
                  trailing: Icon(
                    s.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: s.done ? AppColors.blue : AppColors.pink,
                  ),
                ),
              ),
            ),
          _secTitle(context, 'Proof of concept summary'),
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Problem',
                  'Predict vocabulary mastery from accuracy, speed and voice'),
              _kv('Data',
                  'Server vocabulary + student assessments + demo data'),
              _kv('Models', 'Logistic regression and kNN (pure Dart)'),
              _kv('Success target', 'MAE below 0.08 on hold-out data'),
              _kv(
                  'Current result',
                  p == null
                      ? 'Run the workflow to get a result'
                      : '${p.name} v${p.version}: MAE ${_fmt(mae ?? 0)} '
                      '(${(mae ?? 1) < 0.08 ? 'PASS' : 'needs work'})'),
              _kv('Next steps',
                  'Use more real data, add a TFLite model, automate retraining'),
            ],
          )),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Data & requirements
// ------------------------------------------------------------------
class DataStudioPage extends StatefulWidget {
  const DataStudioPage({super.key});

  @override
  State<DataStudioPage> createState() => _DataStudioPageState();
}

class _DataStudioPageState extends State<DataStudioPage> {
  List<PerformanceSample> demo = [];
  List<PerformanceSample> real = [];
  bool useReal = false;
  bool consent = true;
  double n = 500;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await DemoData.load();
    final r = await StudentStorage.loadPerformanceSamples();
    final c = await Governance.consent();
    if (!mounted) return;
    setState(() {
      demo = d;
      real = r;
      consent = c;
      loading = false;
    });
  }

  Future<void> _generate() async {
    final d = DemoData.generate(n.round(), seed: DateTime.now().millisecond);
    await DemoData.save(d);
    await AuditLog.add('Demo data generated', '${d.length} rows');
    if (!mounted) return;
    setState(() {
      demo = d;
      useReal = false;
    });
    _studioToast(context, '${d.length} demo rows generated and saved.');
  }

  Future<void> _clear() async {
    await DemoData.clear();
    await AuditLog.add('Demo data cleared', '');
    if (!mounted) return;
    setState(() => demo = []);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = useReal && !consent;
    final data = blocked ? <PerformanceSample>[] : (useReal ? real : demo);
    final prof = DataProfile.of(data);
    final acc = prof.stat('accuracy');
    final tgt = prof.stat('target');

    final checks = <List<dynamic>>[
      ['At least 100 rows', prof.rows >= 100],
      ['No missing or out-of-range values', prof.rows > 0 && prof.invalid == 0],
      ['Accuracy has variety (std above 0.05)', acc.std > 0.05],
      ['Target has variety (std above 0.05)', tgt.std > 0.05],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Data & requirements')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Demo data'),
                      icon: Icon(Icons.science_outlined)),
                  ButtonSegment(
                      value: true,
                      label: Text('My data'),
                      icon: Icon(Icons.person_outline)),
                ],
                selected: {useReal},
                onSelectionChanged: (s) =>
                    setState(() => useReal = s.first),
              ),
              const SizedBox(height: 12),
              Text(
                  useReal
                      ? '${real.length} samples from your assessments'
                      : '${demo.length} demo rows stored',
                  style: const TextStyle(color: AppColors.muted)),
              if (blocked)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                      'You turned off training on your data (Governance tab), so it is hidden here.',
                      style: TextStyle(color: AppColors.pink)),
                ),
              if (!useReal) ...[
                const SizedBox(height: 8),
                Text('Rows to generate: ${n.round()}'),
                Slider(
                  value: n,
                  min: 100,
                  max: 1000,
                  divisions: 9,
                  onChanged: (v) => setState(() => n = v),
                ),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate demo data'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                      onPressed: demo.isEmpty ? null : _clear,
                      child: const Text('Clear')),
                ]),
              ],
            ],
          )),
          _secTitle(context, 'Data profile'),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Feature')),
                  DataColumn(label: Text('Min')),
                  DataColumn(label: Text('Max')),
                  DataColumn(label: Text('Mean')),
                  DataColumn(label: Text('Std')),
                  DataColumn(label: Text('Invalid')),
                ],
                rows: [
                  for (final s in prof.stats)
                    DataRow(cells: [
                      DataCell(Text(s.name)),
                      DataCell(Text(_fmt(s.min))),
                      DataCell(Text(_fmt(s.max))),
                      DataCell(Text(_fmt(s.mean))),
                      DataCell(Text(_fmt(s.std))),
                      DataCell(Text('${s.invalid}')),
                    ]),
                ],
              ),
            ),
          ),
          _secTitle(context, 'Quality checks'),
          _infoCard(Column(children: [
            for (final c in checks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    c[1] as bool
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: c[1] as bool
                        ? AppColors.blue
                        : AppColors.pink),
                title: Text(c[0] as String),
              ),
          ])),
          _secTitle(context, 'Data requirements'),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Field')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Range')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Needed')),
                ],
                rows: const [
                  DataRow(cells: [
                    DataCell(Text('accuracy')),
                    DataCell(Text('float')),
                    DataCell(Text('0 - 1')),
                    DataCell(Text('Test score / total')),
                    DataCell(Text('Yes')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('speed')),
                    DataCell(Text('float')),
                    DataCell(Text('0 - 1')),
                    DataCell(Text('1 / (1 + avg seconds / 15)')),
                    DataCell(Text('Yes')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('voiceScore')),
                    DataCell(Text('float')),
                    DataCell(Text('0 - 1')),
                    DataCell(Text('Voice tutor result')),
                    DataCell(Text('Optional')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('target')),
                    DataCell(Text('float')),
                    DataCell(Text('0 - 1')),
                    DataCell(Text('Weighted mastery label')),
                    DataCell(Text('Yes')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('word, definition')),
                    DataCell(Text('text')),
                    DataCell(Text('non-empty')),
                    DataCell(Text('Python server /words')),
                    DataCell(Text('Yes')),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Minimum 100 rows to train. No names or emails are used as features. '
                'Each student\'s data is stored under their own user id.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Train demo models
// ------------------------------------------------------------------
class TrainStudioPage extends StatefulWidget {
  const TrainStudioPage({super.key});

  @override
  State<TrainStudioPage> createState() => _TrainStudioPageState();
}

class _TrainStudioPageState extends State<TrainStudioPage> {
  bool useReal = false;
  bool consent = true;
  bool training = false;
  double epochs = 60;
  List<TrainedCandidate> cands = [];
  final Set<String> registered = {};

  @override
  void initState() {
    super.initState();
    Governance.consent().then((c) {
      if (mounted) setState(() => consent = c);
    });
  }

  Future<void> _train() async {
    setState(() {
      training = true;
      cands = [];
      registered.clear();
    });
    try {
      List<PerformanceSample> data;
      if (useReal) {
        if (!consent) {
          _studioToast(context,
              'Training on your data is turned off in the Governance tab.');
          return;
        }
        data = await StudentStorage.loadPerformanceSamples();
      } else {
        data = await DemoData.load();
        if (data.isEmpty) {
          data = DemoData.generate(500);
          await DemoData.save(data);
        }
      }
      if (data.length < 20) {
        if (mounted) {
          _studioToast(context,
              'Need at least 20 samples. Use demo data or take more tests.');
        }
        return;
      }
      final r = await DemoTrainer.trainBoth(data, epochs: epochs.round());
      await AuditLog.add('Demo training',
          '${data.length} rows, ${epochs.round()} epochs, ${useReal ? 'my data' : 'demo data'}');
      if (mounted) setState(() => cands = r);
    } catch (e) {
      if (mounted) _studioToast(context, 'Training failed: $e');
    } finally {
      if (mounted) setState(() => training = false);
    }
  }

  int get _bestIndex {
    var best = 0;
    for (var i = 1; i < cands.length; i++) {
      if (cands[i].val.mae < cands[best].val.mae) best = i;
    }
    return best;
  }

  Future<void> _register(TrainedCandidate c) async {
    final e = await ModelRegistry.registerCandidate(c, 'Train page');
    await NotificationService.notify(
        'Model registered', '${e.name} v${e.version} saved (Staging).');
    if (!mounted) return;
    setState(() => registered.add(c.name));
    _studioToast(context, 'Registered ${e.name} v${e.version} as Staging.');
  }

  Future<void> _registerBest() async {
    final c = cands[_bestIndex];
    final e = await ModelRegistry.registerCandidate(c, 'Train page');
    await ModelRegistry.setStage(e.id, 'Production');
    if (!mounted) return;
    setState(() => registered.add(c.name));
    _studioToast(context, '${e.name} v${e.version} is now in Production.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Train demo models')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Demo data'),
                      icon: Icon(Icons.science_outlined)),
                  ButtonSegment(
                      value: true,
                      label: Text('My data'),
                      icon: Icon(Icons.person_outline)),
                ],
                selected: {useReal},
                onSelectionChanged: (s) => setState(() => useReal = s.first),
              ),
              const SizedBox(height: 12),
              Text('Epochs: ${epochs.round()}'),
              Slider(
                value: epochs,
                min: 10,
                max: 200,
                divisions: 19,
                onChanged: training ? null : (v) => setState(() => epochs = v),
              ),
              FilledButton.icon(
                onPressed: training ? null : _train,
                icon: const Icon(Icons.play_arrow),
                label: Text(training ? 'Training...' : 'Train both models'),
              ),
              if (training) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          )),
          if (cands.isNotEmpty) ...[
            _secTitle(context, 'Results (hold-out set)'),
            for (var i = 0; i < cands.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _infoCard(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(cands[i].name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      if (i == _bestIndex) _pill('Best', AppColors.blue),
                    ]),
                    const SizedBox(height: 8),
                    _kv('MAE (lower is better)', _fmt(cands[i].val.mae)),
                    _kv('RMSE', _fmt(cands[i].val.rmse)),
                    _kv('R2 (higher is better)', _fmt(cands[i].val.r2)),
                    _kv('Train MAE', _fmt(cands[i].train.mae)),
                    _kv('Train / validation rows',
                        '${cands[i].trainSize} / ${cands[i].valSize}'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: registered.contains(cands[i].name)
                          ? null
                          : () => _register(cands[i]),
                      icon: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.pink),
                      label: Text(registered.contains(cands[i].name)
                          ? 'Registered'
                          : 'Register (Staging)'),
                    ),
                  ],
                )),
              ),
            FilledButton.icon(
              onPressed: _registerBest,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Register best & promote to Production'),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Model registry
// ------------------------------------------------------------------
class RegistryPage extends StatefulWidget {
  const RegistryPage({super.key});

  @override
  State<RegistryPage> createState() => _RegistryPageState();
}

class _RegistryPageState extends State<RegistryPage> {
  List<RegistryEntry> entries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await ModelRegistry.load();
    if (!mounted) return;
    setState(() {
      entries = l;
      loading = false;
    });
  }

  Future<void> _stage(RegistryEntry e, String stage) async {
    await ModelRegistry.setStage(e.id, stage);
    await _load();
  }

  Future<void> _delete(RegistryEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete model?'),
        content: Text('${e.name} v${e.version} will be removed from the registry.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ModelRegistry.delete(e.id);
      await _load();
    }
  }

  void _card(RegistryEntry e) {
    final text = ModelCard.build(e);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Model card', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            SelectableText(text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) _studioToast(ctx, 'Model card copied.');
              },
              icon: const Icon(Icons.copy, color: AppColors.pink),
              label: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model registry'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'No models yet. Train one in "Train demo models" or the ML Training tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted)),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _infoCard(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('${e.name}  v${e.version}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                    _pill(e.stage, _stageColor(e.stage)),
                  ]),
                  const SizedBox(height: 8),
                  _kv('Type', e.type),
                  _kv('MAE', _fmt(_nv(e.metrics['mae']))),
                  _kv('R2', _fmt(_nv(e.metrics['r2']))),
                  _kv('Samples', '${e.samples}'),
                  _kv('Checksum', e.checksum),
                  _kv('Trained', _stamp(e.trainedAt)),
                  _kv('Source', e.source),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    if (e.stage != 'Production')
                      FilledButton(
                          onPressed: () => _stage(e, 'Production'),
                          child: Text(e.stage == 'Archived'
                              ? 'Roll back to this'
                              : 'Promote')),
                    if (e.stage == 'Production')
                      OutlinedButton(
                          onPressed: () => _stage(e, 'Staging'),
                          child: const Text('Move to Staging')),
                    if (e.stage != 'Archived')
                      OutlinedButton(
                          onPressed: () => _stage(e, 'Archived'),
                          child: const Text('Archive')),
                    TextButton(
                        onPressed: () => _card(e),
                        child: const Text('Model card')),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _delete(e),
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.pink),
                    ),
                  ]),
                ],
              )),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Monitoring
// ------------------------------------------------------------------
class MonitorPage extends StatefulWidget {
  final List<AssessmentRecord> history;
  const MonitorPage({super.key, required this.history});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  MonitorReport? report;
  bool loading = true;
  bool simulated = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run({bool simulate = false}) async {
    setState(() {
      loading = true;
      simulated = simulate;
    });
    try {
      final r = simulate
          ? await ModelMonitor.evaluateSamples(DemoData.generate(30,
          seed: 5, accShift: -.35, targetShift: -.18))
          : await ModelMonitor.evaluate(widget.history);
      await ModelMonitor.notifyIfNeeded(r);
      if (!mounted) return;
      setState(() => report = r);
    } catch (e) {
      if (mounted) _studioToast(context, 'Monitoring failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _tile(IconData icon, String label, String value) => SizedBox(
    width: 165,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring')),
      body: loading || r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _pill(r.status, _statusColor(r.status)),
                const SizedBox(width: 10),
                if (simulated) _pill('Simulated drift', AppColors.pink),
              ]),
              const SizedBox(height: 10),
              Text('Model: ${r.model}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Live assessments checked: ${r.liveCount}',
                  style: const TextStyle(color: AppColors.muted)),
            ],
          )),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _tile(Icons.error_outline, 'Live error (MAE)',
                r.liveMae == null ? '-' : _fmt(r.liveMae!)),
            _tile(Icons.flag_outlined, 'Training error',
                r.baselineMae == null ? '-' : _fmt(r.baselineMae!)),
            _tile(Icons.swap_vert, 'Drift (z-score)',
                r.driftZ == null ? '-' : _fmt(r.driftZ!, 2)),
            _tile(Icons.speed, 'Latency',
                r.latencyUs == null ? '-' : '${_fmt(r.latencyUs!, 1)} us'),
          ]),
          _secTitle(context, 'Findings'),
          for (final f in r.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(
                      r.status == 'OK'
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: r.status == 'OK'
                          ? AppColors.blue
                          : AppColors.pink),
                  title: Text(f),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _run(),
            icon: const Icon(Icons.refresh),
            label: const Text('Check with my live data'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _run(simulate: true),
            icon: const Icon(Icons.bug_report_outlined,
                color: AppColors.pink),
            label: const Text('Simulate drift (sends alert)'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Rules: ALERT when live error is more than double the training error '
                'or the accuracy mean drifts over 2 standard deviations. '
                'ALERT also sends a push notification.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// CRUD analysis
// ------------------------------------------------------------------
class CrudPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final Future<void> Function() onReloadWords;
  const CrudPage({super.key, required this.words, required this.onReloadWords});

  @override
  State<CrudPage> createState() => _CrudPageState();
}

class _CrudPageState extends State<CrudPage> {
  late List<VocabularyWord> items;
  final _q = TextEditingController();
  bool busy = false;
  List<CrudStat> testRun = [];

  @override
  void initState() {
    super.initState();
    items = List<VocabularyWord>.from(widget.words);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<VocabularyWord> get _filtered {
    final q = _q.text.trim().toLowerCase();
    final l = q.isEmpty
        ? items
        : items
        .where((w) =>
    w.word.toLowerCase().contains(q) ||
        w.definition.toLowerCase().contains(q))
        .toList();
    return l.length > 200 ? l.sublist(0, 200) : l;
  }

  Future<Map<String, dynamic>?> _editDialog({VocabularyWord? w}) {
    final word = TextEditingController(text: w?.word ?? '');
    final def = TextEditingController(text: w?.definition ?? '');
    final mean = TextEditingController(text: w?.meaning ?? '');
    final ex = TextEditingController(text: w?.example ?? '');
    final diff = TextEditingController(text: w?.difficulty ?? '');
    final syn = TextEditingController(text: w?.synonyms.join(', ') ?? '');
    String? err;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(w == null ? 'Add word' : 'Edit word'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: word,
                  decoration: const InputDecoration(labelText: 'Word')),
              TextField(
                  controller: def,
                  decoration: const InputDecoration(labelText: 'Definition')),
              TextField(
                  controller: mean,
                  decoration: const InputDecoration(labelText: 'Meaning')),
              TextField(
                  controller: ex,
                  decoration: const InputDecoration(labelText: 'Example')),
              TextField(
                  controller: diff,
                  decoration: const InputDecoration(labelText: 'Difficulty')),
              TextField(
                  controller: syn,
                  decoration: const InputDecoration(
                      labelText: 'Synonyms (comma separated)')),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                  Text(err!, style: const TextStyle(color: AppColors.pink)),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final wd = word.text.trim();
                if (wd.isEmpty ||
                    (def.text.trim().isEmpty && mean.text.trim().isEmpty)) {
                  setS(() => err = 'A word and a definition or meaning are required.');
                  return;
                }
                Navigator.pop(ctx, {
                  'word': wd,
                  'letter': wd[0].toUpperCase(),
                  'definition': def.text.trim(),
                  'meaning': mean.text.trim(),
                  'example': ex.text.trim(),
                  'difficulty': diff.text.trim(),
                  'synonyms': syn.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final data = await _editDialog();
    if (data == null) return;
    setState(() => busy = true);
    final st = await VocabCrud.create(data);
    if (st.ok) {
      final id = VocabCrud.idFrom(st.body) ??
          DateTime.now().millisecondsSinceEpoch;
      final nw = VocabularyWord.fromJson({...data, 'id': id}).cleaned();
      items.insert(0, nw);
      unawaited(widget.onReloadWords());
    }
    if (!mounted) return;
    setState(() => busy = false);
    _studioToast(context, st.ok ? 'Word created.' : 'Create failed: ${st.detail}');
  }

  Future<void> _edit(VocabularyWord w) async {
    if (w.id == null) {
      _studioToast(context, 'This word has no id, so it cannot be updated.');
      return;
    }
    final data = await _editDialog(w: w);
    if (data == null) return;
    setState(() => busy = true);
    final st = await VocabCrud.update(w.id, data);
    if (st.ok) {
      final idx = items.indexWhere((e) => e.id == w.id);
      if (idx >= 0) {
        items[idx] = VocabularyWord.fromJson({...data, 'id': w.id}).cleaned();
      }
      unawaited(widget.onReloadWords());
    }
    if (!mounted) return;
    setState(() => busy = false);
    _studioToast(context, st.ok ? 'Word updated.' : 'Update failed: ${st.detail}');
  }

  Future<void> _delete(VocabularyWord w) async {
    if (w.id == null) {
      _studioToast(context, 'This word has no id, so it cannot be deleted.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete word?'),
        content: Text('"${w.word}" will be deleted from the server.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    final st = await VocabCrud.delete(w.id);
    if (st.ok) {
      items.removeWhere((e) => e.id == w.id);
      unawaited(widget.onReloadWords());
    }
    if (!mounted) return;
    setState(() => busy = false);
    _studioToast(context, st.ok ? 'Word deleted.' : 'Delete failed: ${st.detail}');
  }

  Future<void> _selfTest() async {
    setState(() {
      busy = true;
      testRun = [];
    });
    final r = await VocabCrud.selfTest();
    if (!mounted) return;
    setState(() {
      testRun = r;
      busy = false;
    });
  }

  Widget _analysis() {
    final ops = ['CREATE', 'READ', 'UPDATE', 'DELETE'];
    final rows = <DataRow>[];
    for (final op in ops) {
      final l = VocabCrud.log.where((s) => s.op == op).toList();
      final okCount = l.where((s) => s.ok).length;
      final avg = l.isEmpty
          ? 0
          : l.map((s) => s.ms).reduce((a, b) => a + b) / l.length;
      rows.add(DataRow(cells: [
        DataCell(Text(op)),
        DataCell(Text('${l.length}')),
        DataCell(Text('$okCount')),
        DataCell(Text(l.isEmpty
            ? '-'
            : '${(okCount / l.length * 100).toStringAsFixed(0)}%')),
        DataCell(Text(l.isEmpty ? '-' : '${avg.toStringAsFixed(0)} ms')),
      ]));
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Operation')),
            DataColumn(label: Text('Calls')),
            DataColumn(label: Text('OK')),
            DataColumn(label: Text('Success')),
            DataColumn(label: Text('Avg time')),
          ],
          rows: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('CRUD analysis')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : _create,
        backgroundColor: AppColors.pink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add word'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        children: [
          if (busy) const LinearProgressIndicator(),
          Text('Server: ${VocabularyApi.baseUrl}',
              style: const TextStyle(color: AppColors.muted)),
          _secTitle(context, 'This session'),
          _analysis(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _selfTest,
            icon: const Icon(Icons.rule, color: AppColors.pink),
            label: const Text('Run CRUD self-test'),
          ),
          if (testRun.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoCard(Column(children: [
              for (final s in testRun)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(s.ok ? Icons.check_circle : Icons.cancel,
                      color: s.ok ? AppColors.blue : AppColors.pink),
                  title: Text('${s.op}  (${s.ms} ms)'),
                  subtitle: Text(s.detail),
                ),
            ])),
          ],
          _secTitle(context, 'Words (${items.length})'),
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: AppColors.blue),
              labelText: 'Search words',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          for (final w in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(w.word,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      w.definition.isNotEmpty ? w.definition : w.meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: 'Edit',
                        onPressed: busy ? null : () => _edit(w),
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        tooltip: 'Delete',
                        onPressed: busy ? null : () => _delete(w),
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.pink)),
                  ]),
                ),
              ),
            ),
          if (items.length > list.length && _q.text.trim().isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Showing the first 200. Use search to find more.',
                  style: TextStyle(color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Governance & security
// ------------------------------------------------------------------
class _Check {
  final String title;
  final String detail;
  final bool ok;
  _Check(this.title, this.detail, this.ok);
}

class GovernancePage extends StatefulWidget {
  final Future<void> Function() onModelChanged;
  const GovernancePage({super.key, required this.onModelChanged});

  @override
  State<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends State<GovernancePage> {
  bool consent = true;
  bool loading = true;
  RegistryEntry? prod;
  List<AuditEvent> events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await Governance.consent();
    final p = await ModelRegistry.production();
    final e = await AuditLog.load();
    if (!mounted) return;
    setState(() {
      consent = c;
      prod = p;
      events = e;
      loading = false;
    });
  }

  Future<void> _setConsent(bool v) async {
    await Governance.setConsent(v);
    await _load();
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all my data?'),
        content: const Text(
            'This removes your assessment history, training samples, ML model, '
                'demo data, registry and audit log from this device and your cloud registry copies.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete everything')),
        ],
      ),
    );
    if (ok != true) return;
    await StudentStorage.clearStudentData();
    await ModelRegistry.clearAll();
    await DemoData.clear();
    await AuditLog.clear();
    await AuditLog.add('Data deleted', 'User deleted all personal data');
    await widget.onModelChanged();
    await _load();
    if (mounted) {
      _studioToast(context, 'All your data was deleted. Restart the app to reset the screens.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final https = VocabularyApi.baseUrl.startsWith('https');
    final checks = <_Check>[
      _Check('Sign-in required', 'Only signed-in students can use the app.',
          user != null),
      _Check('Per-user data isolation',
          'All local data is stored under your user id.', true),
      _Check(
          'Training consent recorded',
          consent
              ? 'You allow your data to be used for training.'
              : 'Training on your data is switched off.',
          consent),
      _Check(
          'HTTPS API',
          https
              ? 'The API uses HTTPS.'
              : 'The API uses plain HTTP (${VocabularyApi.baseUrl}). Use HTTPS in production.',
          https),
      _Check(
          'Production model documented',
          prod == null
              ? 'No Production model yet.'
              : 'Model card available for ${prod!.name} v${prod!.version}.',
          prod != null),
      _Check('Audit log active', '${events.length} events recorded.',
          events.isNotEmpty),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Governance & security')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            onChanged: _setConsent,
            title: const Text('Allow training on my assessment data',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'When off, the data and training screens will not use your results.'),
          )),
          _secTitle(context, 'Automatic checks'),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(
                      c.ok
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      color: c.ok ? AppColors.blue : AppColors.pink),
                  title: Text(c.title,
                      style:
                      const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(c.detail),
                ),
              ),
            ),
          _secTitle(context, 'Manual security review'),
          const PersistentChecklist(
            storeKey: 'gov_manual',
            items: [
              ChecklistItem('rules', 'Firestore rules published',
                  'Each user can only read and write their own documents.'),
              ChecklistItem('secrets', 'No keys or passwords in the code',
                  'Server secrets live in Cloud Functions, never in the app.'),
              ChecklistItem('privacy', 'Privacy policy ready',
                  'A public URL is needed for the Play Store listing.'),
              ChecklistItem('retention', 'Retention period defined',
                  'For example: delete inactive student data after 12 months.'),
              ChecklistItem('delete', 'Delete-my-data flow tested',
                  'Use the red button below and confirm the data is gone.'),
              ChecklistItem('deps', 'Dependencies checked',
                  'Run flutter pub outdated and update packages with fixes.'),
              ChecklistItem('bias', 'Model reviewed for bias',
                  'Check that accuracy is similar across student groups.'),
            ],
          ),
          if (prod != null) ...[
            _secTitle(context, 'Production model card'),
            _infoCard(SelectableText(ModelCard.build(prod!),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12))),
          ],
          _secTitle(context, 'Audit log (latest 15)'),
          if (events.isEmpty)
            const Text('No events yet.',
                style: TextStyle(color: AppColors.muted))
          else
            _infoCard(Column(children: [
              for (final e in events.take(15))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.action),
                  subtitle: Text('${_stamp(e.at)}  ${e.detail}'),
                ),
            ])),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await AuditLog.clear();
              await _load();
            },
            icon: const Icon(Icons.clear_all, color: AppColors.pink),
            label: const Text('Clear audit log'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.pink),
            onPressed: _deleteAll,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete all my data'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Release readiness: Play Store testing + code review
// ------------------------------------------------------------------
class _Diag {
  final String name;
  final bool ok;
  final String detail;
  _Diag(this.name, this.ok, this.detail);
}

class ReleasePage extends StatefulWidget {
  final List<VocabularyWord> words;
  final StudentPerformanceML model;
  final EtlReport? wordReport;
  const ReleasePage(
      {super.key,
        required this.words,
        required this.model,
        required this.wordReport});

  @override
  State<ReleasePage> createState() => _ReleasePageState();
}

class _ReleasePageState extends State<ReleasePage> {
  List<_Diag> diags = [];
  bool running = false;

  Future<void> _run() async {
    setState(() {
      running = true;
      diags = [];
    });
    final out = <_Diag>[];
    final base = VocabularyApi.baseUrl;

    try {
      final res = await http
          .get(Uri.parse('$base/words'))
          .timeout(const Duration(seconds: 6));
      out.add(_Diag('Python server reachable', res.statusCode == 200,
          'GET $base/words returned ${res.statusCode}'));
    } catch (e) {
      out.add(_Diag('Python server reachable', false, '$e'));
    }

    out.add(_Diag(
        'HTTPS API',
        base.startsWith('https'),
        base.startsWith('https')
            ? 'Secure connection.'
            : 'Release builds on Android 9+ block plain HTTP. Use HTTPS.'));

    final local = base.contains('localhost') ||
        base.contains('192.168.') ||
        base.contains('10.0.2.2');
    out.add(_Diag(
        'Server URL is not a local address',
        !local,
        local
            ? 'Points to $base. Build with --dart-define=VOCAB_URL=https://your-server'
            : base));

    out.add(_Diag('Vocabulary loaded', widget.words.isNotEmpty,
        '${widget.words.length} words'));
    out.add(_Diag('ETL pipeline ran', widget.wordReport != null,
        widget.wordReport?.source ?? 'Not run'));
    out.add(_Diag('ML model trained', widget.model.trainingSteps > 0,
        '${widget.model.trainingSteps} training steps'));
    out.add(_Diag('Signed in', FirebaseAuth.instance.currentUser != null,
        FirebaseAuth.instance.currentUser?.email ?? 'No user'));

    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) throw 'Sign in first';
      await fs.FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      out.add(_Diag('Firestore reachable', true, 'Read succeeded.'));
    } catch (e) {
      out.add(_Diag('Firestore reachable', false, '$e'));
    }

    if (_pushSupported) {
      final t = NotificationService.token;
      out.add(_Diag('Push token available', t != null,
          t == null ? 'No FCM token yet' : '${t.substring(0, min(18, t.length))}...'));
    } else {
      out.add(_Diag('Push notifications', true,
          'Not supported on this platform (Android and iOS only).'));
    }

    if (!mounted) return;
    setState(() {
      diags = out;
      running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Release & code review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: running ? null : _run,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: Text(running ? 'Checking...' : 'Run readiness checks'),
          ),
          if (running) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (diags.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in diags)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                        d.ok ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: d.ok ? AppColors.blue : AppColors.pink),
                    title: Text(d.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(d.detail),
                  ),
                ),
              ),
          ],
          _secTitle(context, 'Play Store deployment testing'),
          const PersistentChecklist(
            storeKey: 'release_playstore',
            items: [
              ChecklistItem('appid', 'Unique applicationId set',
                  'android/app/build.gradle, for example com.yourname.vocabularyai.'),
              ChecklistItem('version', 'Version updated',
                  'pubspec.yaml: version: 1.0.0+1 (the number after + is the versionCode).'),
              ChecklistItem('internet', 'INTERNET permission added',
                  'Add <uses-permission android:name="android.permission.INTERNET"/> to the main AndroidManifest.xml. Debug builds add it automatically, release builds do not.'),
              ChecklistItem('mic', 'RECORD_AUDIO permission added',
                  'Needed by the voice tutor (speech recognition).'),
              ChecklistItem('notif', 'POST_NOTIFICATIONS permission added',
                  'Needed for push notifications on Android 13+.'),
              ChecklistItem('keystore', 'Release keystore configured',
                  'Create an upload key and reference it in key.properties.'),
              ChecklistItem('sha', 'SHA-1 and SHA-256 added in Firebase',
                  'Add the release key fingerprints in Project Settings, then download a fresh google-services.json.'),
              ChecklistItem('icon', 'App icon and splash screen set',
                  'Check them on a real device.'),
              ChecklistItem('bundle', 'Release bundle builds',
                  'flutter build appbundle --release --dart-define=VOCAB_URL=https://your-server'),
              ChecklistItem('devices', 'Tested on low-end phone and tablet',
                  'Check the layout, voice tutor and notifications.'),
              ChecklistItem('internal', 'Uploaded to the Internal testing track',
                  'Add testers by email in Play Console and install from the link.'),
              ChecklistItem('prelaunch', 'Pre-launch report reviewed',
                  'Fix crashes and accessibility warnings that Play Console finds.'),
              ChecklistItem('safety', 'Data safety form and privacy policy done',
                  'Declare account info, assessment data and voice usage.'),
              ChecklistItem('listing', 'Store listing complete',
                  'Screenshots, description, content rating and target audience.'),
            ],
          ),
          _secTitle(context, 'Code review'),
          const PersistentChecklist(
            storeKey: 'release_codereview',
            items: [
              ChecklistItem('analyze', 'flutter analyze has no errors',
                  'Fix warnings about unused code and missing awaits.'),
              ChecklistItem('url', 'Server URL not hard-coded',
                  'Use --dart-define=VOCAB_URL for every environment.'),
              ChecklistItem('errors', 'Async calls handle errors',
                  'Every network and storage call is inside try/catch.'),
              ChecklistItem('dispose', 'Controllers and streams disposed',
                  'Check TextEditingController, timers and subscriptions.'),
              ChecklistItem('logs', 'No secrets or noisy debug prints',
                  'Remove tokens and personal data from logs.'),
              ChecklistItem('tests', 'Tests for ETL and ML code',
                  'Cover cleaning rules, feature engineering and metrics.'),
              ChecklistItem('a11y', 'Accessibility checked',
                  'Large text, contrast and screen reader labels.'),
            ],
          ),
          _secTitle(context, 'Release commands'),
          _infoCard(const SelectableText(
            'flutter clean && flutter pub get\n'
                'flutter analyze\n'
                'flutter test\n'
                'flutter build appbundle --release \\\n'
                '  --dart-define=VOCAB_URL=https://your-server.com\n'
                '# upload build/app/outputs/bundle/release/app-release.aab',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          )),
        ],
      ),
    );
  }
}

// ============================================================================
// ============================================================================
//  NEW MODULE  -  PROVIDER + NETWORK IMAGES + PLATFORM CHANNELS + AI COACH
//
//  APPEND THIS WHOLE BLOCK TO THE BOTTOM OF YOUR EXISTING main.dart
//  (see the 5 small edits listed in the chat reply / at the end of this file).
//
//  Needs one new package:   provider: ^6.1.2
//  Everything else uses packages the app already imports.
// ============================================================================
// ============================================================================

// ------------------------------------------------------------------
// 1. PROVIDER ROOT
// ------------------------------------------------------------------

/// All app-wide ChangeNotifiers live here. Used in main():
///   runApp(MultiProvider(providers: AppProviders.build(),
///                        child: const VocabularyAIApp()));
class AppProviders {
  static List<SingleChildWidget> build() => [
    ChangeNotifierProvider<StudyProvider>(create: (_) => StudyProvider()),
    ChangeNotifierProvider<NativeProvider>(create: (_) => NativeProvider()),
  ];
}

// ------------------------------------------------------------------
// 2. NETWORK IMAGES (pink + blue brand look)
// ------------------------------------------------------------------

class BrandImages {
  /// Override at run time:
  ///   flutter run --dart-define=BANNER_URL=https://your-cdn/banner.jpg
  static const _override = String.fromEnvironment('BANNER_URL');

  /// Fallback list. The pink/blue gradient overlay in [BrandBanner] is applied
  /// on top of whichever photo loads, so the pink + blue look is guaranteed
  /// even if you swap the photo for another one.
  static const List<String> urls = [
    'https://picsum.photos/seed/vocab-pink-blue/1200/600',
    'https://picsum.photos/seed/books-learning/1200/600',
    'https://picsum.photos/seed/language-study/1200/600',
  ];

  static String get primary => _override.isNotEmpty ? _override : urls.first;
  static String at(int i) => urls[i % urls.length];
}

/// Photo from the network + blue-to-pink gradient + title text.
/// Shows a gradient (never a blank box) while loading or when offline.
class BrandBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final double height;
  final String? url;

  const BrandBanner({
    super.key,
    required this.title,
    this.subtitle = '',
    this.height = 170,
    this.url,
  });

  Widget _gradientFill({Widget? child}) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.blue, AppColors.pink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url ?? BrandImages.primary,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (c, child, progress) {
                if (progress == null) return child;
                final total = progress.expectedTotalBytes;
                return _gradientFill(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      value: total == null
                          ? null
                          : progress.cumulativeBytesLoaded / total,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _gradientFill(
                child: const Center(
                  child: Icon(Icons.auto_stories,
                      size: 56, color: Colors.white54),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blue.withValues(alpha: .80),
                    AppColors.pink.withValues(alpha: .62),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.3)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular network avatar with a pink ring (used in the Device tab).
class BrandAvatar extends StatelessWidget {
  final double size;
  final String? url;
  const BrandAvatar({super.key, this.size = 56, this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.blue, AppColors.pink]),
      ),
      child: ClipOval(
        child: Image.network(
          url ?? BrandImages.at(1),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.softBlue,
            child: const Icon(Icons.person, color: AppColors.blue),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// 3. METHOD CHANNEL + EVENT CHANNEL
// ------------------------------------------------------------------

/// Thin wrapper over the platform channels. Every call is safe: if the native
/// side is missing (iOS without handler, web, desktop, tests) the call returns
/// null / uses a Dart fallback instead of crashing.
class NativeBridge {
  static const MethodChannel _method = MethodChannel('com.vocabai/native');
  static const EventChannel _events = EventChannel('com.vocabai/events');

  static Future<T?> _safe<T>(String name, [dynamic args]) async {
    try {
      return await _method.invokeMethod<T>(name, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Native "$name" failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Native "$name" error: $e');
      return null;
    }
  }

  /// Battery percentage (0-100) or null when unavailable.
  static Future<int?> batteryLevel() => _safe<int>('getBatteryLevel');

  /// Model / manufacturer / OS version. Falls back to Dart-only info.
  static Future<Map<String, dynamic>> deviceInfo() async {
    final r = await _safe<Map<dynamic, dynamic>>('getDeviceInfo');
    if (r != null) {
      return r.map((k, v) => MapEntry('$k', v));
    }
    return {
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'source': 'Dart fallback (no native handler)',
    };
  }

  /// kind: 'light' | 'medium' | 'heavy' | 'success' | 'error'
  static Future<void> haptic(String kind) async {
    final ok = await _safe<bool>('haptic', {'kind': kind});
    if (ok == true) return;
    switch (kind) {
      case 'heavy':
      case 'error':
        await HapticFeedback.heavyImpact();
        break;
      case 'medium':
        await HapticFeedback.mediumImpact();
        break;
      case 'success':
        await HapticFeedback.selectionClick();
        break;
      default:
        await HapticFeedback.lightImpact();
    }
  }

  /// Asks the native side to open the system share sheet with plain text.
  /// Returns false when the native handler is not present.
  static Future<bool> shareText(String text) async =>
      (await _safe<bool>('shareText', {'text': text})) == true;

  /// Native -> Dart stream (battery changes, connectivity, etc).
  /// Emits a MissingPluginException error when no handler exists; the
  /// provider turns that into a simulated heartbeat.
  static Stream<Map<String, dynamic>> events() {
    return _events.receiveBroadcastStream().map((e) {
      if (e is Map) return e.map((k, v) => MapEntry('$k', v));
      return <String, dynamic>{'type': 'raw', 'value': '$e'};
    });
  }
}

class NativeProvider extends ChangeNotifier {
  int? battery;
  bool charging = false;
  bool nativeAvailable = false;
  Map<String, dynamic> device = {};
  final List<String> eventLog = [];

  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _fallback;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    battery = await NativeBridge.batteryLevel();
    nativeAvailable = battery != null;
    device = await NativeBridge.deviceInfo();
    _log(nativeAvailable
        ? 'Native method channel connected.'
        : 'No native handler found. Using Dart fallbacks.');
    notifyListeners();

    _sub = NativeBridge.events().listen(
      _onEvent,
      onError: (Object e) {
        _startFallback();
      },
      cancelOnError: true,
    );
  }

  Future<void> refreshBattery() async {
    battery = await NativeBridge.batteryLevel();
    nativeAvailable = battery != null;
    _log(battery == null
        ? 'Battery: not available on this platform.'
        : 'Battery refreshed: $battery%.');
    notifyListeners();
  }

  void _onEvent(Map<String, dynamic> e) {
    final type = '${e['type']}';
    if (type == 'battery') {
      battery = _nv(e['level']).round();
      charging = e['charging'] == true;
      nativeAvailable = true;
      _log('Battery event: $battery%${charging ? ' (charging)' : ''}');
    } else {
      _log('Event: $e');
    }
    notifyListeners();
  }

  void _startFallback() {
    if (_fallback != null) return;
    _log('Event channel not implemented natively. Simulated heartbeat started.');
    _fallback = Timer.periodic(const Duration(seconds: 20), (_) {
      _log('Simulated heartbeat ${_stamp(DateTime.now())}');
      notifyListeners();
    });
    notifyListeners();
  }

  void _log(String m) {
    eventLog.insert(0, '${_stamp(DateTime.now())}  $m');
    if (eventLog.length > 40) eventLog.removeLast();
  }

  void clearLog() {
    eventLog.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fallback?.cancel();
    super.dispose();
  }
}

// ------------------------------------------------------------------
// 4. AI: SPACED-REPETITION (SM-2) + STUDY PROVIDER
// ------------------------------------------------------------------

class CardState {
  final String word;
  double ease;
  int interval; // days
  int reps;
  int lapses;
  DateTime due;
  DateTime? last;

  CardState(
      this.word, {
        this.ease = 2.5,
        this.interval = 0,
        this.reps = 0,
        this.lapses = 0,
        DateTime? due,
        this.last,
      }) : due = due ?? DateTime.now();

  bool get isDue => !due.isAfter(DateTime.now());

  String get stage {
    if (reps == 0) return lapses > 0 ? 'Relearning' : 'New';
    return interval >= 21 ? 'Mastered' : 'Learning';
  }

  /// SM-2. [q] is 0-5 (below 3 = forgot).
  void review(int q) {
    final g = q.clamp(0, 5);
    if (g < 3) {
      reps = 0;
      interval = 1;
      lapses++;
    } else {
      interval = previewInterval(g);
      reps++;
    }
    ease = max(1.3, ease + 0.1 - (5 - g) * (0.08 + (5 - g) * 0.02));
    last = DateTime.now();
    due = last!.add(Duration(days: interval));
  }

  int previewInterval(int q) {
    if (q < 3) return 1;
    if (reps == 0) return 1;
    if (reps == 1) return 6;
    return max(1, (interval * ease).round());
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'ease': ease,
    'interval': interval,
    'reps': reps,
    'lapses': lapses,
    'due': due.toIso8601String(),
    'last': last?.toIso8601String(),
  };

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
    '${j['word']}',
    ease: _nv(j['ease'], 2.5),
    interval: _nv(j['interval']).round(),
    reps: _nv(j['reps']).round(),
    lapses: _nv(j['lapses']).round(),
    due: DateTime.tryParse('${j['due']}'),
    last: DateTime.tryParse('${j['last']}'),
  );
}

class AiInsight {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const AiInsight(this.icon, this.title, this.body, this.color);
}

class AiPlanItem {
  final IconData icon;
  final String title;
  final String detail;
  final int minutes;
  const AiPlanItem(this.icon, this.title, this.detail, this.minutes);
}

double _aiSlope(List<double> y) {
  final n = y.length;
  if (n < 2) return 0;
  final xm = (n - 1) / 2;
  final ym = y.reduce((a, b) => a + b) / n;
  double num = 0, den = 0;
  for (var i = 0; i < n; i++) {
    num += (i - xm) * (y[i] - ym);
    den += (i - xm) * (i - xm);
  }
  return den == 0 ? 0 : num / den;
}

int _aiEditDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}

double _aiSimilarity(String a, String b) {
  final x = a.toLowerCase().trim();
  final y = b.toLowerCase().trim();
  if (x.isEmpty || y.isEmpty) return 0;
  return 1 - _aiEditDistance(x, y) / max(x.length, y.length);
}

class StudyProvider extends ChangeNotifier {
  static const _cardsKey = 'ai_cards_v1';
  static const _metaKey = 'ai_meta_v1';

  final Map<String, CardState> _cards = {};
  List<VocabularyWord> _words = [];

  int streak = 0;
  int bestStreak = 0;
  int dailyGoal = 10;
  int reviewedToday = 0;
  String _lastDay = '';
  String _reviewDay = '';
  bool loaded = false;

  List<VocabularyWord> get words => _words;

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
  String _yesterday() => DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);

  Future<void> load() async {
    try {
      _cards.clear();
      final raw = await StudioStore.readList(_cardsKey);
      for (final m in raw) {
        final c = CardState.fromJson(m);
        _cards[c.word.toLowerCase()] = c;
      }
      final metaRaw = await StudioStore.getString(_metaKey);
      if (metaRaw != null) {
        final m = Map<String, dynamic>.from(jsonDecode(metaRaw) as Map);
        streak = _nv(m['streak']).round();
        bestStreak = _nv(m['best']).round();
        dailyGoal = max(3, _nv(m['goal'], 10).round());
        _lastDay = '${m['lastDay'] ?? ''}';
        _reviewDay = '${m['reviewDay'] ?? ''}';
        reviewedToday = _reviewDay == _today() ? _nv(m['today']).round() : 0;
      } else {
        streak = 0;
        bestStreak = 0;
        reviewedToday = 0;
      }
      if (_lastDay != _today() && _lastDay != _yesterday()) streak = 0;
    } catch (e) {
      debugPrint('StudyProvider.load failed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await StudioStore.writeList(
          _cardsKey, _cards.values.map((c) => c.toJson()).toList());
      await StudioStore.setString(
          _metaKey,
          jsonEncode({
            'streak': streak,
            'best': bestStreak,
            'goal': dailyGoal,
            'lastDay': _lastDay,
            'reviewDay': _reviewDay,
            'today': reviewedToday,
          }));
    } catch (e) {
      debugPrint('StudyProvider.save failed: $e');
    }
  }

  void attachWords(List<VocabularyWord> w) {
    if (identical(w, _words)) return;
    _words = w;
    notifyListeners();
  }

  void setGoal(int g) {
    dailyGoal = g.clamp(3, 50);
    notifyListeners();
    unawaited(_save());
  }

  CardState? cardFor(VocabularyWord w) => _cards[w.word.toLowerCase()];

  int get dueCount => _words.where((w) => cardFor(w)?.isDue == true).length;
  int get newCount => _words.where((w) => cardFor(w) == null).length;
  int get learningCount =>
      _cards.values.where((c) => c.stage == 'Learning' || c.stage == 'Relearning').length;
  int get masteredCount => _cards.values.where((c) => c.stage == 'Mastered').length;
  double get goalProgress =>
      dailyGoal == 0 ? 0 : (reviewedToday / dailyGoal).clamp(0.0, 1.0);

  /// Due cards first (most overdue first), then new words to fill the goal.
  List<VocabularyWord> sessionQueue({int? size}) {
    final n = size ?? dailyGoal;
    final due = _words.where((w) => cardFor(w)?.isDue == true).toList()
      ..sort((a, b) => cardFor(a)!.due.compareTo(cardFor(b)!.due));
    final queue = due.take(n).toList();
    if (queue.length < n) {
      final seed = DateTime.now().year * 1000 + DateTime.now().day;
      final fresh = _words.where((w) => cardFor(w) == null).toList()
        ..shuffle(Random(seed));
      queue.addAll(fresh.take(n - queue.length));
    }
    return queue;
  }

  void review(VocabularyWord w, int quality) {
    final key = w.word.toLowerCase();
    final c = _cards.putIfAbsent(key, () => CardState(w.word));
    c.review(quality);

    final today = _today();
    if (_lastDay != today) {
      streak = _lastDay == _yesterday() ? streak + 1 : 1;
      bestStreak = max(bestStreak, streak);
      _lastDay = today;
    }
    if (_reviewDay != today) {
      _reviewDay = today;
      reviewedToday = 0;
    }
    reviewedToday++;
    notifyListeners();
    unawaited(_save());
    unawaited(NativeBridge.haptic(quality >= 3 ? 'light' : 'heavy'));
  }

  /// Words the learner struggles with (lapses, low ease).
  List<VocabularyWord> weakWords([int n = 8]) {
    final list = _words.where((w) {
      final c = cardFor(w);
      return c != null && (c.lapses > 0 || c.ease < 2.2);
    }).toList()
      ..sort((a, b) {
        final ca = cardFor(a)!, cb = cardFor(b)!;
        final byLapse = cb.lapses.compareTo(ca.lapses);
        return byLapse != 0 ? byLapse : ca.ease.compareTo(cb.ease);
      });
    return list.take(n).toList();
  }

  Future<void> resetProgress() async {
    _cards.clear();
    streak = 0;
    reviewedToday = 0;
    _lastDay = '';
    notifyListeners();
    await _save();
  }

  // ---------------- AI: daily plan ----------------
  List<AiPlanItem> dailyPlan(List<AssessmentRecord> history, double mastery) {
    final plan = <AiPlanItem>[];
    final due = dueCount;
    if (due > 0) {
      plan.add(AiPlanItem(Icons.replay_circle_filled, 'Review $due due cards',
          'Reviewing on time is what makes memory last.', max(3, due ~/ 2)));
    }
    final left = max(0, dailyGoal - reviewedToday - min(due, dailyGoal));
    if (left > 0 && newCount > 0) {
      final int wordsToLearn = min(left, newCount).toInt();

      plan.add(
        AiPlanItem(
          Icons.fiber_new,
          'Learn $wordsToLearn new words',
          mastery < 50
              ? 'Keep it small today and focus on understanding.'
              : 'You are ready for a bigger batch.',
          wordsToLearn * 1,
        ),
      );
    }
    final voice = history.where((h) => h.voiceScore > 0).take(3).toList();
    final voiceAvg = voice.isEmpty
        ? 0.0
        : voice.map((e) => e.voiceScore).reduce((a, b) => a + b) / voice.length;
    if (voice.isEmpty || voiceAvg < 70) {
      plan.add(const AiPlanItem(Icons.mic, 'Practise pronunciation',
          'Say 5 words aloud in the Voice tab.', 5));
    }
    final stale = history.isEmpty ||
        DateTime.now().difference(history.first.date).inDays >= 3;
    if (stale) {
      plan.add(const AiPlanItem(Icons.quiz, 'Take a 10-question test',
          'A fresh score keeps the ML model accurate.', 10));
    }
    final weak = weakWords(3);
    if (weak.isNotEmpty) {
      plan.add(AiPlanItem(Icons.healing, 'Fix weak words',
          weak.map((e) => e.word).join(', '), 5));
    }
    if (plan.isEmpty) {
      plan.add(const AiPlanItem(Icons.emoji_events, 'You are all caught up',
          'Try the Sentence Lab to use words in context.', 5));
    }
    return plan;
  }

  // ---------------- AI: insights ----------------
  List<AiInsight> insights(List<AssessmentRecord> history, double mastery) {
    final out = <AiInsight>[];
    if (history.length >= 3) {
      final series = history.take(10).toList().reversed
          .map((e) => e.percentage)
          .toList();
      final slope = _aiSlope(series);
      if (slope > 1) {
        final cur = series.last;
        final steps = cur >= 80 ? 0 : ((80 - cur) / slope).ceil();
        out.add(AiInsight(
            Icons.trending_up,
            'You are improving',
            steps == 0
                ? 'Scores trend up about ${slope.toStringAsFixed(1)} points per test and you are above 80%.'
                : 'Scores trend up about ${slope.toStringAsFixed(1)} points per test. At this pace you reach 80% in about $steps tests.',
            AppColors.blue));
      } else if (slope < -1) {
        out.add(AiInsight(
            Icons.trending_down,
            'Scores are slipping',
            'Down about ${(-slope).toStringAsFixed(1)} points per test. Do a short review session before the next test.',
            AppColors.pink));
      } else {
        out.add(const AiInsight(Icons.trending_flat, 'Steady progress',
            'Your scores are stable. Add harder words to keep growing.',
            AppColors.blue));
      }
      final avgTime = history.take(5).map((e) => e.averageTime).reduce((a, b) => a + b) /
          min(5, history.length);
      if (avgTime > 15) {
        out.add(AiInsight(
            Icons.timer_outlined,
            'Answer speed',
            'Average ${avgTime.toStringAsFixed(0)}s per question. Flashcard reviews will build faster recall.',
            AppColors.pink));
      }
    } else {
      out.add(const AiInsight(Icons.insights, 'Not enough data yet',
          'Complete 3 tests to unlock trend analysis and forecasts.',
          AppColors.blue));
    }
    if (mastery > 0) {
      out.add(AiInsight(
          Icons.psychology,
          'ML mastery estimate',
          'The on-device model predicts ${mastery.toStringAsFixed(0)}% mastery from your latest result.',
          AppColors.blue));
    }
    if (streak >= 3) {
      out.add(AiInsight(Icons.local_fire_department, '$streak day streak',
          'Best streak: $bestStreak days. Keep it going today.', AppColors.pink));
    }
    final weak = weakWords(3);
    if (weak.isNotEmpty) {
      out.add(AiInsight(
          Icons.healing,
          'Words to revisit',
          weak.map((w) => w.word).join(', '),
          AppColors.pink));
    }
    return out;
  }
}

// ------------------------------------------------------------------
// 5. AI: LOCAL TUTOR (intent detection + fuzzy / semantic word search)
// ------------------------------------------------------------------

class TutorMessage {
  final String text;
  final bool fromUser;
  final List<String> chips;
  const TutorMessage(this.text, {this.fromUser = false, this.chips = const []});
}

class TutorEngine {
  static const _stop = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'to', 'of', 'and', 'or',
    'in', 'on', 'for', 'with', 'that', 'this', 'it', 'be', 'as', 'at', 'by',
    'what', 'does', 'mean', 'word', 'i', 'you', 'me', 'my', 'do', 'how',
    'which', 'who', 'from', 'about', 'someone', 'something', 'one', 'not',
  };

  final List<VocabularyWord> words;
  final Random _r = Random();
  final Map<String, VocabularyWord> _index = {};
  VocabularyWord? _pending;
  VocabularyWord? lastWord;

  TutorEngine(this.words) {
    for (final w in words) {
      _index[w.word.toLowerCase()] = w;
    }
  }

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r"[^a-z\-']+"))
      .where((e) => e.isNotEmpty)
      .toList();

  static Set<String> _content(String s) =>
      _tokens(s).where((e) => e.length > 2 && !_stop.contains(e)).toSet();

  String _meaning(VocabularyWord w) =>
      w.meaning.isNotEmpty ? w.meaning : w.definition;

  List<VocabularyWord> _find(String t) {
    final found = <VocabularyWord>[];
    for (final e in _index.entries) {
      if (e.key.contains(' ') && t.contains(e.key)) found.add(e.value);
    }
    for (final tok in _tokens(t)) {
      final exact = _index[tok];
      if (exact != null) {
        if (!found.contains(exact)) found.add(exact);
        continue;
      }
      if (tok.length >= 5) {
        for (final e in _index.entries) {
          if ((e.key.length - tok.length).abs() <= 1 &&
              _aiEditDistance(e.key, tok) <= 1) {
            if (!found.contains(e.value)) found.add(e.value);
            break;
          }
        }
      }
    }
    return found;
  }

  /// Keyword-overlap search over meaning, definition, synonyms and usage.
  List<VocabularyWord> semanticSearch(String query, {int n = 3}) {
    final q = _content(query);
    if (q.isEmpty) return [];
    final scored = <MapEntry<VocabularyWord, int>>[];
    for (final w in words) {
      final hay = _content('${w.meaning} ${w.definition} ${w.usage}');
      final syn = w.synonyms.map((e) => e.toLowerCase()).toSet();
      var s = 0;
      for (final t in q) {
        if (hay.contains(t)) s += 2;
        if (syn.contains(t)) s += 3;
      }
      if (s > 0) scored.add(MapEntry(w, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(n).map((e) => e.key).toList();
  }

  String _card(VocabularyWord w) {
    final b = StringBuffer()
      ..writeln('${w.word}  (${w.partsOfSpeech}${w.difficultCefrStyle.isEmpty ? '' : ', ${w.difficultCefrStyle}'})');
    if (w.definition.isNotEmpty) b.writeln('Definition: ${w.definition}');
    if (w.meaning.isNotEmpty) b.writeln('Meaning: ${w.meaning}');
    if (w.synonyms.isNotEmpty) b.writeln('Synonyms: ${w.synonyms.take(5).join(', ')}');
    if (w.example.isNotEmpty) b.writeln('Example: ${w.example}');
    return b.toString().trim();
  }

  TutorMessage _grade(String answer) {
    final w = _pending!;
    final expected = _content('${w.meaning} ${w.definition} ${w.synonyms.join(' ')}');
    final given = _content(answer);
    final syn = w.synonyms.map((e) => e.toLowerCase());
    final hitSyn = given.any(syn.contains);
    final overlap = given.where(expected.contains).length;
    _pending = null;
    if (hitSyn || overlap >= 2) {
      return TutorMessage(
          'Correct! "${w.word}" means: ${_meaning(w)}',
          chips: const ['Quiz me', 'Give an example', 'Study plan']);
    }
    if (overlap == 1) {
      return TutorMessage(
          'Close. Full meaning of "${w.word}": ${_meaning(w)}',
          chips: const ['Quiz me', 'Give an example']);
    }
    return TutorMessage(
        'Not quite. "${w.word}" means: ${_meaning(w)}',
        chips: const ['Quiz me', 'Give an example']);
  }

  TutorMessage reply(String raw, {double mastery = 0, int due = 0}) {
    final t = raw.toLowerCase().trim();
    if (t.isEmpty) return const TutorMessage('Type a word or ask a question.');
    if (words.isEmpty) {
      return const TutorMessage('No vocabulary is loaded yet. Reload on the Dashboard.');
    }

    if (_pending != null) {
      if (RegExp(r"^(skip|stop|give up|answer|i don't know|idk)").hasMatch(t)) {
        final w = _pending!;
        _pending = null;
        return TutorMessage('No problem. "${w.word}" means: ${_meaning(w)}',
            chips: const ['Quiz me', 'Give an example']);
      }
      if (!t.contains('?') && _tokens(t).length <= 14) return _grade(t);
    }

    bool has(List<String> keys) => keys.any(t.contains);
    final found = _find(t);

    if (has(['hello', 'hi ', 'hey']) && found.isEmpty && t.length < 14) {
      return const TutorMessage(
          'Hi! I am your offline vocabulary tutor. Ask me about any word, or tap a suggestion.',
          chips: ['Quiz me', 'Study plan', 'Word of the day']);
    }
    if (has(['plan', 'what should i study', 'schedule'])) {
      return TutorMessage(
          'Today: review $due due cards, learn 5 new words, then do one test. '
              '${mastery > 0 ? 'Your predicted mastery is ${mastery.toStringAsFixed(0)}%.' : 'Take a test so I can estimate your mastery.'}',
          chips: const ['Quiz me', 'Word of the day']);
    }
    if (has(['word of the day', 'random word', 'new word'])) {
      final w = words[_r.nextInt(words.length)];
      lastWord = w;
      return TutorMessage(_card(w), chips: const ['Give an example', 'Quiz me']);
    }
    if (has(['quiz', 'test me', 'ask me'])) {
      final w = words[_r.nextInt(words.length)];
      _pending = w;
      lastWord = w;
      final hint = w.word.isEmpty ? '' : 'Hint: starts with "${w.word[0]}", ${w.word.length} letters.';
      return TutorMessage('What does "${w.word}" mean?\n$hint\n(Say "skip" to see the answer.)');
    }
    if (found.length >= 2 && has(['vs', 'compare', 'difference', 'versus'])) {
      final a = found[0], b = found[1];
      lastWord = a;
      return TutorMessage('${a.word}: ${_meaning(a)}\n\n${b.word}: ${_meaning(b)}\n\n'
          'Similarity of spelling: ${(_aiSimilarity(a.word, b.word) * 100).round()}%. '
          'Check the example sentences to see how each is used.',
          chips: [a.word, b.word]);
    }

    VocabularyWord? target = found.isNotEmpty ? found.first : null;
    final refersBack = has(['it', 'that word', 'this word', 'another example']);
    if (target == null && refersBack) target = lastWord;

    if (target != null) {
      lastWord = target;
      if (has(['synonym', 'similar', 'another word for', 'same as'])) {
        return TutorMessage(target.synonyms.isEmpty
            ? 'I have no synonyms stored for "${target.word}".'
            : 'Synonyms of "${target.word}": ${target.synonyms.join(', ')}',
            chips: const ['Give an example', 'Quiz me']);
      }
      if (has(['example', 'sentence', 'use it', 'context'])) {
        return TutorMessage(target.example.isEmpty
            ? 'No example stored. Try writing your own in the Sentence Lab.'
            : 'Example: ${target.example}',
            chips: const ['Synonyms', 'Quiz me']);
      }
      if (has(['usage', 'when do i use', 'how to use'])) {
        return TutorMessage(target.usage.isEmpty
            ? 'No usage note stored for "${target.word}".'
            : 'Usage: ${target.usage}');
      }
      return TutorMessage(_card(target),
          chips: const ['Synonyms', 'Give an example', 'Quiz me']);
    }

    final related = semanticSearch(t);
    if (related.isNotEmpty) {
      lastWord = related.first;
      return TutorMessage(
          'I could not find that exact word, but these relate to your question:\n'
              '${related.map((w) => '- ${w.word}: ${_meaning(w)}').join('\n')}',
          chips: related.map((w) => w.word).toList());
    }
    return const TutorMessage(
        'I did not understand. Try a word from your list, "quiz me", or "study plan".',
        chips: ['Quiz me', 'Study plan', 'Word of the day']);
  }
}

// ------------------------------------------------------------------
// 6. AI: SENTENCE COACH (rule-based writing feedback)
// ------------------------------------------------------------------

class SentenceReport {
  final int score;
  final List<String> good;
  final List<String> fix;
  const SentenceReport(this.score, this.good, this.fix);

  String get verdict => score >= 85
      ? 'Excellent'
      : score >= 70
      ? 'Good'
      : score >= 50
      ? 'Getting there'
      : 'Needs work';
}

class SentenceCoach {
  static const _connectors = {
    'because', 'although', 'which', 'while', 'since', 'however', 'despite',
    'when', 'if', 'whereas', 'who', 'that', 'so', 'but', 'though',
  };

  static SentenceReport analyze(VocabularyWord w, String sentence) {
    final s = sentence.trim();
    final good = <String>[];
    final fix = <String>[];
    var score = 0;

    if (s.isEmpty) {
      return const SentenceReport(0, [], ['Write a sentence first.']);
    }
    final tokens = s
        .toLowerCase()
        .split(RegExp(r"[^a-z\-']+"))
        .where((e) => e.isNotEmpty)
        .toList();
    final wl = w.word.toLowerCase();
    final stem = wl.length > 5 ? wl.substring(0, wl.length - 2) : wl;

    final uses = tokens.where((t) => t.startsWith(stem)).length;
    if (uses >= 1) {
      score += 40;
      good.add('You used "${w.word}".');
    } else {
      fix.add('Include the target word "${w.word}" (or a form of it).');
    }
    if (uses > 1) {
      fix.add('You repeated the target word. Use it once, naturally.');
    } else if (uses == 1) {
      score += 5;
    }

    final n = tokens.length;
    if (n >= 6 && n <= 30) {
      score += 15;
      good.add('Good length ($n words).');
    } else if (n < 6) {
      fix.add('Too short. Add context so the meaning is clear (6+ words).');
    } else {
      fix.add('Quite long ($n words). Split it for clarity.');
    }

    if (RegExp(r'^[A-Z]').hasMatch(s)) {
      score += 5;
    } else {
      fix.add('Start the sentence with a capital letter.');
    }
    if (RegExp(r'[.!?]$').hasMatch(s)) {
      score += 5;
    } else {
      fix.add('End the sentence with punctuation.');
    }

    if (w.example.isNotEmpty && _aiSimilarity(s, w.example) > .85) {
      fix.add('This is almost the same as the example. Write your own.');
    } else {
      score += 10;
    }

    if (tokens.any(_connectors.contains)) {
      score += 10;
      good.add('Nice sentence structure (uses a connecting word).');
    } else {
      fix.add('Add a connecting word such as because, although or which.');
    }

    final variety = n == 0 ? 0.0 : tokens.toSet().length / n;
    if (variety >= .7) {
      score += 10;
    } else {
      fix.add('Vary your words. Too many repeats.');
    }

    final synHit = w.synonyms.any((x) => tokens.contains(x.toLowerCase()));
    if (synHit && uses >= 1) {
      fix.add('Avoid defining the word with its own synonym; show it through context.');
      score -= 5;
    }
    return SentenceReport(score.clamp(0, 100), good, fix);
  }
}

// ------------------------------------------------------------------
// 7. AI HUB UI (5 tabs)
// ------------------------------------------------------------------

Widget _aiStat(IconData icon, String label, String value, Color color) {
  return Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    ),
  );
}

class AiHubPage extends StatefulWidget {
  final List<VocabularyWord> words;
  final List<AssessmentRecord> history;
  final double mastery;

  const AiHubPage({
    super.key,
    required this.words,
    required this.history,
    required this.mastery,
  });

  @override
  State<AiHubPage> createState() => _AiHubPageState();
}

class _AiHubPageState extends State<AiHubPage> {
  final TabController? _none = null; // DefaultTabController manages tabs
  final ValueNotifier<int> _tab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final study = context.read<StudyProvider>();
      final native = context.read<NativeProvider>();
      await study.load();
      study.attachWords(widget.words);
      unawaited(native.start());
    });
  }

  @override
  void didUpdateWidget(covariant AiHubPage old) {
    super.didUpdateWidget(old);
    if (!identical(old.words, widget.words)) {
      context.read<StudyProvider>().attachWords(widget.words);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Coach'),
          actions: [
            IconButton(
                tooltip: 'Sign out',
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout)),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.pink,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_customize), text: 'Coach'),
              Tab(icon: Icon(Icons.style), text: 'Review'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Tutor'),
              Tab(icon: Icon(Icons.edit_note), text: 'Sentence Lab'),
              Tab(icon: Icon(Icons.phone_android), text: 'Device'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CoachTab(
              history: widget.history,
              mastery: widget.mastery,
              onStartReview: () {
                final c = DefaultTabController.of(context);
                c.animateTo(1);
              },
            ),
            _ReviewTab(words: widget.words),
            _TutorTab(words: widget.words, mastery: widget.mastery),
            _SentenceTab(words: widget.words),
            const _DeviceTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------- Coach tab ----------------

class _CoachTab extends StatelessWidget {
  final List<AssessmentRecord> history;
  final double mastery;
  final VoidCallback onStartReview;
  const _CoachTab({
    required this.history,
    required this.mastery,
    required this.onStartReview,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StudyProvider>();
    final plan = s.dailyPlan(history, mastery);
    final insights = s.insights(history, mastery);
    final weak = s.weakWords(8);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BrandBanner(
          title: 'Your AI study coach',
          subtitle:
          '${s.words.length} words - spaced repetition - local ML - works offline',
        ),
        const SizedBox(height: 14),
        Row(children: [
          _aiStat(Icons.local_fire_department, 'Day streak', '${s.streak}',
              AppColors.pink),
          const SizedBox(width: 10),
          _aiStat(Icons.replay, 'Due now', '${s.dueCount}', AppColors.blue),
          const SizedBox(width: 10),
          _aiStat(Icons.workspace_premium, 'Mastered', '${s.masteredCount}',
              AppColors.pink),
        ]),
        const SizedBox(height: 14),
        _infoCard(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Daily goal',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Text('${s.reviewedToday} / ${s.dailyGoal}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: s.goalProgress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            Slider(
              value: s.dailyGoal.toDouble(),
              min: 3,
              max: 50,
              divisions: 47,
              label: '${s.dailyGoal}',
              onChanged: (v) => s.setGoal(v.round()),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: s.words.length < 4 ? null : onStartReview,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start today\'s review'),
              ),
            ),
          ],
        )),
        _secTitle(context, 'Today\'s plan'),
        for (final p in plan)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppColors.softBlue,
                    child: Icon(p.icon, color: AppColors.blue)),
                title: Text(p.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(p.detail),
                trailing: _pill('${p.minutes} min', AppColors.pink),
              ),
            ),
          ),
        _secTitle(context, 'AI insights'),
        for (final i in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Icon(i.icon, color: i.color),
                title: Text(i.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(i.body),
              ),
            ),
          ),
        if (weak.isNotEmpty) ...[
          _secTitle(context, 'Weak words'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final w in weak)
              Chip(
                avatar: const Icon(Icons.healing, size: 16),
                label: Text(w.word),
              ),
          ]),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Reset flashcard progress?'),
                content: const Text(
                    'Streak, intervals and due dates will be cleared. Test history is kept.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset')),
                ],
              ),
            );
            if (ok == true) {
              await s.resetProgress();
              if (context.mounted) _studioToast(context, 'Progress reset.');
            }
          },
          icon: const Icon(Icons.restart_alt, color: AppColors.pink),
          label: const Text('Reset flashcard progress'),
        ),
      ],
    );
  }
}

// ---------------- Review tab (SM-2 flashcards) ----------------

class _ReviewTab extends StatefulWidget {
  final List<VocabularyWord> words;
  const _ReviewTab({required this.words});

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab>
    with AutomaticKeepAliveClientMixin {
  List<VocabularyWord> queue = [];
  int idx = 0;
  bool revealed = false;
  bool started = false;
  int again = 0, good = 0;
  final Set<String> requeued = {};

  @override
  bool get wantKeepAlive => true;

  void _start() {
    final s = context.read<StudyProvider>();
    setState(() {
      queue = s.sessionQueue();
      idx = 0;
      revealed = false;
      started = true;
      again = 0;
      good = 0;
      requeued.clear();
    });
  }

  void _grade(int q) {
    final s = context.read<StudyProvider>();
    final w = queue[idx];
    s.review(w, q);
    if (q < 3) {
      again++;
      if (requeued.add(w.word)) queue.add(w); // see it once more this session
    } else {
      good++;
    }
    setState(() {
      idx++;
      revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = context.watch<StudyProvider>();

    if (!started) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        BrandBanner(
            title: 'Flashcard review',
            subtitle:
            '${s.dueCount} due - ${s.newCount} new - spaced repetition (SM-2)',
            height: 140),
        const SizedBox(height: 16),
        _infoCard(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How it works',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Rate how well you remembered each word. The AI schedules the next '
                    'review: easy words come back later, hard words come back sooner.',
                style: TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.words.length < 4 ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text('Start session (${s.dailyGoal} cards)'),
            ),
          ],
        )),
      ]);
    }

    if (idx >= queue.length) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        _infoCard(Column(children: [
          const Icon(Icons.emoji_events, size: 60, color: AppColors.pink),
          const SizedBox(height: 10),
          const Text('Session complete',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Remembered: $good   -   Forgot: $again',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          Text('Streak: ${s.streak} days',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.refresh),
              label: const Text('Another session')),
        ])),
      ]);
    }

    final w = queue[idx];
    final c = s.cardFor(w);
    final probe = c ?? CardState(w.word);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Expanded(
            child: LinearProgressIndicator(
                value: idx / queue.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Text('${idx + 1}/${queue.length}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => revealed = true),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  _pill(c?.stage ?? 'New', c == null ? AppColors.blue : AppColors.pink),
                  const SizedBox(height: 16),
                  Text(w.word,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 36, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    if (w.partsOfSpeech.isNotEmpty)
                      Chip(label: Text(w.partsOfSpeech)),
                    if (w.difficultCefrStyle.isNotEmpty)
                      Chip(label: Text(w.difficultCefrStyle)),
                  ]),
                  const SizedBox(height: 14),
                  if (!revealed)
                    const Text('Tap to reveal the answer',
                        style: TextStyle(color: AppColors.muted))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (w.definition.isNotEmpty) Text(w.definition),
                        if (w.meaning.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(w.meaning,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                        if (w.synonyms.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Synonyms: ${w.synonyms.take(5).join(', ')}',
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                        if (w.example.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('"${w.example}"',
                              style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!revealed)
          FilledButton.icon(
              onPressed: () => setState(() => revealed = true),
              icon: const Icon(Icons.visibility),
              label: const Text('Show answer'))
        else
          Row(children: [
            _rateButton('Again', 1, probe, AppColors.pink),
            const SizedBox(width: 8),
            _rateButton('Hard', 3, probe, AppColors.blue),
            const SizedBox(width: 8),
            _rateButton('Good', 4, probe, AppColors.blue),
            const SizedBox(width: 8),
            _rateButton('Easy', 5, probe, AppColors.pink),
          ]),
      ],
    );
  }

  Widget _rateButton(String label, int q, CardState probe, Color color) {
    final days = probe.previewInterval(q);
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => _grade(q),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${days}d',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

// ---------------- Tutor tab (chat) ----------------

class _TutorTab extends StatefulWidget {
  final List<VocabularyWord> words;
  final double mastery;
  const _TutorTab({required this.words, required this.mastery});

  @override
  State<_TutorTab> createState() => _TutorTabState();
}

class _TutorTabState extends State<_TutorTab>
    with AutomaticKeepAliveClientMixin {
  late TutorEngine engine;
  final List<TutorMessage> msgs = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool thinking = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    engine = TutorEngine(widget.words);
    msgs.add(const TutorMessage(
        'Hi, I am your vocabulary tutor. Ask about a word, say "quiz me", or ask for a study plan.',
        chips: ['Quiz me', 'Study plan', 'Word of the day']));
  }

  @override
  void didUpdateWidget(covariant _TutorTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.words, widget.words)) {
      engine = TutorEngine(widget.words);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || thinking) return;
    final due = context.read<StudyProvider>().dueCount;
    _input.clear();
    setState(() {
      msgs.add(TutorMessage(t, fromUser: true));
      thinking = true;
    });
    _toEnd();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final r = engine.reply(t, mastery: widget.mastery, due: due);
    setState(() {
      msgs.add(r);
      thinking = false;
    });
    _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lastChips = msgs.isNotEmpty && !msgs.last.fromUser ? msgs.last.chips : const <String>[];
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: msgs.length + (thinking ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= msgs.length) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              final m = msgs[i];
              return Align(
                alignment:
                m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .82),
                  decoration: BoxDecoration(
                    color: m.fromUser ? AppColors.blue : AppColors.softBlue,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SelectableText(m.text,
                      style: TextStyle(
                          height: 1.4,
                          color: m.fromUser ? Colors.white : AppColors.text)),
                ),
              );
            },
          ),
        ),
        if (lastChips.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in lastChips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                        label: Text(c), onPressed: () => _send(c)),
                  ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask about a word...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _send(_input.text),
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------- Sentence Lab tab ----------------

class _SentenceTab extends StatefulWidget {
  final List<VocabularyWord> words;
  const _SentenceTab({required this.words});

  @override
  State<_SentenceTab> createState() => _SentenceTabState();
}

class _SentenceTabState extends State<_SentenceTab> {
  final _input = TextEditingController();
  final Random _r = Random();
  VocabularyWord? word;
  SentenceReport? report;

  @override
  void initState() {
    super.initState();
    _pick();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _pick() {
    if (widget.words.isEmpty) return;
    setState(() {
      word = widget.words[_r.nextInt(widget.words.length)];
      report = null;
      _input.clear();
    });
  }

  void _check() {
    final w = word;
    if (w == null) return;
    FocusScope.of(context).unfocus();
    final r = SentenceCoach.analyze(w, _input.text);
    setState(() => report = r);
    unawaited(NativeBridge.haptic(r.score >= 70 ? 'success' : 'medium'));
  }

  @override
  Widget build(BuildContext context) {
    final w = word;
    if (w == null) {
      return const Center(child: Text('No vocabulary available.'));
    }
    final r = report;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoCard(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WRITE A SENTENCE USING',
                style: TextStyle(color: AppColors.muted, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(w.word,
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pink)),
            const SizedBox(height: 4),
            Text(w.meaning.isNotEmpty ? w.meaning : w.definition,
                style: const TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'Type your sentence here...',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                    onPressed: _check,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Analyze')),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.shuffle, color: AppColors.pink),
                  label: const Text('New word')),
            ]),
          ],
        )),
        if (r != null) ...[
          const SizedBox(height: 14),
          _infoCard(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(fit: StackFit.expand, children: [
                    CircularProgressIndicator(
                        value: r.score / 100,
                        strokeWidth: 7,
                        color: r.score >= 70 ? AppColors.blue : AppColors.pink),
                    Center(
                        child: Text('${r.score}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18))),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(r.verdict,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ]),
              if (r.good.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final g in r.good)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle, color: AppColors.blue),
                    title: Text(g),
                  ),
              ],
              if (r.fix.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final f in r.fix)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lightbulb_outline,
                        color: AppColors.pink),
                    title: Text(f),
                  ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<StudyProvider>().review(
                      w, r.score >= 85 ? 5 : (r.score >= 70 ? 4 : (r.score >= 50 ? 3 : 1)));
                  _studioToast(context, 'Counted as a flashcard review.');
                },
                icon: const Icon(Icons.style, color: AppColors.pink),
                label: const Text('Count as a review'),
              ),
            ],
          )),
        ],
        if (w.example.isNotEmpty) ...[
          _secTitle(context, 'Model example'),
          _infoCard(Text('"${w.example}"',
              style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4))),
        ],
      ],
    );
  }
}

// ---------------- Device tab (Method + Event channel demo) ----------------

class _DeviceTab extends StatelessWidget {
  const _DeviceTab();

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NativeProvider>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoCard(Row(children: [
          const BrandAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(FirebaseAuth.instance.currentUser?.email ?? 'Student',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _pill(
                    n.nativeAvailable ? 'Native channel: connected' : 'Native channel: fallback',
                    n.nativeAvailable ? AppColors.blue : AppColors.pink),
              ],
            ),
          ),
        ])),
        _secTitle(context, 'Method channel'),
        _infoCard(Column(children: [
          _kv('Channel', 'com.vocabai/native'),
          _kv('Battery', n.battery == null ? 'not available' : '${n.battery}%${n.charging ? ' (charging)' : ''}'),
          for (final e in n.device.entries) _kv(e.key, '${e.value}'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: n.refreshBattery,
              icon: const Icon(Icons.battery_full),
              label: const Text('Battery'),
            ),
            OutlinedButton.icon(
              onPressed: () => NativeBridge.haptic('medium'),
              icon: const Icon(Icons.vibration, color: AppColors.pink),
              label: const Text('Haptic'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await NativeBridge.shareText(
                    'I am learning vocabulary with Vocabulary AI-ML!');
                if (!ok) {
                  await Share.share(
                      'I am learning vocabulary with Vocabulary AI-ML!');
                }
              },
              icon: const Icon(Icons.share, color: AppColors.blue),
              label: const Text('Share'),
            ),
          ]),
        ])),
        _secTitle(context, 'Event channel'),
        _infoCard(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Channel', 'com.vocabai/events'),
            const SizedBox(height: 8),
            if (n.eventLog.isEmpty)
              const Text('No events yet.',
                  style: TextStyle(color: AppColors.muted))
            else
              for (final l in n.eventLog.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11.5)),
                ),
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: n.clearLog,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear log')),
          ],
        )),
        const SizedBox(height: 12),
        const Text(
          'Android handler: see MainActivity.kt. Without it, the app uses Dart fallbacks, '
              'so nothing breaks.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

// ============================================================================
//  THE 5 EDITS TO YOUR EXISTING main.dart
// ============================================================================
//
// pubspec.yaml ->  dependencies:  provider: ^6.1.2   (then: flutter pub get)
//
// (1) Imports, add near the top:
//       import 'package:provider/provider.dart';
//
// (2) In main(), replace the last line
//       runApp(const VocabularyAIApp());
//     with
//       runApp(MultiProvider(
//         providers: AppProviders.build(),
//         child: const VocabularyAIApp(),
//       ));
//
// (3) In _VocabularyHomeState._nav, add AFTER the 'Studio' item:
//       _NavItem('AI Coach', Icons.auto_awesome_outlined, Icons.auto_awesome),
//
// (4) In the `pages` list inside build(), add AFTER StudioHubPage(...),:
//       AiHubPage(words: words, history: history, mastery: currentMastery),
//
// (5) Optional: show the pink/blue network banner on the Dashboard. In
//     DashboardPage.build(), inside the ListView children, before _hero():
//       const BrandBanner(
//         title: 'Learn. Speak. Master.',
//         subtitle: 'Pink + blue vocabulary hub',
//         height: 150,
//       ),
//       const SizedBox(height: 16),
//
// Android release builds also need  <uses-permission android:name="android.permission.INTERNET"/>
// (network images) in android/app/src/main/AndroidManifest.xml.