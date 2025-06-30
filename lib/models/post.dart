import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String description;
  final String uid;
  final String username;
  final List<dynamic> rate;
  final String postId;
  final DateTime datePublished;
  final String postUrl;
  final String profImage;
  final String region;
  final int age;
  final String gender;

  const Post({
    required this.description,
    required this.uid,
    required this.username,
    required this.rate,
    required this.postId,
    required this.datePublished,
    required this.postUrl,
    required this.profImage,
    required this.region,
    required this.age,
    required this.gender,
  });

  static Post fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;

    Timestamp timestamp = snapshot["datePublished"];
    DateTime datePublished = timestamp.toDate();

    return Post(
      description: snapshot["description"] ?? '',
      uid: snapshot["uid"] ?? '',
      rate: snapshot["rate"] ?? [],
      postId: snapshot["postId"] ?? '',
      datePublished: datePublished,
      username: snapshot["username"] ?? 'Unknown',
      postUrl: snapshot['postUrl'] ?? '',
      profImage: snapshot['profImage'] ?? '',
      region: snapshot['region'] ?? '',
      age: snapshot['age'] as int? ?? 0,
      gender: snapshot['gender'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        "description": description,
        "uid": uid,
        "rate": rate,
        "username": username,
        "postId": postId,
        "datePublished": datePublished,
        'postUrl': postUrl,
        'profImage': profImage,
        'region': region,
        'age': age,
        'gender': gender,
      };
}
