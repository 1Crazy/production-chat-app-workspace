enum FriendshipStatus {
  self,
  none,
  outgoingPending,
  incomingPending,
  friends,
}

extension FriendshipStatusX on FriendshipStatus {
  static FriendshipStatus fromWireValue(String rawValue) {
    switch (rawValue) {
      case 'self':
        return FriendshipStatus.self;
      case 'outgoing_pending':
        return FriendshipStatus.outgoingPending;
      case 'incoming_pending':
        return FriendshipStatus.incomingPending;
      case 'friends':
        return FriendshipStatus.friends;
      case 'none':
      default:
        return FriendshipStatus.none;
    }
  }
}
