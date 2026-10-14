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

  /// Row of the `projects` table (snake_case columns).
  factory Project.fromRow(Map<String, dynamic> j) {
    return Project(
      id: j['id'] as String,
      ownerId: j['owner_id'] as String? ?? '',
      name: j['name'] as String? ?? 'Untitled',
      roomType: j['room_type'] as String? ?? 'other',
      status: j['status'] as String? ?? 'scanned',
      coverPhotoUrl: j['cover_photo_url'] as String?,
      isFavorite: j['is_favorite'] as bool? ?? false,
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal(),
    );
  }
}
