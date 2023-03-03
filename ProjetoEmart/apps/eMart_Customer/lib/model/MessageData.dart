import 'package:cloud_firestore/cloud_firestore.dart';

class MessageData {
  String messageID;

  Url url;

  String content;

  Timestamp created;

  String recipientFirstName;

  String recipientLastName;

  String recipientProfilePictureURL;

  String recipientID;

  String senderFirstName;

  String senderLastName;

  String senderProfilePictureURL;

  String senderID;

  String videoThumbnail;

  MessageData(
      {this.messageID = '',
      url,
      this.content = '',
      created,
      this.recipientFirstName = '',
      this.recipientLastName = '',
      this.recipientProfilePictureURL = '',
      this.recipientID = '',
      this.senderFirstName = '',
      this.senderLastName = '',
      this.senderProfilePictureURL = '',
      this.senderID = '',
      this.videoThumbnail = ''})
      : url = url ?? Url(),
        created = created ?? Timestamp.now();

  factory MessageData.fromJson(Map<String, dynamic> parsedJson) {
    return MessageData(
        messageID: parsedJson['id'] ?? parsedJson['messageID'] ?? '',
        url: parsedJson.containsKey('url') ? Url.fromJson(parsedJson['url']) : Url(),
        content: parsedJson['content'] ?? '',
        created: parsedJson['createdAt'] ?? parsedJson['created'] ?? Timestamp.now(),
        recipientFirstName: parsedJson['recipientFirstName'] ?? '',
        recipientLastName: parsedJson['recipientLastName'] ?? '',
        recipientProfilePictureURL: parsedJson['recipientProfilePictureURL'] ?? '',
        recipientID: parsedJson['recipientID'] ?? '',
        senderFirstName: parsedJson['senderFirstName'] ?? '',
        senderLastName: parsedJson['senderLastName'] ?? '',
        senderProfilePictureURL: parsedJson['senderProfilePictureURL'] ?? '',
        senderID: parsedJson['senderID'] ?? '',
        videoThumbnail: parsedJson['videoThumbnail'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': messageID,
      'url': url.toJson(),
      'content': content,
      'createdAt': created,
      'recipientFirstName': recipientFirstName,
      'recipientLastName': recipientLastName,
      'recipientProfilePictureURL': recipientProfilePictureURL,
      'recipientID': recipientID,
      'senderFirstName': senderFirstName,
      'senderLastName': senderLastName,
      'senderProfilePictureURL': senderProfilePictureURL,
      'senderID': senderID,
      'videoThumbnail': videoThumbnail
    };
  }
}

class Url {
  String mime;

  String url;

  String? videoThumbnail;

  Url({this.mime = '', this.url = '', this.videoThumbnail});

  factory Url.fromJson(Map<dynamic, dynamic> parsedJson) {
    return Url(mime: parsedJson['mime'] ?? '', url: parsedJson['url'] ?? '', videoThumbnail: parsedJson['videoThumbnail'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'mime': mime, 'url': url, 'videoThumbnail': videoThumbnail};
  }
}
