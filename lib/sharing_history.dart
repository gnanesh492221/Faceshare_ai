class SharingHistory {
  final String id;
  final String imagePath;
  final List<String> sharedWith;
  final DateTime createdAt;

  SharingHistory({
    required this.id,
    required this.imagePath,
    required this.sharedWith,
    required this.createdAt,
  });
}