class FacePhoto {
  final String id;
  final String imagePath;
  final List<String> recognizedPeople;
  final DateTime createdAt;

  FacePhoto({
    required this.id,
    required this.imagePath,
    required this.recognizedPeople,
    required this.createdAt,
  });
}