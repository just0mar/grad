import 'package:file_picker/file_picker.dart';

class Announcement {
  final String id;
  final String authorName;
  final String authorRole;
  final String authorImage;
  final String? authorUserId;
  final String caption;
  final String? imageUrl;
  final PlatformFile? image;
  final String priority;
  final bool isEmergency;

  Announcement({
    this.id = '',
    required this.authorName,
    required this.authorRole,
    required this.authorImage,
    this.authorUserId,
    required this.caption,
    this.imageUrl,
    this.image,
    String? priority,
    bool? isEmergency,
  }) : priority = priority ?? (isEmergency == true ? 'Urgent' : 'Normal'),
       isEmergency =
           isEmergency ?? (priority ?? 'Normal').toLowerCase() == 'urgent';

  bool get isImportant => priority.toLowerCase() == 'important';
  bool get isUrgent => priority.toLowerCase() == 'urgent' || isEmergency;

  Announcement copyWith({
    String? id,
    String? authorName,
    String? authorRole,
    String? authorImage,
    String? authorUserId,
    String? caption,
    String? imageUrl,
    PlatformFile? image,
    String? priority,
    bool? isEmergency,
    bool clearImageUrl = false,
  }) {
    return Announcement(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorImage: authorImage ?? this.authorImage,
      authorUserId: authorUserId ?? this.authorUserId,
      caption: caption ?? this.caption,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      image: image ?? this.image,
      priority: priority ?? this.priority,
      isEmergency: isEmergency ?? this.isEmergency,
    );
  }
}
