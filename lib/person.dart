class Person {
  final String id;
  final String name;
  final String imagePath;

  /// Face embedding generated during registration.
  final List<double> faceEmbedding;

  /// Firebase Auth / FaceShare account ID.
  final String faceShareUserId;

  /// Whether this profile can receive shared photos.
  final bool sharingEnabled;

  const Person({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.faceEmbedding,
    required this.faceShareUserId,
    required this.sharingEnabled,
  });

  Person copyWith({
    String? id,
    String? name,
    String? imagePath,
    List<double>? faceEmbedding,
    String? faceShareUserId,
    bool? sharingEnabled,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      faceShareUserId:
          faceShareUserId ?? this.faceShareUserId,
      sharingEnabled:
          sharingEnabled ?? this.sharingEnabled,
    );
  }

  bool get hasFaceEmbedding =>
      faceEmbedding.isNotEmpty;

  bool get canReceivePhotos =>
      sharingEnabled &&
      faceShareUserId.isNotEmpty;

  String get sharingStatus {
    if (!sharingEnabled) {
      return 'Sharing disabled';
    }

    if (faceShareUserId.isEmpty) {
      return 'Profile unavailable';
    }

    return 'Ready to receive';
  }

  @override
  String toString() {
    return 'Person('
        'id: $id, '
        'name: $name, '
        'faceShareUserId: $faceShareUserId, '
        'sharingEnabled: $sharingEnabled'
        ')';
  }
}