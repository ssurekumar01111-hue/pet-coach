import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exam_config.dart';
import '../models/run_session.dart';

class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection('sessions');
  CollectionReference<Map<String, dynamic>> get _examConfigs =>
      _firestore.collection('exam_configs');

  Stream<List<ExamConfig>> watchExamConfigs() => _examConfigs.snapshots().map(
        (snapshot) => snapshot.docs.map(ExamConfig.fromFirestore).toList(),
      );
  Future<List<ExamConfig>> getExamConfigs() async =>
      (await _examConfigs.get()).docs.map(ExamConfig.fromFirestore).toList();
  Future<void> updateUserProfile(String uid, Map<String, dynamic> profile) =>
      _users.doc(uid).set({'profile': profile}, SetOptions(merge: true));
  Future<void> setExamTarget(String uid, String examId) =>
      _users.doc(uid).set({'examTarget': examId}, SetOptions(merge: true));
  Future<void> createSession(RunSession session) =>
      _sessions.doc(session.id).set(session.toMap());
  Future<void> updateSession(RunSession session) =>
      _sessions.doc(session.id).update(session.toMap());
  Future<RunSession?> getSession(String sessionId) async {
    final doc = await _sessions.doc(sessionId).get();
    return doc.exists ? RunSession.fromFirestore(doc) : null;
  }

  Stream<List<RunSession>> watchUserSessions(String uid) => _sessions
      .where('uid', isEqualTo: uid)
      .orderBy('startTime', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(RunSession.fromFirestore).toList());
}
