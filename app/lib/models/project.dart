import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  const Project({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.roomType,
    required this.status,
    this.coverPhotoUrl,
    this.isFavorite = false,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String roomType;
  final String status; // scanned | analyzed | designed | archived
  final String? coverPhotoUrl;
  final bool isFavorite;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'name': name,
        'roomType': roomType,
        'status': status,
        if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
        'isFavorite': isFavorite,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? {};
    return Project(
      id: doc.id,
      ownerId: j['ownerId'] as String? ?? '',
      name: j['name'] as String? ?? 'Untitled',
      roomType: j['roomType'] as String? ?? 'other',
      status: j['status'] as String? ?? 'scanned',
      coverPhotoUrl: j['coverPhotoUrl'] as String?,
      isFavorite: j['isFavorite'] as bool? ?? false,
      updatedAt: (j['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
