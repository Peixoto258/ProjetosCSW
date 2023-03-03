import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  String id;

  String creatorId;
  String lastMessage;

  String name;

  Timestamp lastMessageDate;

  ConversationModel({this.id = '', this.creatorId = '', this.lastMessage = '', this.name = '', lastMessageDate}) : lastMessageDate = lastMessageDate ?? Timestamp.now();

  factory ConversationModel.fromJson(Map<String, dynamic> parsedJson) {
    return ConversationModel(
        id: parsedJson['id'] ?? '',
        creatorId: parsedJson['creatorID'] ?? parsedJson['creator_id'] ?? '',
        lastMessage: parsedJson['lastMessage'] ?? '',
        name: parsedJson['name'] ?? '',
        lastMessageDate: parsedJson['lastMessageDate'] ?? Timestamp.now());
  }

  factory ConversationModel.fromPayload(Map<String, dynamic> parsedJson) {
    return ConversationModel(
        id: parsedJson['id'] ?? '',
        creatorId: parsedJson['creatorID'] ?? parsedJson['creator_id'] ?? '',
        lastMessage: parsedJson['lastMessage'] ?? '',
        name: parsedJson['name'] ?? '',
        lastMessageDate: Timestamp.fromMillisecondsSinceEpoch(parsedJson['lastMessageDate']));
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'creatorID': creatorId, 'lastMessage': lastMessage, 'name': name, 'lastMessageDate': lastMessageDate};
  }

  Map<String, dynamic> toPayload() {
    return {'id': id, 'creatorID': creatorId, 'lastMessage': lastMessage, 'name': name, 'lastMessageDate': lastMessageDate.millisecondsSinceEpoch};
  }
}
