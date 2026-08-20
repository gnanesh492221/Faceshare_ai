class ReceivedPhoto {
  final String id;
  final String imagePath;
  final String senderName;
  final String senderUid;
  final DateTime receivedAt;
  final bool isRead;

  const ReceivedPhoto({
    required this.id,
    required this.imagePath,
    required this.senderName,
    required this.senderUid,
    required this.receivedAt,
    this.isRead = false,
  });

  ReceivedPhoto copyWith({
    String? id,
    String? imagePath,
    String? senderName,
    String? senderUid,
    DateTime? receivedAt,
    bool? isRead,
  }) {
    return ReceivedPhoto(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      senderName: senderName ?? this.senderName,
      senderUid: senderUid ?? this.senderUid,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() {
    return 'ReceivedPhoto('
        'id: $id, '
        'imagePath: $imagePath, '
        'senderName: $senderName, '
        'senderUid: $senderUid, '
        'receivedAt: $receivedAt, '
        'isRead: $isRead'
        ')';
  }
}