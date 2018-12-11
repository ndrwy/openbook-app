import 'package:Openbook/models/circles_list.dart';
import 'package:Openbook/models/follows_lists_list.dart';
import 'package:Openbook/models/updatable_model.dart';
import 'package:Openbook/models/user_profile.dart';
import 'package:dcache/dcache.dart';

class User extends UpdatableModel<User> {
  int id;
  String email;
  String username;
  UserProfile profile;
  int followersCount;
  int followingCount;
  int postsCount;
  bool isFollowing;
  bool isConnected;
  CirclesList connectedCircles;
  FollowsListsList followLists;

  static final navigationUsersFactory = UserFactory(
      cache: LfuCache<int, User>(storage: SimpleStorage(size: 100)));
  static final sessionUsersFactory = UserFactory(
      cache: SimpleCache<int, User>(storage: SimpleStorage(size: 10)));

  factory User.fromJson(Map<String, dynamic> json,
      {bool storeInSessionCache = false}) {
    int userId = json['id'];

    User user = navigationUsersFactory.getItemWithIdFromCache(userId) ??
        sessionUsersFactory.getItemWithIdFromCache(userId);

    if (user != null) {
      user.update(json);
      return user;
    }
    return storeInSessionCache
        ? sessionUsersFactory.fromJson(json)
        : navigationUsersFactory.fromJson(json);
  }

  static void clearNavigationCache() {
    navigationUsersFactory.clearCache();
  }

  static void clearSessionCache() {
    sessionUsersFactory.clearCache();
  }

  User(
      {this.id,
      this.username,
      this.email,
      this.profile,
      this.followersCount,
      this.followingCount,
      this.postsCount,
      this.isFollowing,
      this.isConnected});

  void updateFromJson(Map json) {
    if (json.containsKey('username')) username = json['username'];
    if (json.containsKey('email')) email = json['email'];
    if (json.containsKey('profile')) {
      if (profile != null) {
        profile.updateFromJson(json['profile']);
      } else {
        profile = navigationUsersFactory.parseUserProfile(json['profile']);
      }
    }
    if (json.containsKey('followers_count'))
      followersCount = json['followers_count'];
    if (json.containsKey('following_count'))
      followingCount = json['following_count'];
    if (json.containsKey('posts_count')) postsCount = json['posts_count'];
    if (json.containsKey('is_following')) isFollowing = json['is_following'];
    if (json.containsKey('is_connected')) isConnected = json['is_connected'];
  }

  bool hasProfileLocation() {
    return profile.hasLocation();
  }

  bool hasProfileUrl() {
    return profile.hasUrl();
  }

  String getProfileAvatar() {
    return this.profile.avatar;
  }

  String getProfileName() {
    return this.profile.name;
  }

  String getProfileCover() {
    return this.profile.cover;
  }

  String getProfileBio() {
    return this.profile.bio;
  }

  DateTime getProfileBirthDate() {
    return profile.birthDate;
  }

  bool getProfileFollowersCountVisible() {
    return this.profile.followersCountVisible;
  }

  String getProfileUrl() {
    return this.profile.url;
  }

  String getProfileLocation() {
    return this.profile.location;
  }

  void incrementFollowersCount() {
    if (this.followersCount != null) {
      this.followersCount += 1;
      notifyUpdate();
    }
  }

  void decrementFollowersCount() {
    if (this.followersCount != null) {
      this.followersCount -= 1;
      notifyUpdate();
    }
  }
}

class UserFactory extends UpdatableModelFactory<User> {
  UserFactory({cache}) : super(cache: cache);

  @override
  User makeFromJson(Map json) {
    return User(
        id: json['id'],
        followersCount: json['followers_count'],
        postsCount: json['posts_count'],
        email: json['email'],
        username: json['username'],
        followingCount: json['following_count'],
        isFollowing: json['is_following'],
        isConnected: json['is_connected'],
        profile: parseUserProfile(json['profile']));
  }

  UserProfile parseUserProfile(Map profile) {
    return UserProfile.fromJSON(profile);
  }
}
