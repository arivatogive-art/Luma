// Pfad: lib/presentation/screens/profile_screen.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../features/pages/application/page_controller.dart' as luma_pages;
import '../../features/pages/application/page_visibility_policy.dart';
import '../../features/pages/domain/models/page_model.dart';
import '../../features/pages/presentation/screens/internal_page_detail_screen.dart';
import '../../application/messenger_controller.dart';
import '../../application/messenger_remote_mode.dart';
import '../../application/profile_friendship_notifier.dart';
import '../../data/friendship_repository.dart';
import '../../data/profile_moment_repository.dart';
import '../../data/profile_photo_repository.dart';
import '../../data/profile_report_repository.dart';
import '../../data/profile_storage_repository.dart';
import '../../data/user_profile_repository.dart';
import '../../domain/models/friendship_model.dart';
import '../../domain/models/chat_model.dart';
import '../../domain/models/luma_user_profile_model.dart';
import '../../domain/models/private_profile_model.dart';
import '../../domain/models/profile_moment_comment_model.dart';
import '../../domain/models/profile_moment_model.dart';
import '../../domain/models/profile_photo_model.dart';
import '../../domain/models/profile_privacy_model.dart';
import '../../domain/models/profile_relationship_status.dart';
import '../widgets/profile_info_sheet.dart';
import '../widgets/profile_account_overview_dialog.dart';
import '../widgets/profile_create_post_card.dart';
import '../widgets/profile_action_bar_card.dart';
import '../widgets/profile_friends_preview_card.dart' as profile_friends;
import '../widgets/profile_friend_picker_dialog.dart';
import '../widgets/profile_create_moment_dialog.dart';
import '../widgets/profile_edit_moment_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_identity_helpers.dart';
import '../widgets/profile_external_url_helper.dart';
import '../widgets/profile_feedback_helper.dart';
import '../widgets/profile_display_name_helper.dart';
import '../widgets/profile_moment_sheet_state_builders.dart';
import '../widgets/profile_media_source_sheet.dart';
import '../widgets/profile_website_sheet.dart';
import '../widgets/profile_options_sheet.dart';
import '../widgets/profile_photo_widgets.dart';
import '../widgets/profile_photo_preview_builder.dart';
import '../widgets/profile_photos_sheet.dart';
import '../widgets/profile_block_state.dart';
import '../widgets/profile_report_safety_sheets.dart';
import '../widgets/profile_screen_support_widgets.dart';
import '../widgets/profile_posts_sheet.dart';
import '../widgets/profile_posts_preview_card.dart' as profile_posts;
import '../widgets/profile_tagged_friend_resolver.dart';
import '../widgets/profile_timeline_section.dart';
import '../widgets/profile_utils.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'friends_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isOwnProfile;
  final String? userId;

  const ProfileScreen({
    super.key,
    this.isOwnProfile = true,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileFriendshipNotifier _friendshipNotifier;
  late final MessengerController _messengerController;
  late final UserProfileRepository _userProfileRepository;
  late final FriendshipRepository _friendshipRepository;
  late final ProfileMomentRepository _profileMomentRepository;
  late final ProfilePhotoRepository _profilePhotoRepository;
  late final ProfileReportRepository _profileReportRepository;
  late final ProfileStorageRepository _profileStorageRepository;
  late final FirebaseAuth _firebaseAuth;
  late final luma_pages.PageController _pageController;

  PrivateProfileModel _profile = PrivateProfileModel.empty();

  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription<List<ProfileMomentModel>>? _profileMomentsSubscription;
  StreamSubscription<List<ProfilePhotoModel>>? _profilePhotosSubscription;

  bool _isLoadingProfile = true;
  bool _isLoadingMoments = false;
  bool _isUploadingProfileImage = false;
  bool _isUploadingCoverImage = false;
  bool _isOpeningMessageConversation = false;
  bool _isBlockedByMe = false;
  bool _isBlockedBetweenUsers = false;
  bool _isUpdatingBlockStatus = false;
  String? _profileLoadError;
  String? _momentError;
  String _currentAuthUserId = '';
  String _currentViewedUserId = '';

  List<PrivateProfileModel> _firebaseFriends = const <PrivateProfileModel>[];
  List<PrivateProfileModel> _mutualFriends = const <PrivateProfileModel>[];
  List<profile_posts.ProfileMomentPreviewData> _profileMoments =
      const <profile_posts.ProfileMomentPreviewData>[];
  List<ProfilePhotoModel> _profilePhotos = const <ProfilePhotoModel>[];

  bool get _isViewingOwnProfile {
    final cleanWidgetUserId = widget.userId?.trim();

    if (_currentAuthUserId.isEmpty) {
      return widget.isOwnProfile;
    }

    if (cleanWidgetUserId != null && cleanWidgetUserId.isNotEmpty) {
      return cleanWidgetUserId == _currentAuthUserId;
    }

    return widget.isOwnProfile;
  }

  @override
  void initState() {
    super.initState();

    _firebaseAuth = FirebaseAuth.instance;
    _messengerController = MessengerController.instance;
    _userProfileRepository = UserProfileRepository();
    _friendshipRepository = FriendshipRepository();
    _profileMomentRepository = ProfileMomentRepository();
    _profilePhotoRepository = ProfilePhotoRepository();
    _profileReportRepository = ProfileReportRepository();
    _profileStorageRepository = ProfileStorageRepository();
    _pageController = luma_pages.PageController(
      visibilityPolicy: PageVisibilityPolicy.visibleForDeveloper,
    );

    _friendshipNotifier = ProfileFriendshipNotifier()
      ..addListener(_handleFriendshipChanged);

    _initializeProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOwnProfile != widget.isOwnProfile ||
        oldWidget.userId != widget.userId) {
      _firebaseFriends = const <PrivateProfileModel>[];
      _mutualFriends = const <PrivateProfileModel>[];
      _profileMoments = const <profile_posts.ProfileMomentPreviewData>[];
      _profilePhotos = const <ProfilePhotoModel>[];
      _isBlockedByMe = false;
      _isBlockedBetweenUsers = false;
      _profileMomentsSubscription?.cancel();
      _profilePhotosSubscription?.cancel();
      _profileMomentsSubscription = null;
      _profilePhotosSubscription = null;
      _initializeProfile(notify: true);
    }
  }

  @override
  void dispose() {
    _profileMomentsSubscription?.cancel();
    _profilePhotosSubscription?.cancel();

    _friendshipNotifier
      ..removeListener(_handleFriendshipChanged)
      ..dispose();

    _pageController.dispose();

    super.dispose();
  }

  void _handleFriendshipChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _initializeProfile({bool notify = false}) async {
    final authUser = _firebaseAuth.currentUser;
    final authUserId = authUser?.uid.trim() ?? '';

    if (notify && mounted) {
      setState(() {
        _isLoadingProfile = true;
        _profileLoadError = null;
        _momentError = null;
      });
    }

    _currentAuthUserId = authUserId;
    unawaited(_pageController.loadInternalPages());

    if (authUserId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
        _isLoadingMoments = false;
        _profileLoadError =
            'Melde dich an, um dein Profil zu laden.';
        _profile = PrivateProfileModel.empty();
        _firebaseFriends = const <PrivateProfileModel>[];
        _mutualFriends = const <PrivateProfileModel>[];
        _profileMoments = const <profile_posts.ProfileMomentPreviewData>[];
        _profilePhotos = const <ProfilePhotoModel>[];
        _isBlockedByMe = false;
        _isBlockedBetweenUsers = false;
      });
      return;
    }

    final viewedUserId = _resolveViewedUserId(authUserId);
    final isOwnProfile = viewedUserId == authUserId;

    _currentViewedUserId = viewedUserId;

    try {
      final LumaUserProfileModel? firebaseProfile;

      if (isOwnProfile) {
        firebaseProfile = await _userProfileRepository.createProfileIfMissing(
          userId: authUserId,
          displayName: authUser?.displayName ??
              ProfileIdentityHelpers.nameFromEmail(authUser?.email),
          username: ProfileIdentityHelpers.usernameFromEmail(authUser?.email),
          email: authUser?.email,
          avatarUrl: authUser?.photoURL,
        );

        _friendshipNotifier.reset();
      } else {
        firebaseProfile = await _userProfileRepository.fetchProfile(
          userId: viewedUserId,
        );

        _friendshipNotifier.initialize(
          currentUserId: authUserId,
          viewedUserId: viewedUserId,
        );
      }

      if (!mounted) return;

      if (firebaseProfile == null) {
        setState(() {
          _isLoadingProfile = false;
          _isLoadingMoments = false;
          _profileLoadError =
              'Dieses Profil wurde nicht gefunden.';
          _profile = PrivateProfileModel.empty().copyWith(
            id: viewedUserId,
            displayName: 'Unbekanntes Profil',
            username: 'unknown',
            isOwnProfile: false,
          );
          _firebaseFriends = const <PrivateProfileModel>[];
          _mutualFriends = const <PrivateProfileModel>[];
          _profileMoments = const <profile_posts.ProfileMomentPreviewData>[];
          _isBlockedByMe = false;
          _isBlockedBetweenUsers = false;
        });
        return;
      }

      List<PrivateProfileModel> firebaseFriends =
          const <PrivateProfileModel>[];
      List<PrivateProfileModel> mutualFriends =
          const <PrivateProfileModel>[];

      try {
        firebaseFriends = await _loadFirebaseFriendsForProfile(
          viewedUserId,
          isOwnProfile: isOwnProfile,
        );
      } catch (error) {
        debugPrint('Luma optional profile friends load warning: $error');
      }

      if (!isOwnProfile) {
        try {
          mutualFriends = await _loadMutualFriendsForProfile(viewedUserId);
        } catch (error) {
          debugPrint('Luma optional mutual friends load warning: $error');
        }
      }

      if (!mounted) return;

      final relationshipStatus = isOwnProfile
          ? ProfileRelationshipStatus.self
          : _friendshipNotifier.relationshipStatus;

      final blockState = isOwnProfile
          ? const ProfileBlockState()
          : await _loadProfileBlockState(
              currentUserId: authUserId,
              viewedUserId: viewedUserId,
            );

      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
        _profileLoadError = null;
        _firebaseFriends = firebaseFriends;
        _mutualFriends = mutualFriends;
        _profile = _privateProfileFromFirebase(
          firebaseProfile!,
          isOwnProfile: isOwnProfile,
          relationshipStatus: relationshipStatus,
          friendsCount: firebaseFriends.length,
          postsCount: _profileMoments.length,
          mutualFriendsCount: mutualFriends.length,
        );
        _isBlockedByMe = blockState.blockedByMe;
        _isBlockedBetweenUsers = blockState.blockedBetweenUsers;
      });

      _watchProfileMoments(viewedUserId);
      _watchProfilePhotos(viewedUserId);
    } catch (error) {
      if (!mounted) return;

      debugPrint('Luma profile load error: $error');

      setState(() {
        _isLoadingProfile = false;
        _isLoadingMoments = false;
        _profileLoadError = 'Das Profil konnte nicht geladen werden.';
        _profile = PrivateProfileModel.empty();
        _firebaseFriends = const <PrivateProfileModel>[];
        _mutualFriends = const <PrivateProfileModel>[];
        _profileMoments = const <profile_posts.ProfileMomentPreviewData>[];
        _profilePhotos = const <ProfilePhotoModel>[];
        _isBlockedByMe = false;
        _isBlockedBetweenUsers = false;
      });
    }
  }

  Future<ProfileBlockState> _loadProfileBlockState({
    required String currentUserId,
    required String viewedUserId,
  }) async {
    final cleanedCurrentUserId = currentUserId.trim();
    final cleanedViewedUserId = viewedUserId.trim();

    if (cleanedCurrentUserId.isEmpty ||
        cleanedViewedUserId.isEmpty ||
        cleanedCurrentUserId == cleanedViewedUserId) {
      return const ProfileBlockState();
    }

    try {
      final results = await Future.wait<bool>([
        _friendshipRepository.isUserBlockedBy(
          ownerUserId: cleanedCurrentUserId,
          blockedUserId: cleanedViewedUserId,
        ),
        _friendshipRepository.isUserBlockedBy(
          ownerUserId: cleanedViewedUserId,
          blockedUserId: cleanedCurrentUserId,
        ),
      ]);

      final blockedByMe = results[0];
      final blockedByOtherUser = results[1];

      return ProfileBlockState(
        blockedByMe: blockedByMe,
        blockedByOtherUser: blockedByOtherUser,
      );
    } catch (error) {
      debugPrint('Luma profile block state warning: $error');
      return const ProfileBlockState();
    }
  }

  void _watchProfilePhotos(String viewedUserId) {
    final cleanedViewedUserId = viewedUserId.trim();

    _profilePhotosSubscription?.cancel();
    _profilePhotosSubscription = null;

    if (cleanedViewedUserId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _profilePhotos = const <ProfilePhotoModel>[];
      });
      return;
    }

    _profilePhotosSubscription = _profilePhotoRepository
        .watchProfilePhotos(userId: cleanedViewedUserId)
        .listen(
      (photos) {
        if (!mounted) return;

        setState(() {
          _profilePhotos = photos;
        });
      },
      onError: (Object error) {
        debugPrint('Luma profile photos watch error: $error');
        if (!mounted) return;

        setState(() {
          _profilePhotos = const <ProfilePhotoModel>[];
        });
      },
    );
  }

  void _watchProfileMoments(String viewedUserId) {
    final cleanedViewedUserId = viewedUserId.trim();

    _profileMomentsSubscription?.cancel();
    _profileMomentsSubscription = null;

    if (cleanedViewedUserId.isEmpty) return;

    setState(() {
      _isLoadingMoments = true;
      _momentError = null;
    });

    _profileMomentsSubscription = _profileMomentRepository
        .watchProfileMoments(
          userId: cleanedViewedUserId,
          currentViewerUserId: _currentAuthUserId,
        )
        .listen(
      (moments) {
        if (!mounted) return;

        final previewMoments = moments
            .map(_profileMomentPreviewFromFirebase)
            .toList(growable: false);

        setState(() {
          _isLoadingMoments = false;
          _momentError = null;
          _profileMoments = previewMoments;
          _profile = _profile.copyWith(postsCount: previewMoments.length);
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        debugPrint('Luma profile moments watch error: $error');

        setState(() {
          _isLoadingMoments = false;
          _momentError =
              'Profilmomente konnten nicht geladen werden.';
        });
      },
    );
  }

  profile_posts.ProfileMomentPreviewData _profileMomentPreviewFromFirebase(
    ProfileMomentModel moment,
  ) {
    final taggedFriendIds = moment.taggedFriendIds;

    return profile_posts.ProfileMomentPreviewData(
      id: moment.id,
      text: moment.text,
      createdAt: moment.createdAt,
      moodLabel: moment.moodLabel,
      moodIconKey: moment.moodIconKey,
      likeCount: moment.likeCount,
      commentCount: moment.commentCount,
      shareCount: moment.shareCount,
      saveCount: moment.saveCount,
      isLikedByCurrentUser: moment.isLikedByCurrentUser,
      taggedFriendIds: taggedFriendIds,
      taggedFriendNames: ProfileTaggedFriendResolver.resolveTaggedFriendNames(
        taggedFriendIds: taggedFriendIds,
        friends: _firebaseFriends,
      ),
      taggedFriendNamesById:
          ProfileTaggedFriendResolver.resolveTaggedFriendNamesById(
        taggedFriendIds: taggedFriendIds,
        friends: _firebaseFriends,
      ),
      taggedFriendAvatarUrlsById:
          ProfileTaggedFriendResolver.resolveTaggedFriendAvatarUrlsById(
        taggedFriendIds: taggedFriendIds,
        friends: _firebaseFriends,
      ),
    );
  }


  Future<List<PrivateProfileModel>> _loadFirebaseFriendsForProfile(
    String viewedUserId, {
    required bool isOwnProfile,
  }) async {
    final cleanedViewedUserId = viewedUserId.trim();

    if (cleanedViewedUserId.isEmpty) {
      return const <PrivateProfileModel>[];
    }

    final currentAuthUserId = _currentAuthUserId.trim();

    if (!isOwnProfile) {
      if (currentAuthUserId.isEmpty) {
        return const <PrivateProfileModel>[];
      }

      try {
        final directFriendship = await _friendshipRepository.fetchFriendship(
          userId: currentAuthUserId,
          otherUserId: cleanedViewedUserId,
        );

        if (directFriendship?.status != FriendshipStatus.accepted) {
          return const <PrivateProfileModel>[];
        }
      } catch (error) {
        debugPrint(
          'Luma foreign profile direct friendship lookup warning: $error',
        );
        return const <PrivateProfileModel>[];
      }

      return const <PrivateProfileModel>[];
    }

    final acceptedFriendIds = <String>{
      ...await _friendshipRepository.fetchAcceptedFriendUserIds(
        userId: cleanedViewedUserId,
      ),
    }..removeWhere((id) => id.trim().isEmpty);

    if (acceptedFriendIds.isEmpty) {
      return const <PrivateProfileModel>[];
    }

    final friendProfiles = await _userProfileRepository.fetchProfilesByIds(
      userIds: acceptedFriendIds.toList(growable: false),
    );

    return friendProfiles.map((profile) {
      return _privateProfileFromFirebase(
        profile,
        isOwnProfile: profile.id == currentAuthUserId,
        relationshipStatus: profile.id == currentAuthUserId
            ? ProfileRelationshipStatus.self
            : ProfileRelationshipStatus.friends,
        friendsCount: 0,
        postsCount: 0,
      );
    }).toList(growable: false);
  }

  Future<List<PrivateProfileModel>> _loadMutualFriendsForProfile(
    String viewedUserId,
  ) async {
    final currentUserId = _currentAuthUserId.trim();
    final cleanedViewedUserId = viewedUserId.trim();

    if (currentUserId.isEmpty || cleanedViewedUserId.isEmpty) {
      return const <PrivateProfileModel>[];
    }

    if (currentUserId == cleanedViewedUserId) {
      return const <PrivateProfileModel>[];
    }

    try {
      final currentFriendIds = <String>{
        ...await _friendshipRepository.fetchAcceptedFriendUserIds(
          userId: currentUserId,
        ),
      }..removeWhere((id) => id.trim().isEmpty);

      final viewedFriendIds = <String>{
        ...await _friendshipRepository.fetchAcceptedFriendUserIds(
          userId: cleanedViewedUserId,
        ),
      }..removeWhere((id) => id.trim().isEmpty);

      if (currentFriendIds.isEmpty || viewedFriendIds.isEmpty) {
        return const <PrivateProfileModel>[];
      }

      final mutualFriendIds = currentFriendIds
          .intersection(viewedFriendIds)
          .where((id) {
            final cleanedId = id.trim();
            return cleanedId.isNotEmpty &&
                cleanedId != currentUserId &&
                cleanedId != cleanedViewedUserId;
          })
          .toList(growable: false);

      if (mutualFriendIds.isEmpty) {
        return const <PrivateProfileModel>[];
      }

      final mutualProfiles = await _userProfileRepository.fetchProfilesByIds(
        userIds: mutualFriendIds,
      );

      return mutualProfiles.map((profile) {
        return _privateProfileFromFirebase(
          profile,
          isOwnProfile: profile.id == currentUserId,
          relationshipStatus: profile.id == currentUserId
              ? ProfileRelationshipStatus.self
              : ProfileRelationshipStatus.friends,
          friendsCount: 0,
          postsCount: 0,
        );
      }).toList(growable: false);
    } catch (error) {
      debugPrint('Luma mutual friends load warning: $error');
      return const <PrivateProfileModel>[];
    }
  }

  String _resolveViewedUserId(String authUserId) {
    final cleanWidgetUserId = widget.userId?.trim();

    if (cleanWidgetUserId != null && cleanWidgetUserId.isNotEmpty) {
      return cleanWidgetUserId;
    }

    return authUserId;
  }

  PrivateProfileModel _privateProfileFromFirebase(
    LumaUserProfileModel profile, {
    required bool isOwnProfile,
    required ProfileRelationshipStatus relationshipStatus,
    required int friendsCount,
    required int postsCount,
    int mutualFriendsCount = 0,
  }) {
    return PrivateProfileModel(
      id: profile.id,
      displayName: profile.displayName,
      username: profile.username,
      bio: profile.bio ?? '',
      profileImageUrl: profile.avatarUrl ?? '',
      coverImageUrl: profile.coverUrl ?? '',
      friendsCount: friendsCount,
      postsCount: postsCount,
      privacy: ProfilePrivacyModel.defaultSettings(),
      mutualFriendsCount: mutualFriendsCount,
      location: profile.location ?? '',
      work: profile.work ?? '',
      education: profile.education ?? '',
      website: profile.website ?? '',
      isVerified: profile.isVerified,
      isOwnProfile: isOwnProfile,
      allowFollowers: false,
      isPrivateProfile: profile.isPrivate,
      relationshipStatus: relationshipStatus,
      nickname: profile.nickname ?? '',
      relationshipStatusText: profile.relationshipStatusText ?? '',
      familyInfo: profile.familyInfo ?? '',
      birthday: profile.birthday,
      birthdayVisibility: profile.birthdayVisibility,
      birthYearVisibility: profile.birthYearVisibility,
      friendsVisibility: profile.friendsVisibility,
      instagramUrl: profile.instagramUrl ?? '',
      youtubeUrl: profile.youtubeUrl ?? '',
      spotifyUrl: profile.spotifyUrl ?? '',
      tiktokUrl: profile.tiktokUrl ?? '',
      facebookUrl: profile.facebookUrl ?? '',
      whatsappUrl: profile.whatsappUrl ?? '',
      twitterUrl: profile.twitterUrl ?? '',
    );
  }

  ProfileRelationshipStatus get _effectiveRelationshipStatus {
    if (_isViewingOwnProfile) {
      return ProfileRelationshipStatus.self;
    }

    return _friendshipNotifier.state.relationshipStatus;
  }

  bool get _isFriendViewingProfile {
    return _effectiveRelationshipStatus == ProfileRelationshipStatus.friends;
  }

  bool get _canViewPrivateProfileContent {
    if (_isViewingOwnProfile) return true;
    if (_isBlockedBetweenUsers) return false;
    if (!_profile.isPrivateProfile) return true;

    return _isFriendViewingProfile;
  }

  bool _canViewProfileField(ProfileFieldVisibility visibility) {
    if (_isViewingOwnProfile) return true;

    switch (visibility) {
      case ProfileFieldVisibility.onlyMe:
        return false;
      case ProfileFieldVisibility.friends:
        return _isFriendViewingProfile;
      case ProfileFieldVisibility.public:
        return true;
    }
  }

  bool get _canViewBirthday {
    return _profile.hasBirthday &&
        _canViewProfileField(_profile.birthdayVisibility);
  }

  bool get _canViewBirthdayYear {
    return _profile.hasBirthday &&
        _canViewProfileField(_profile.birthYearVisibility);
  }

  bool get _canViewFriendsList {
    if (!_canViewPrivateProfileContent) return false;
    return _canViewProfileField(_profile.friendsVisibility);
  }

  bool get _isFriendsListHiddenByPrivacy {
    if (_isViewingOwnProfile) return false;
    if (!_canViewPrivateProfileContent) return true;
    return !_canViewProfileField(_profile.friendsVisibility);
  }

  List<PrivateProfileModel> get _visibleFriendsForCurrentViewer {
    if (!_canViewFriendsList) {
      return const <PrivateProfileModel>[];
    }

    return _firebaseFriends;
  }

  List<profile_posts.ProfileMomentPreviewData> get
      _visibleProfileMomentsForCurrentViewer {
    if (!_canViewPrivateProfileContent) {
      return const <profile_posts.ProfileMomentPreviewData>[];
    }

    return _profileMoments;
  }

  PrivateProfileModel get _visibleProfileForCurrentViewer {
    final visibleFriends = _visibleFriendsForCurrentViewer;
    final visibleMoments = _visibleProfileMomentsForCurrentViewer;

    var visibleProfile = _profile.copyWith(
      friendsCount: visibleFriends.length,
      postsCount: visibleMoments.length,
      clearBirthday: !_canViewBirthday,
    );

    if (!_canViewPrivateProfileContent && !_isViewingOwnProfile) {
      visibleProfile = visibleProfile.copyWith(
        bio: '',
        location: '',
        work: '',
        education: '',
        website: '',
        nickname: '',
        relationshipStatusText: '',
        familyInfo: '',
        instagramUrl: '',
        youtubeUrl: '',
        spotifyUrl: '',
        tiktokUrl: '',
        facebookUrl: '',
        whatsappUrl: '',
        twitterUrl: '',
      );
    }

    return visibleProfile;
  }

  int get _visibleMomentsCount {
    return _visibleProfileMomentsForCurrentViewer.length;
  }

  bool get _hasAnyInfo {
    final visibleProfile = _visibleProfileForCurrentViewer;

    return visibleProfile.hasLocation ||
        visibleProfile.hasWork ||
        visibleProfile.hasEducation ||
        visibleProfile.hasWebsite ||
        visibleProfile.hasNickname ||
        visibleProfile.hasRelationshipStatus ||
        visibleProfile.hasFamilyInfo ||
        visibleProfile.hasBirthday ||
        visibleProfile.hasInstagram ||
        visibleProfile.hasYoutube ||
        visibleProfile.hasSpotify ||
        visibleProfile.hasTikTok ||
        visibleProfile.hasFacebook ||
        visibleProfile.hasWhatsApp ||
        visibleProfile.hasTwitter;
  }

  bool get _showForeignInfoSection => !_isViewingOwnProfile && _hasAnyInfo;

  bool get _showOwnInfoSection => _isViewingOwnProfile;

  bool get _isUploadingAnyProfileMedia {
    return _isUploadingProfileImage || _isUploadingCoverImage;
  }

  bool _isUploadingMediaForType(bool isProfileImage) {
    return isProfileImage ? _isUploadingProfileImage : _isUploadingCoverImage;
  }

  void _setMediaUploadState({
    required bool isProfileImage,
    required bool isUploading,
  }) {
    if (!mounted) return;

    setState(() {
      if (isProfileImage) {
        _isUploadingProfileImage = isUploading;
      } else {
        _isUploadingCoverImage = isUploading;
      }
    });
  }


  Future<void> _openEditProfile() async {
    if (!_isViewingOwnProfile || _isUploadingAnyProfileMedia) return;

    final updatedProfile = await Navigator.of(context).push<PrivateProfileModel>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile),
      ),
    );

    if (!mounted || updatedProfile == null) return;

    setState(() {
      _profile = updatedProfile;
    });

    await _userProfileRepository.updateProfileFields(
      userId: updatedProfile.id,
      displayName: updatedProfile.displayName,
      username: updatedProfile.username,
      bio: updatedProfile.bio,
      avatarUrl: updatedProfile.profileImageUrl,
      coverUrl: updatedProfile.coverImageUrl,
      isPrivate: updatedProfile.isPrivateProfile,
      isVerified: updatedProfile.isVerified,
      location: updatedProfile.location,
      work: updatedProfile.work,
      education: updatedProfile.education,
      website: updatedProfile.website,
      nickname: updatedProfile.nickname,
      relationshipStatusText: updatedProfile.relationshipStatusText,
      familyInfo: updatedProfile.familyInfo,
      birthday: updatedProfile.birthday,
      birthdayVisibility: updatedProfile.birthdayVisibility,
      birthYearVisibility: updatedProfile.birthYearVisibility,
      friendsVisibility: updatedProfile.friendsVisibility,
      instagramUrl: updatedProfile.instagramUrl,
      youtubeUrl: updatedProfile.youtubeUrl,
      spotifyUrl: updatedProfile.spotifyUrl,
      tiktokUrl: updatedProfile.tiktokUrl,
      facebookUrl: updatedProfile.facebookUrl,
      whatsappUrl: updatedProfile.whatsappUrl,
      twitterUrl: updatedProfile.twitterUrl,
      clearBirthday: updatedProfile.birthday == null,
    );
  }

  void _openFriendsList() {
    if (_isFriendsListHiddenByPrivacy) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Diese Freundesliste ist nicht für dich sichtbar.',
      );
      return;
    }

    final friends = _visibleFriendsForCurrentViewer;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsListScreen(
          friends: friends,
          title: _isViewingOwnProfile
              ? 'Deine Freunde'
              : 'Freunde von ${_profile.displayName.trim().isEmpty ? 'diesem Profil' : _profile.displayName}',
        ),
      ),
    );
  }

  void _openMutualFriendsList() {
    if (_mutualFriends.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendsListScreen(
          friends: _mutualFriends,
          title: _mutualFriends.length == 1
              ? '1 gemeinsamer Freund'
              : '${_mutualFriends.length} gemeinsame Freunde',
        ),
      ),
    );
  }

  void _openFriendProfile(PrivateProfileModel friend) {
    final userId = friend.userId.trim();

    if (userId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          isOwnProfile: userId == _currentAuthUserId,
          userId: userId,
        ),
      ),
    );
  }

  void _openTaggedFriendProfile(String friendUserId) {
    final cleanedFriendUserId = friendUserId.trim();

    if (cleanedFriendUserId.isEmpty) return;

    for (final friend in _firebaseFriends) {
      if (friend.userId.trim() == cleanedFriendUserId) {
        _openFriendProfile(friend);
        return;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          isOwnProfile: cleanedFriendUserId == _currentAuthUserId,
          userId: cleanedFriendUserId,
        ),
      ),
    );
  }

  Future<void> _openCreatorHub() async {
    final currentUserId = _currentAuthUserId.trim();

    if (currentUserId.isEmpty) return;

    await Navigator.of(context).pushNamed(
      AppRoutes.pagesHub,
      arguments: currentUserId,
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openOwnedPageDetail(LumaPageModel page) async {
    final currentUserId = _currentAuthUserId.trim();

    if (currentUserId.isEmpty || page.id.trim().isEmpty) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InternalPageDetailScreen(
          pageId: page.id,
          currentUserId: currentUserId,
          controller: _pageController,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  void _showAccountOverviewSheet() {
    if (!_isViewingOwnProfile) {
      _showProfileOptionsMenu();
      return;
    }

    if (_currentAuthUserId.trim().isNotEmpty &&
        _pageController.state.pages.isEmpty &&
        !_pageController.state.isLoading) {
      unawaited(_pageController.loadInternalPages());
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (_) {
        return ProfileAccountOverviewDialog(
          profile: _profile,
          pageController: _pageController,
          currentAuthUserId: _currentAuthUserId,
          onOpenOwnedPage: _openOwnedPageDetail,
          onOpenCreatorHub: _openCreatorHub,
        );
      },
    );
  }

  Future<void> _showMediaSourceSheet({
    required String title,
    required bool isProfileImage,
  }) async {
    if (!_isViewingOwnProfile) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasImage = isProfileImage
        ? _profile.profileImageUrl.trim().isNotEmpty
        : _profile.coverImageUrl.trim().isNotEmpty;
    final isUploading = _isUploadingMediaForType(isProfileImage);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (_) {
        return ProfileMediaSourceSheet(
          title: title,
          isProfileImage: isProfileImage,
          hasImage: hasImage,
          isUploading: isUploading,
          onPickFromGallery: () async {
            await _pickImage(
              source: ImageSource.gallery,
              isProfileImage: isProfileImage,
            );
          },
          onPickFromCamera: () async {
            await _pickImage(
              source: ImageSource.camera,
              isProfileImage: isProfileImage,
            );
          },
          onRemove: () {
            if (isProfileImage) {
              _removeProfileImage();
            } else {
              _removeCoverImage();
            }
          },
        );
      },
    );
  }

  Future<void> _pickImage({
    required ImageSource source,
    required bool isProfileImage,
  }) async {
    if (!_isViewingOwnProfile) return;
    if (_isUploadingMediaForType(isProfileImage)) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: isProfileImage ? 1200 : 1800,
        maxHeight: isProfileImage ? 1200 : 1200,
      );

      if (pickedFile == null || !mounted) return;

      final currentUserId = _profile.userId.trim();

      if (currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Das aktuelle Profil konnte nicht bestimmt werden.'),
          ),
        );
        return;
      }

      _setMediaUploadState(
        isProfileImage: isProfileImage,
        isUploading: true,
      );

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isProfileImage
                  ? 'Profilbild wird hochgeladen ...'
                  : 'Coverbild wird hochgeladen ...',
            ),
          ),
        );

      final uploadedImageUrl = isProfileImage
          ? await _profileStorageRepository.uploadAvatar(
              userId: currentUserId,
              imageFile: pickedFile,
            )
          : await _profileStorageRepository.uploadCover(
              userId: currentUserId,
              imageFile: pickedFile,
            );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isProfileImage
                  ? 'Profilbild wurde hochgeladen. Profil wird aktualisiert ...'
                  : 'Coverbild wurde hochgeladen. Profil wird aktualisiert ...',
            ),
          ),
        );

      try {
        await _userProfileRepository.updateProfileFields(
          userId: currentUserId,
          avatarUrl: isProfileImage ? uploadedImageUrl : null,
          coverUrl: isProfileImage ? null : uploadedImageUrl,
        );
      } catch (error) {
        if (!mounted) return;

        debugPrint('Luma profile media firestore update error: $error');

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isProfileImage
                    ? 'Profilbild wurde hochgeladen, aber dein Profil konnte nicht aktualisiert werden.'
                    : 'Coverbild wurde hochgeladen, aber dein Profil konnte nicht aktualisiert werden.',
              ),
            ),
          );

        return;
      }

      try {
        await _profilePhotoRepository.upsertRemoteProfileMediaPhoto(
          userId: currentUserId,
          imageUrl: uploadedImageUrl,
          type: isProfileImage
              ? ProfilePhotoType.profileImage
              : ProfilePhotoType.coverImage,
          caption: isProfileImage ? 'Profilbild' : 'Titelbild',
        );
      } catch (error) {
        debugPrint('Luma profile photo gallery sync warning: $error');
      }

      if (!mounted) return;

      setState(() {
        if (isProfileImage) {
          _profile = _profile.copyWith(profileImageUrl: uploadedImageUrl);
        } else {
          _profile = _profile.copyWith(coverImageUrl: uploadedImageUrl);
        }
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isProfileImage
                  ? 'Profilbild wurde gespeichert.'
                  : 'Coverbild wurde gespeichert.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      debugPrint('Luma profile image upload error: $error');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isProfileImage
                  ? 'Profilbild konnte nicht hochgeladen werden.'
                  : 'Coverbild konnte nicht hochgeladen werden.',
            ),
          ),
        );
    } finally {
      _setMediaUploadState(
        isProfileImage: isProfileImage,
        isUploading: false,
      );
    }
  }

  Future<void> _removeProfileImage() async {
    if (!mounted || !_isViewingOwnProfile) return;
    if (_isUploadingProfileImage) return;

    final currentUserId = _profile.userId.trim();
    if (currentUserId.isEmpty) return;

    _setMediaUploadState(isProfileImage: true, isUploading: true);

    try {
      await _userProfileRepository.updateProfileFields(
        userId: currentUserId,
        avatarUrl: '',
      );

      if (!mounted) return;

      setState(() {
        _profile = _profile.copyWith(profileImageUrl: '');
      });

      try {
        await _profileStorageRepository.deleteAvatar(userId: currentUserId);
      } catch (error) {
        debugPrint('Luma profile avatar storage delete warning: $error');
      }

      try {
        await _profilePhotoRepository.deleteRemoteProfileMediaPhoto(
          userId: currentUserId,
          type: ProfilePhotoType.profileImage,
        );
      } catch (error) {
        debugPrint('Luma profile avatar gallery delete warning: $error');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Profilbild wurde entfernt.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      debugPrint('Luma profile avatar remove error: $error');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Profilbild konnte nicht entfernt werden.'),
          ),
        );
    } finally {
      _setMediaUploadState(isProfileImage: true, isUploading: false);
    }
  }

  Future<void> _removeCoverImage() async {
    if (!mounted || !_isViewingOwnProfile) return;
    if (_isUploadingCoverImage) return;

    final currentUserId = _profile.userId.trim();
    if (currentUserId.isEmpty) return;

    _setMediaUploadState(isProfileImage: false, isUploading: true);

    try {
      await _userProfileRepository.updateProfileFields(
        userId: currentUserId,
        coverUrl: '',
      );

      if (!mounted) return;

      setState(() {
        _profile = _profile.copyWith(coverImageUrl: '');
      });

      try {
        await _profileStorageRepository.deleteCover(userId: currentUserId);
      } catch (error) {
        debugPrint('Luma profile cover storage delete warning: $error');
      }

      try {
        await _profilePhotoRepository.deleteRemoteProfileMediaPhoto(
          userId: currentUserId,
          type: ProfilePhotoType.coverImage,
        );
      } catch (error) {
        debugPrint('Luma profile cover gallery delete warning: $error');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Coverbild wurde entfernt.'),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      debugPrint('Luma profile cover remove error: $error');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Coverbild konnte nicht entfernt werden.'),
          ),
        );
    } finally {
      _setMediaUploadState(isProfileImage: false, isUploading: false);
    }
  }

  void _showWebsiteSheet(String website) {
    final cleanWebsite = website.trim();
    if (cleanWebsite.isEmpty) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (_) {
        return ProfileWebsiteSheet(
          website: cleanWebsite,
          onOpenWebsite: _openExternalProfileUrl,
        );
      },
    );
  }

  Future<void> _openExternalProfileUrl(String rawUrl) async {
    final normalizedUrl = ProfileExternalUrlHelper.normalize(rawUrl);

    if (normalizedUrl == null) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Diese Website-Adresse ist ungültig.',
      );
      return;
    }

    final uri = Uri.tryParse(normalizedUrl);

    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Diese Website-Adresse ist ungültig.',
      );
      return;
    }

    try {
      final didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!didLaunch) {
        ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Website konnte nicht geöffnet werden.',
      );
      }
    } catch (error) {
      debugPrint('Luma profile website launch error: $error');
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Website konnte nicht geöffnet werden.',
      );
    }
  }

  Future<void> _openMessageConversation() async {
    if (_isViewingOwnProfile || _isOpeningMessageConversation) return;

    if (_isBlockedBetweenUsers) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Unterhaltung ist wegen einer Blockierung nicht verfügbar.',
      );
      return;
    }

    final currentUserId = _currentAuthUserId.trim();
    final viewedUserId = _currentViewedUserId.trim();

    if (currentUserId.isEmpty || viewedUserId.isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Unterhaltung konnte nicht geöffnet werden.',
      );
      return;
    }

    if (currentUserId == viewedUserId) {
      return;
    }

    setState(() {
      _isOpeningMessageConversation = true;
    });

    try {
      await _messengerController.configureRemoteMode(
        mode: MessengerRemoteMode.remoteOnly,
        currentUserId: currentUserId,
      );

      final participant = ChatParticipantModel(
        userId: viewedUserId,
        displayName: _profile.displayName.trim().isEmpty
            ? _profile.username.trim().isEmpty
                ? 'Luma Profil'
                : _profile.username.trim()
            : _profile.displayName.trim(),
        avatarUrl: _profile.profileImageUrl.trim(),
        isOnline: false,
      );

      final chat = await _messengerController.openOrCreateDirectChat(
        participant,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chat: chat),
        ),
      );
    } catch (error) {
      debugPrint('Luma profile open message conversation error: $error');

      if (!mounted) return;

      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Unterhaltung konnte nicht geöffnet werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMessageConversation = false;
        });
      }
    }
  }

  Future<List<PrivateProfileModel>?> _showTagFriendsPickerDialog({
    required List<PrivateProfileModel> selectedFriends,
  }) async {
    return ProfileFriendPickerDialog.show(
      context: context,
      availableFriends: _firebaseFriends,
      selectedFriends: selectedFriends,
    );
  }

  void _showCreatePostPlaceholderSheet() {
    if (!_isViewingOwnProfile) return;

    ProfileCreateMomentDialog.show(
      context: context,
      displayName: _profile.displayName,
      currentViewedUserId: _currentViewedUserId,
      profileMomentRepository: _profileMomentRepository,
      showTagFriendsPickerDialog: _showTagFriendsPickerDialog,
      onTaggedFriendTap: _openTaggedFriendProfile,
    );
  }

  void _showEditProfileMomentSheet(profile_posts.ProfileMomentPreviewData moment) {
    if (!_isViewingOwnProfile) return;

    ProfileEditMomentSheet.show(
      context: context,
      moment: moment,
      onSave: ({
        required String text,
        required BuildContext actionContext,
        required BuildContext sheetContext,
      }) async {
        final userId = _currentViewedUserId.trim();

        if (userId.isEmpty) return;

        try {
          await _profileMomentRepository.updateProfileMoment(
            userId: userId,
            momentId: moment.id,
            text: text,
          );

          if (!actionContext.mounted) return;

          Navigator.of(sheetContext).pop();

          ScaffoldMessenger.of(actionContext).showSnackBar(
            const SnackBar(
              content: Text(
                'Moment wurde aktualisiert.',
              ),
            ),
          );
        } catch (error) {
          if (!actionContext.mounted) return;

          ScaffoldMessenger.of(actionContext).showSnackBar(
            SnackBar(
              content: Text(
                'Moment konnte nicht aktualisiert werden: $error',
              ),
            ),
          );
        }
      },
    );
  }




  Future<List<PrivateProfileModel>> _loadProfileMomentLikerProfiles({
    required String ownerUserId,
    required String momentId,
  }) async {
    final likerUserIds =
        await _profileMomentRepository.fetchProfileMomentLikerUserIds(
      ownerUserId: ownerUserId,
      momentId: momentId,
      limit: 120,
    );

    if (likerUserIds.isEmpty) {
      return const <PrivateProfileModel>[];
    }

    final profiles = await _userProfileRepository.fetchProfilesByIds(
      userIds: likerUserIds,
    );

    final profilesById = <String, PrivateProfileModel>{
      for (final profile in profiles)
        profile.id.trim(): _privateProfileFromFirebase(
          profile,
          isOwnProfile: profile.id.trim() == _currentAuthUserId.trim(),
          relationshipStatus: profile.id.trim() == _currentAuthUserId.trim()
              ? ProfileRelationshipStatus.self
              : ProfileRelationshipStatus.notFriends,
          friendsCount: 0,
          postsCount: 0,
        ),
    };

    final orderedProfiles = <PrivateProfileModel>[];

    for (final likerUserId in likerUserIds) {
      final profile = profilesById[likerUserId.trim()];
      if (profile == null) continue;
      orderedProfiles.add(profile);
    }

    return List<PrivateProfileModel>.unmodifiable(orderedProfiles);
  }

  void _showProfileMomentLikers(
    profile_posts.ProfileMomentPreviewData moment,
  ) {
    final ownerUserId = _currentViewedUserId.trim();
    final momentId = moment.id.trim();

    if (ownerUserId.isEmpty || momentId.isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Gefällt-mir-Angaben konnten nicht geöffnet werden.',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ProfileMomentLikersSheet(
          future: _loadProfileMomentLikerProfiles(
            ownerUserId: ownerUserId,
            momentId: momentId,
          ),
          onOpenProfile: (profile) {
            Navigator.of(sheetContext).pop();
            _openFriendProfile(profile);
          },
        );
      },
    );
  }

  Future<void> _toggleProfileMomentLike(
    profile_posts.ProfileMomentPreviewData moment,
  ) async {
    final ownerUserId = _currentViewedUserId.trim();
    final currentUserId = _currentAuthUserId.trim();
    final momentId = moment.id.trim();

    if (ownerUserId.isEmpty || currentUserId.isEmpty || momentId.isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Gefällt mir konnte nicht gespeichert werden.',
      );
      return;
    }

    try {
      await _profileMomentRepository.toggleProfileMomentLike(
        ownerUserId: ownerUserId,
        momentId: momentId,
        currentUserId: currentUserId,
      );
    } catch (error) {
      debugPrint('Luma profile moment like error: $error');

      if (!mounted) return;

      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Gefällt mir konnte nicht gespeichert werden.',
      );
    }
  }

  void _openProfileMomentComments(
    profile_posts.ProfileMomentPreviewData moment,
  ) {
    final ownerUserId = _currentViewedUserId.trim();
    final currentUserId = _currentAuthUserId.trim();
    final momentId = moment.id.trim();

    if (ownerUserId.isEmpty || currentUserId.isEmpty || momentId.isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Kommentare konnten nicht geöffnet werden.',
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ProfileMomentCommentsSheet(
          moment: moment,
          ownerUserId: ownerUserId,
          currentUserId: currentUserId,
          repository: _profileMomentRepository,
          authorDisplayName: _currentCommentAuthorDisplayName,
          authorUsername: _currentCommentAuthorUsername,
          authorAvatarUrl: _currentCommentAuthorAvatarUrl,
          canDeleteAsOwner: ownerUserId == currentUserId,
          onAuthorTap: _openTaggedFriendProfile,
        );
      },
    );
  }

  String get _currentCommentAuthorDisplayName {
    final authUser = _firebaseAuth.currentUser;
    final cleanDisplayName = authUser?.displayName?.trim() ?? '';

    if (cleanDisplayName.isNotEmpty) return cleanDisplayName;

    final cleanEmail = authUser?.email?.trim() ?? '';
    final fallback = ProfileIdentityHelpers.nameFromEmail(cleanEmail);

    return fallback.trim().isEmpty ? 'Luma Nutzer' : fallback.trim();
  }

  String get _currentCommentAuthorUsername {
    final authUser = _firebaseAuth.currentUser;
    final cleanEmail = authUser?.email?.trim() ?? '';
    final username = ProfileIdentityHelpers.usernameFromEmail(cleanEmail).trim();

    if (username.isEmpty) return '';
    return username.startsWith('@') ? username.substring(1) : username;
  }

  String get _currentCommentAuthorAvatarUrl {
    return _firebaseAuth.currentUser?.photoURL?.trim() ?? '';
  }


  Future<void> _deleteProfileMoment(profile_posts.ProfileMomentPreviewData moment) async {
    if (!_isViewingOwnProfile) return;

    final userId = _currentViewedUserId.trim();

    if (userId.isEmpty) return;

    try {
      await _profileMomentRepository.deleteProfileMoment(
        userId: userId,
        momentId: moment.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Moment wurde gelöscht.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moment konnte nicht gelöscht werden: $error'),
        ),
      );
    }
  }

  void _showProfilePostsPlaceholderSheet() {
    ProfilePostsSheet.show(
      context: context,
      profileMoments: _profileMoments,
      isViewingOwnProfile: _isViewingOwnProfile,
      isLoadingMoments: _isLoadingMoments,
      momentError: _momentError,
      buildMomentsLoadingSheetState: () {
        return ProfileMomentSheetStateBuilders.buildLoading(context);
      },
      buildMomentsErrorSheetState: () {
        return ProfileMomentSheetStateBuilders.buildError(
          context: context,
          momentError: _momentError,
          viewedUserId: _currentViewedUserId,
          onRetry: _watchProfileMoments,
        );
      },
      buildEmptyMomentsSheetState: () {
        return ProfileMomentSheetStateBuilders.buildEmpty(
          context: context,
          isViewingOwnProfile: _isViewingOwnProfile,
        );
      },
      onCreateMoment: _showCreatePostPlaceholderSheet,
      onEditMoment: _showEditProfileMomentSheet,
      onDeleteMoment: _deleteProfileMoment,
      onLikeSummaryTap: _showProfileMomentLikers,
      onTaggedFriendTap: _openTaggedFriendProfile,
    );
  }


  List<ProfilePhotoPreviewItemData> _buildProfilePhotoPreviewItems() {
    return ProfilePhotoPreviewBuilder.buildItems(
      profilePhotos: _profilePhotos,
      profileImageUrl: _profile.profileImageUrl,
      coverImageUrl: _profile.coverImageUrl,
    );
  }

  List<String> _buildProfilePhotoPreviewUrls() {
    return ProfilePhotoPreviewBuilder.buildUrls(
      profilePhotos: _profilePhotos,
      profileImageUrl: _profile.profileImageUrl,
      coverImageUrl: _profile.coverImageUrl,
    );
  }

  void _openProfilePhotoViewer(ProfilePhotoPreviewItemData item) {
    final imageUrl = item.imageUrl.trim();

    if (imageUrl.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfilePhotoFullscreenViewer(
            imageUrl: imageUrl,
            title: item.label,
            displayName: _safeProfileDisplayName,
            username: _safeProfileUsername,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  void _showProfileInfoSheet() {
    ProfileInfoSheet.show(
      context: context,
      profile: _visibleProfileForCurrentViewer,
      isOwnProfile: _isViewingOwnProfile,
      showBirthdayYear: _canViewBirthdayYear,
      onWebsiteTap: _showWebsiteSheet,
    );
  }

  void _showProfilePhotosSheet() {
    ProfilePhotosSheet.show(
      context: context,
      photoPreviewItems: _buildProfilePhotoPreviewItems(),
      isViewingOwnProfile: _isViewingOwnProfile,
      onPhotoTap: _openProfilePhotoViewer,
    );
  }

  String get _safeProfileDisplayName {
    return ProfileDisplayNameHelper.safeDisplayName(_profile);
  }

  String get _safeProfileUsername {
    return ProfileDisplayNameHelper.safeUsername(_profile);
  }

  void _showProfileOptionsMenu() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (_) {
        return ProfileOptionsSheet(
          onClose: () => Navigator.of(context).pop(),
          isOwnProfile: _isViewingOwnProfile,
          profileDisplayName: _safeProfileDisplayName,
          profileUsername: _safeProfileUsername,
          isBlocked: _isBlockedByMe,
          onReportProfile: _showReportProfileSheet,
          onBlockProfile: _confirmBlockProfile,
          onUnblockProfile: _confirmUnblockProfile,
          onHideProfile: _hideProfileFromView,
          onOpenPrivacyInfo: _showProfileSafetyInfoSheet,
        );
      },
    );
  }

  void _hideProfileFromView() {
    Navigator.of(context).maybePop();

    ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Profil wurde für diese Sitzung ausgeblendet.',
      );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmBlockProfile() async {
    Navigator.of(context).maybePop();

    if (_isViewingOwnProfile) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Dein eigenes Profil kann nicht blockiert werden.',
      );
      return;
    }

    if (_isUpdatingBlockStatus) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Profil blockieren?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '$_safeProfileDisplayName kann dir danach keine Freundschaftsanfrage senden und keine direkte Interaktion mehr mit dir starten. Eine bestehende Freundschaft wird entfernt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Blockieren'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final currentUserId = _currentAuthUserId.trim();
    final viewedUserId = _currentViewedUserId.trim();

    if (currentUserId.isEmpty || viewedUserId.isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Profil konnte nicht blockiert werden.',
      );
      return;
    }

    setState(() {
      _isUpdatingBlockStatus = true;
    });

    try {
      await _friendshipRepository.blockUser(
        blockerUserId: currentUserId,
        blockedUserId: viewedUserId,
      );

      if (!mounted) return;

      setState(() {
        _isBlockedByMe = true;
        _isBlockedBetweenUsers = true;
      });

      _friendshipNotifier.reset();

      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: '$_safeProfileDisplayName wurde blockiert.',
      );
    } catch (error) {
      debugPrint('Luma profile block error: $error');

      if (!mounted) return;

      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Profil konnte nicht blockiert werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBlockStatus = false;
        });
      }
    }
  }

  Future<void> _confirmUnblockProfile() async {
    Navigator.of(context).maybePop();

    if (_isViewingOwnProfile) return;
    if (_isUpdatingBlockStatus) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Blockierung aufheben?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '$_safeProfileDisplayName kann danach wieder gefunden werden und dir erneut eine Freundschaftsanfrage senden. Eine frühere Freundschaft wird nicht automatisch wiederhergestellt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Aufheben'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final currentUserId = _currentAuthUserId.trim();
    final viewedUserId = _currentViewedUserId.trim();

    if (currentUserId.isEmpty || viewedUserId.isEmpty) {
      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Blockierung konnte nicht aufgehoben werden.',
      );
      return;
    }

    setState(() {
      _isUpdatingBlockStatus = true;
    });

    try {
      await _friendshipRepository.unblockUser(
        blockerUserId: currentUserId,
        blockedUserId: viewedUserId,
      );

      if (!mounted) return;

      setState(() {
        _isBlockedByMe = false;
        _isBlockedBetweenUsers = false;
      });

      _friendshipNotifier.initialize(
        currentUserId: currentUserId,
        viewedUserId: viewedUserId,
      );

      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Blockierung wurde aufgehoben.',
      );
    } catch (error) {
      debugPrint('Luma profile unblock error: $error');

      if (!mounted) return;

      ProfileFeedbackHelper.showSnackBar(
        context: context,
        message: 'Blockierung konnte nicht aufgehoben werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBlockStatus = false;
        });
      }
    }
  }

  Future<void> _showReportProfileSheet() async {
    await ProfileReportSafetySheets.showReportProfileSheet(
      context: context,
      isViewingOwnProfile: _isViewingOwnProfile,
      onShowSnackBar: (message) {
        ProfileFeedbackHelper.showSnackBar(
          context: context,
          message: message,
        );
      },
    );
  }

  void _showProfileSafetyInfoSheet() {
    ProfileReportSafetySheets.showProfileSafetyInfoSheet(
      context: context,
    );
  }


  @override
  Widget build(BuildContext context) {
    final friendshipState = _friendshipNotifier.state;
    final relationshipStatus = _effectiveRelationshipStatus;
    final visibleProfile = _visibleProfileForCurrentViewer;
    final previewFriends = _visibleFriendsForCurrentViewer;
    final visibleMoments = _visibleProfileMomentsForCurrentViewer;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canNavigateBack = Navigator.of(context).canPop();
    final shouldShowTimelineSection = _isLoadingMoments ||
        (_momentError?.trim().isNotEmpty ?? false) ||
        visibleMoments.isNotEmpty;

    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: canNavigateBack
            ? AppBar(
                leading: const BackButton(),
                title: const Text('Profil'),
              )
            : null,
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_profileLoadError != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: canNavigateBack ? const BackButton() : null,
          automaticallyImplyLeading: canNavigateBack,
          title: const Text('Profil'),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _profileLoadError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canNavigateBack) ...[
                const ProfileBackToFeedButton(),
                const SizedBox(height: 8),
              ],
              ProfileHeader(
                profile: visibleProfile,
                isOwnProfile: _isViewingOwnProfile,
                onEditProfile: _isViewingOwnProfile ? _openEditProfile : null,
                onOpenProfileOptions:
                    _isViewingOwnProfile ? _showAccountOverviewSheet : null,
                onEditProfileImage:
                    _isViewingOwnProfile && !_isUploadingProfileImage
                        ? () => _showMediaSourceSheet(
                              title: 'Profilbild',
                              isProfileImage: true,
                            )
                        : null,
                onEditCoverImage: _isViewingOwnProfile && !_isUploadingCoverImage
                    ? () => _showMediaSourceSheet(
                          title: 'Coverbild',
                          isProfileImage: false,
                        )
                    : null,
              ),
              if (!_isViewingOwnProfile)
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: _isBlockedBetweenUsers
                      ? BlockedProfileActionCard(
                          blockedByMe: _isBlockedByMe,
                          isUpdating: _isUpdatingBlockStatus,
                          onUnblock: _confirmUnblockProfile,
                          onOpenOptions: _showProfileOptionsMenu,
                        )
                      : ProfileActionBarCard(
                          relationshipStatus: relationshipStatus,
                          isOwnProfile: _isViewingOwnProfile,
                          allowFriendRequests:
                              _profile.privacy.allowFriendRequests,
                          onEditProfile: _openEditProfile,
                          onAddFriend: () async {
                            await _friendshipNotifier.sendFriendRequest(
                              allowFriendRequests:
                                  _profile.privacy.allowFriendRequests,
                            );
                          },
                          onCancelRequest: () async {
                            await _friendshipNotifier.cancelFriendRequest();
                          },
                          onAccept: () async {
                            await _friendshipNotifier.acceptFriendRequest();
                            await _initializeProfile(notify: true);
                          },
                          onDecline: () async {
                            await _friendshipNotifier.declineFriendRequest();
                          },
                          onRemoveFriend: () async {
                            await _friendshipNotifier.removeFriend();
                            await _initializeProfile(notify: true);
                          },
                          onMessage: () {
                            unawaited(_openMessageConversation());
                          },
                          onMarkAsFavorite: () async {},
                          onOpenProfileOptions: _showProfileOptionsMenu,
                        ),
                ),
              if (!_isViewingOwnProfile && friendshipState.hasError) ...[
                const SizedBox(height: 4),
                Text(
                  friendshipState.errorMessage ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
              if (!_isViewingOwnProfile && _mutualFriends.isNotEmpty)
                ProfileFlowSection(
                  order: 0,
                  topSpacing: 8,
                  child: ProfileMutualFriendsStrip(
                    mutualFriends: _mutualFriends,
                    onTap: _openMutualFriendsList,
                    onOpenFriendProfile: _openFriendProfile,
                  ),
                ),
              ProfileFlowSection(
                order: 1,
                topSpacing: _isViewingOwnProfile ? 10 : 8,
                child: ProfilePrimaryNavigation(
                  momentsCount: _visibleMomentsCount,
                  photosCount: _buildProfilePhotoPreviewUrls().length,
                  onPostsTap: _showProfilePostsPlaceholderSheet,
                  onInfoTap: _showProfileInfoSheet,
                  onPhotosTap: _showProfilePhotosSheet,
                ),
              ),
              if (_isViewingOwnProfile)
                ProfileFlowSection(
                  order: 2,
                  topSpacing: 12,
                  child: ProfileCreatePostCard(
                    displayName: visibleProfile.displayName,
                    profileImageUrl: visibleProfile.profileImageUrl,
                    onCreatePost: _showCreatePostPlaceholderSheet,
                    onAddPhoto: _showCreatePostPlaceholderSheet,
                    onAddMood: _showCreatePostPlaceholderSheet,
                    onTagFriends: _showCreatePostPlaceholderSheet,
                    onChangeVisibility: _showCreatePostPlaceholderSheet,
                  ),
                ),
              if (shouldShowTimelineSection)
                ProfileFlowSection(
                  order: 3,
                  topSpacing: 12,
                  child: ProfileTimelineSection(
                    isOwnProfile: _isViewingOwnProfile,
                    isLoading: _isLoadingMoments,
                    errorMessage: _momentError,
                    moments: visibleMoments,
                    onCreatePost: _showCreatePostPlaceholderSheet,
                    onViewAllPosts: _showProfilePostsPlaceholderSheet,
                    onEditMoment: _showEditProfileMomentSheet,
                    onDeleteMoment: _deleteProfileMoment,
                    onTaggedFriendTap: _openTaggedFriendProfile,
                    onToggleLike: _toggleProfileMomentLike,
                    onCommentTap: _openProfileMomentComments,
                    onLikeSummaryTap: _showProfileMomentLikers,
                  ),
                ),
              ProfileFlowSection(
                order: 4,
                topSpacing: 12,
                child: profile_friends.ProfileFriendsPreviewCard(
                  isOwnProfile: _isViewingOwnProfile,
                  friends: previewFriends,
                  isRestrictedByPrivacy: _isFriendsListHiddenByPrivacy,
                  onOpenFriendsList: _openFriendsList,
                  onOpenFriendProfile: _openFriendProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMomentCommentsSheet extends StatefulWidget {
  const ProfileMomentCommentsSheet({
    super.key,
    required this.moment,
    required this.ownerUserId,
    required this.currentUserId,
    required this.repository,
    required this.authorDisplayName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.canDeleteAsOwner,
    required this.onAuthorTap,
  });

  final profile_posts.ProfileMomentPreviewData moment;
  final String ownerUserId;
  final String currentUserId;
  final ProfileMomentRepository repository;
  final String authorDisplayName;
  final String authorUsername;
  final String authorAvatarUrl;
  final bool canDeleteAsOwner;
  final ValueChanged<String> onAuthorTap;

  @override
  State<ProfileMomentCommentsSheet> createState() =>
      _ProfileMomentCommentsSheetState();
}

class _ProfileMomentCommentsSheetState extends State<ProfileMomentCommentsSheet> {
  static const int _maxCommentLength = 1200;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  bool _isSubmitting = false;
  ProfileMomentCommentModel? _editingComment;

  bool get _canSubmitComment {
    final text = _commentController.text.trim();
    return !_isSubmitting && text.isNotEmpty && text.length <= _maxCommentLength;
  }

  bool get _isCommentTooLong {
    return _commentController.text.trim().length > _maxCommentLength;
  }

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_handleCommentTextChanged);
  }

  void _handleCommentTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _commentController.removeListener(_handleCommentTextChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();

    if (text.isEmpty || _isSubmitting) return;

    if (text.length > _maxCommentLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kommentar darf maximal 1200 Zeichen lang sein.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final editingComment = _editingComment;

      if (editingComment == null) {
        await widget.repository.createProfileMomentComment(
          ownerUserId: widget.ownerUserId,
          momentId: widget.moment.id,
          authorUserId: widget.currentUserId,
          authorDisplayName: widget.authorDisplayName,
          authorUsername: widget.authorUsername,
          authorAvatarUrl: widget.authorAvatarUrl,
          text: text,
        );
      } else {
        await widget.repository.updateProfileMomentComment(
          ownerUserId: widget.ownerUserId,
          momentId: widget.moment.id,
          commentId: editingComment.id,
          currentUserId: widget.currentUserId,
          text: text,
        );
      }

      if (!mounted) return;

      _commentController.clear();
      _editingComment = null;
      _commentFocusNode.unfocus();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kommentar konnte nicht gespeichert werden: $error'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _confirmDeleteComment(ProfileMomentCommentModel comment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kommentar löschen?'),
          content: const Text(
            'Dieser Kommentar wird dauerhaft entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await _deleteComment(comment);
  }

  Future<void> _deleteComment(ProfileMomentCommentModel comment) async {
    try {
      await widget.repository.deleteProfileMomentComment(
        ownerUserId: widget.ownerUserId,
        momentId: widget.moment.id,
        commentId: comment.id,
        currentUserId: widget.currentUserId,
      );

      if (!mounted) return;

      if (_editingComment?.id == comment.id) {
        _commentController.clear();
        _editingComment = null;
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kommentar konnte nicht gelöscht werden: $error'),
        ),
      );
    }
  }

  void _startEditing(ProfileMomentCommentModel comment) {
    setState(() {
      _editingComment = comment;
      _commentController.text = comment.text;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });

    _commentFocusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingComment = null;
      _commentController.clear();
    });

    _commentFocusNode.unfocus();
  }

  bool _canManageComment(ProfileMomentCommentModel comment) {
    return comment.authorUserId == widget.currentUserId || widget.canDeleteAsOwner;
  }

  bool _canEditComment(ProfileMomentCommentModel comment) {
    return comment.authorUserId == widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHigh : const Color(0xFFFFFCF8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.16)
                : const Color(0xFFE8DCCE),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.28 : 0.12),
              blurRadius: 26,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kommentare',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Schließen',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ProfileMomentCommentModel>>(
                stream: widget.repository.watchProfileMomentComments(
                  ownerUserId: widget.ownerUserId,
                  momentId: widget.moment.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                        strokeWidth: 2.4,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ProfileMomentCommentsStateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Kommentare konnten nicht geladen werden',
                      message: 'Bitte versuche es gleich erneut.',
                    );
                  }

                  final comments = snapshot.data ?? const <ProfileMomentCommentModel>[];

                  if (comments.isEmpty) {
                    return _ProfileMomentCommentsStateCard(
                      icon: Icons.mode_comment_outlined,
                      title: 'Noch keine Kommentare',
                      message: 'Schreibe den ersten Kommentar zu diesem Profilbeitrag.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = comments[index];

                      return ProfileMomentCommentTile(
                        comment: comment,
                        currentUserId: widget.currentUserId,
                        canManage: _canManageComment(comment),
                        canEdit: _canEditComment(comment),
                        onEdit: () => _startEditing(comment),
                        onDelete: () => _confirmDeleteComment(comment),
                        onAuthorTap: () {
                          final authorUserId = comment.authorUserId.trim();
                          if (authorUserId.isEmpty) return;
                          Navigator.of(context).pop();
                          widget.onAuthorTap(authorUserId);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.30)
                    : const Color(0xFFFFF8F1),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? colorScheme.outline.withValues(alpha: 0.13)
                        : const Color(0xFFE8DCCE),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_editingComment != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Kommentar bearbeiten',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isSubmitting ? null : _cancelEditing,
                            child: const Text('Abbrechen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: _maxCommentLength,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: _editingComment == null
                                  ? 'Kommentiere als ${widget.authorDisplayName}'
                                  : 'Kommentar bearbeiten...',
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.045)
                                  : Colors.white.withValues(alpha: 0.82),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? colorScheme.outline.withValues(alpha: 0.14)
                                      : const Color(0xFFE1D6CA),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? colorScheme.outline.withValues(alpha: 0.14)
                                      : const Color(0xFFE1D6CA),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: colorScheme.primary.withValues(alpha: 0.58),
                                ),
                              ),
                              contentPadding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: FilledButton(
                            onPressed: _canSubmitComment ? _submitComment : null,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _editingComment == null
                                        ? Icons.send_rounded
                                        : Icons.check_rounded,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _editingComment == null
                                ? 'Dein Kommentar erscheint direkt unter dem Beitrag.'
                                : 'Deine Änderung wird direkt übernommen.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.46),
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${_commentController.text.trim().length}/$_maxCommentLength',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _isCommentTooLong
                                ? colorScheme.error
                                : colorScheme.onSurface.withValues(alpha: 0.46),
                            fontSize: 11.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileMomentCommentTile extends StatelessWidget {
  const ProfileMomentCommentTile({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.canManage,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onAuthorTap,
  });

  final ProfileMomentCommentModel comment;
  final String currentUserId;
  final bool canManage;
  final bool canEdit;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isOwnComment = comment.authorUserId == currentUserId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAuthorTap,
          child: _ProfileMomentCommentAvatar(comment: comment),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isOwnComment
                      ? colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.10)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.045)
                          : Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOwnComment
                        ? colorScheme.primary.withValues(alpha: 0.16)
                        : isDark
                            ? colorScheme.outline.withValues(alpha: 0.10)
                            : const Color(0xFFE8DCCE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onAuthorTap,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    comment.safeAuthorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.4,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                                if (isOwnComment) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Du',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontSize: 10.2,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (canManage)
                          PopupMenuButton<String>(
                            tooltip: 'Kommentar verwalten',
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                onEdit();
                                return;
                              }

                              if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (context) => [
                              if (canEdit)
                                const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Bearbeiten'),
                                ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  'Löschen',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ),
                            ],
                            child: Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: colorScheme.onSurface.withValues(alpha: 0.48),
                            ),
                          ),
                      ],
                    ),
                    if (comment.authorUsername.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        comment.authorUsername.trim().startsWith('@')
                            ? comment.authorUsername.trim()
                            : '@${comment.authorUsername.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.48),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      comment.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.88),
                        fontSize: 14.1,
                        height: 1.30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _commentMetaLabel(comment),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.46),
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _commentMetaLabel(ProfileMomentCommentModel comment) {
    final dateText = ProfileUtils.formatProfileMomentDate(comment.createdAt);
    return comment.editedAt == null ? dateText : '$dateText · bearbeitet';
  }
}

class _ProfileMomentCommentAvatar extends StatelessWidget {
  const _ProfileMomentCommentAvatar({required this.comment});

  final ProfileMomentCommentModel comment;

  String get _initial {
    final cleanName = comment.safeAuthorName.trim();
    if (cleanName.isEmpty) return 'L';
    return String.fromCharCode(cleanName.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cleanAvatarUrl = comment.authorAvatarUrl.trim();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.13),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: cleanAvatarUrl.isEmpty
          ? Center(
              child: Text(
                _initial,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            )
          : Image.network(
              cleanAvatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    _initial,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProfileMomentCommentsStateCard extends StatelessWidget {
  const _ProfileMomentCommentsStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: colorScheme.primary.withValues(alpha: 0.82),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.58),
                height: 1.28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ProfileMomentLikersSheet extends StatelessWidget {
  final Future<List<PrivateProfileModel>> future;
  final ValueChanged<PrivateProfileModel> onOpenProfile;

  const _ProfileMomentLikersSheet({
    required this.future,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.30 : 0.12),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gefällt mir',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Schließen',
                  ),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<PrivateProfileModel>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 26, 16, 34),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const _ProfileMomentLikersState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Likes konnten nicht geladen werden',
                      message: 'Bitte versuche es gleich erneut.',
                    );
                  }

                  final profiles = snapshot.data ?? const <PrivateProfileModel>[];

                  if (profiles.isEmpty) {
                    return const _ProfileMomentLikersState(
                      icon: Icons.thumb_up_alt_outlined,
                      title: 'Noch keine sichtbaren Likes',
                      message:
                          'Sobald jemand den Beitrag mag, erscheint die Person hier.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                    itemCount: profiles.length,
                    separatorBuilder: (context, index) {
                      return Divider(
                        height: 1,
                        color: colorScheme.outline.withValues(alpha: 0.10),
                      );
                    },
                    itemBuilder: (context, index) {
                      final profile = profiles[index];

                      return _ProfileMomentLikerTile(
                        profile: profile,
                        onTap: () => onOpenProfile(profile),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMomentLikersState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ProfileMomentLikersState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.58),
              height: 1.32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMomentLikerTile extends StatelessWidget {
  final PrivateProfileModel profile;
  final VoidCallback onTap;

  const _ProfileMomentLikerTile({
    required this.profile,
    required this.onTap,
  });

  String get _displayName {
    final value = profile.displayName.trim();
    if (value.isNotEmpty) return value;

    final username = profile.username.trim();
    if (username.isNotEmpty) return username;

    return 'Luma Nutzer';
  }

  String get _username {
    final value = profile.username.trim();
    if (value.isEmpty) return '';
    return value.startsWith('@') ? value : '@$value';
  }

  String get _avatarUrl => profile.profileImageUrl.trim();

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'LU';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = _displayName;
    final username = _username;
    final avatarUrl = _avatarUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 11, 8, 11),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          _initials(displayName),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              _initials(displayName),
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.54),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.thumb_up_alt_rounded,
                color: colorScheme.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

