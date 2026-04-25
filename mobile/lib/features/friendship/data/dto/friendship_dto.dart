import 'package:production_chat_app/features/friendship/domain/entities/friend_relationship.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_user_profile.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friendship_status.dart';

class FriendshipRelationshipDto {
  const FriendshipRelationshipDto({
    required this.status,
    required this.pendingRequestId,
    required this.canMessage,
  });

  factory FriendshipRelationshipDto.fromJson(Map<String, dynamic> json) {
    return FriendshipRelationshipDto(
      status: FriendshipStatusX.fromWireValue(
        json['status']?.toString() ?? 'none',
      ),
      pendingRequestId: json['pendingRequestId']?.toString(),
      canMessage: json['canMessage'] as bool? ?? false,
    );
  }

  final FriendshipStatus status;
  final String? pendingRequestId;
  final bool canMessage;

  FriendRelationship toEntity() {
    return FriendRelationship(
      status: status,
      pendingRequestId: pendingRequestId,
      canMessage: canMessage,
    );
  }
}

class FriendUserProfileDto {
  const FriendUserProfileDto({
    required this.id,
    required this.nickname,
    required this.handle,
    required this.avatarUrl,
  });

  factory FriendUserProfileDto.fromJson(Map<String, dynamic> json) {
    return FriendUserProfileDto(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  final String id;
  final String nickname;
  final String handle;
  final String? avatarUrl;

  FriendUserProfile toEntity() {
    return FriendUserProfile(
      id: id,
      nickname: nickname,
      handle: handle,
      avatarUrl: avatarUrl,
    );
  }
}

class FriendSummaryDto {
  const FriendSummaryDto({
    required this.friendUserId,
    required this.createdAt,
    required this.profile,
  });

  factory FriendSummaryDto.fromJson(Map<String, dynamic> json) {
    return FriendSummaryDto(
      friendUserId: json['friendUserId']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime(1970).toIso8601String(),
      ).toLocal(),
      profile: FriendUserProfileDto.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String friendUserId;
  final DateTime createdAt;
  final FriendUserProfileDto profile;

  FriendSummary toEntity() {
    return FriendSummary(
      friendUserId: friendUserId,
      createdAt: createdAt,
      profile: profile.toEntity(),
    );
  }
}

class FriendRequestSummaryDto {
  const FriendRequestSummaryDto({
    required this.id,
    required this.direction,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.respondedAt,
    required this.counterparty,
  });

  factory FriendRequestSummaryDto.fromJson(Map<String, dynamic> json) {
    return FriendRequestSummaryDto(
      id: json['id']?.toString() ?? '',
      direction: json['direction']?.toString() == 'incoming'
          ? FriendRequestDirection.incoming
          : FriendRequestDirection.outgoing,
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString(),
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime(1970).toIso8601String(),
      ).toLocal(),
      respondedAt: json['respondedAt'] == null
          ? null
          : DateTime.parse(json['respondedAt']!.toString()).toLocal(),
      counterparty: FriendUserProfileDto.fromJson(
        json['counterparty'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String id;
  final FriendRequestDirection direction;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final FriendUserProfileDto counterparty;

  FriendRequestSummary toEntity() {
    return FriendRequestSummary(
      id: id,
      direction: direction,
      status: status,
      message: message,
      createdAt: createdAt,
      respondedAt: respondedAt,
      counterparty: counterparty.toEntity(),
    );
  }
}
