// Pfad: lib/presentation/screens/messenger_preview_screen.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../application/messenger_controller.dart';
import '../../application/messenger_remote_mode.dart';
import '../../application/user_identity_controller.dart';
import '../../domain/models/chat_model.dart';
import '../widgets/messenger_conversation_card.dart';
import '../widgets/messenger_inbox_filter_bar.dart';
import '../widgets/messenger_new_conversation_sheet.dart';
import '../widgets/messenger_search_bar.dart';
import '../widgets/messenger_search_empty_state.dart';
import '../widgets/messenger_section_header.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class MessengerPreviewScreen extends StatefulWidget {
  const MessengerPreviewScreen({super.key});

  @override
  State<MessengerPreviewScreen> createState() => _MessengerPreviewScreenState();
}

class _MessengerPreviewScreenState extends State<MessengerPreviewScreen> {
  final MessengerController _controller = MessengerController.instance;
  final UserIdentityController _identityController =
      UserIdentityController.instance;

  late final TextEditingController _searchController;

  bool _isRefreshing = false;
  bool _isOpeningConversation = false;
  bool _rebuildScheduled = false;
  MessengerInboxFilter _activeFilter = MessengerInboxFilter.all;

  static const Set<String> _blockedLegacyChatIds = {
    'chat_001',
    'chat_002',
    'chat_003',
    'chat_004',
    'chat_005',
  };

  static const Set<String> _blockedLegacyUserIds = {
    'user_me',
    'current_user',
    'developer_user',
    'mock_user',
    'unknown_user',
  };

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);

    _controller.addListener(_handleMessengerChanged);
    _identityController.addListener(_handleIdentityChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _identityController.initialize();

      if (!mounted) return;

      await _configureMessengerForCurrentIdentity();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();

    _controller.removeListener(_handleMessengerChanged);
    _identityController.removeListener(_handleIdentityChanged);

    super.dispose();
  }

  String get _currentUserId {
    return _identityController.currentUserId?.trim() ?? '';
  }

  Future<void> _configureMessengerForCurrentIdentity() async {
    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) {
      await _controller.configureRemoteMode(
        mode: MessengerRemoteMode.remoteOnly,
      );
      return;
    }

    await _controller.configureRemoteMode(
      mode: MessengerRemoteMode.remoteOnly,
      currentUserId: currentUserId,
    );
  }

  void _handleIdentityChanged() {
    if (!mounted) return;

    unawaited(_configureMessengerForCurrentIdentity());
    _scheduleRebuild();
  }

  void _handleSearchChanged() {
    _scheduleRebuild();
  }

  void _handleMessengerChanged() {
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (!mounted || _rebuildScheduled) {
      return;
    }

    _rebuildScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;

      if (!mounted) {
        return;
      }

      setState(() {});
    });
  }


  void _showFeedback(
    String message, {
    SnackBarAction? action,
  }) {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.inverseSurface,
          action: action,
        ),
      );
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _configureMessengerForCurrentIdentity();

      if (mounted) {
        _showFeedback('Messenger aktualisiert');
      }
    } catch (error) {
      if (mounted) {
        debugPrint('Messenger refresh failed: $error');
        _showFeedback('Messenger konnte nicht aktualisiert werden');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openNewConversationSheet() async {
    if (_isOpeningConversation) return;

    if (_currentUserId.isEmpty) {
      _showFeedback('Melde dich an, um eine Unterhaltung zu starten.');
      return;
    }

    final selectedParticipant = await showModalBottomSheet<ChatParticipantModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.48),
      builder: (context) {
        return MessengerNewConversationSheet(
          controller: _controller,
        );
      },
    );

    if (!mounted || selectedParticipant == null) return;

    if (!_isUsableRemoteUserId(selectedParticipant.userId)) {
      _showFeedback('Dieser Kontakt ist kein gültiger Firebase-Nutzer.');
      return;
    }

    await _openOrCreateConversation(selectedParticipant);
  }

  Future<void> _openOrCreateConversation(
    ChatParticipantModel selectedParticipant,
  ) async {
    if (_isOpeningConversation) return;

    setState(() {
      _isOpeningConversation = true;
    });

    try {
      final existingBefore =
          _controller.directChatWithUser(selectedParticipant.userId) != null;

      final chat = await _controller.openOrCreateDirectChat(
        selectedParticipant,
      );

      if (!mounted) return;

      if (!_isVisibleRemoteChat(chat)) {
        _showFeedback('Diese Unterhaltung ist nicht für deinen Account gültig.');
        return;
      }

      _showFeedback(
        existingBefore
            ? 'Bestehende Unterhaltung geöffnet'
            : 'Neue Unterhaltung erstellt',
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chat: chat),
        ),
      );
    } catch (error) {
      if (mounted) {
        debugPrint('Messenger open/create conversation failed: $error');
        _showFeedback('Unterhaltung konnte nicht geöffnet werden');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningConversation = false;
        });
      }
    }
  }

  void _openExistingConversation(ChatModel chat) {
    if (_isOpeningConversation) return;

    if (!_isVisibleRemoteChat(chat)) {
      _showFeedback('Diese Unterhaltung ist nicht für deinen Account gültig.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chat: chat),
      ),
    );
  }

  bool _isVisibleRemoteChat(ChatModel chat) {
    final currentUserId = _currentUserId;

    if (currentUserId.isEmpty) return false;

    final chatId = chat.id.trim();

    if (chatId.isEmpty) return false;
    if (_blockedLegacyChatIds.contains(chatId)) return false;
    if (chatId.startsWith('mock_')) return false;
    if (chatId.startsWith('local_')) return false;

    if (!chat.participantIds.contains(currentUserId)) return false;
    if (chat.isDeletedForCurrentUser) return false;

    final hasValidOtherParticipantId = chat.participantIds.any((userId) {
      final cleanedUserId = userId.trim();

      return cleanedUserId != currentUserId &&
          _isUsableRemoteUserId(cleanedUserId);
    });

    final hasValidOtherParticipantPreview = chat.participants.any((participant) {
      final participantUserId = participant.userId.trim();

      return participantUserId != currentUserId &&
          _isUsableRemoteUserId(participantUserId);
    });

    return hasValidOtherParticipantId || hasValidOtherParticipantPreview;
  }

  bool _isUsableRemoteUserId(String value) {
    final cleanedValue = value.trim();

    if (cleanedValue.isEmpty) return false;
    if (_blockedLegacyUserIds.contains(cleanedValue)) return false;

    if (cleanedValue.startsWith('user_')) return false;
    if (cleanedValue.startsWith('mock_')) return false;
    if (cleanedValue.startsWith('suggestion_')) return false;
    if (cleanedValue.startsWith('activity_')) return false;
    if (cleanedValue.startsWith('interest_')) return false;

    return true;
  }

  List<ChatModel> _visibleRemoteChats(List<ChatModel> chats) {
    final filteredChats = chats.where(_isVisibleRemoteChat).toList();

    filteredChats.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      final activityCompare =
          b.lastMessageAt.compareTo(a.lastMessageAt);

      if (activityCompare != 0) {
        return activityCompare;
      }

      final updatedCompare =
          b.updatedAt.compareTo(a.updatedAt);

      if (updatedCompare != 0) {
        return updatedCompare;
      }

      final unreadCompare =
          b.unreadCount.compareTo(a.unreadCount);

      if (unreadCompare != 0) {
        return unreadCompare;
      }

      return a.id.compareTo(b.id);
    });

    return List.unmodifiable(filteredChats);
  }

  String _otherParticipantUserId(ChatModel chat) {
    final currentUserId = _currentUserId;

    for (final participantId in chat.participantIds) {
      final cleanedParticipantId = participantId.trim();
      if (cleanedParticipantId.isEmpty) continue;
      if (cleanedParticipantId == currentUserId) continue;
      return cleanedParticipantId;
    }

    for (final participant in chat.participants) {
      final cleanedParticipantId = participant.userId.trim();
      if (cleanedParticipantId.isEmpty) continue;
      if (cleanedParticipantId == currentUserId) continue;
      return cleanedParticipantId;
    }

    return '';
  }

  void _openConversationProfile(ChatModel chat) {
    final profileUserId = _otherParticipantUserId(chat);

    if (profileUserId.isEmpty) {
      _showFeedback('Profil konnte nicht geöffnet werden.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          isOwnProfile: profileUserId == _currentUserId,
          userId: profileUserId,
        ),
      ),
    );
  }

  Future<bool> _toggleConversationBlocked(ChatModel chat) async {
    final currentlyBlocked = _controller.isChatBlocked(chat.id);

    final success = currentlyBlocked
        ? await _controller.unblockUserInChat(chat.id)
        : await _controller.blockUserInChat(chat.id);

    if (!mounted) return success;

    _showFeedback(
      success
          ? currentlyBlocked
              ? 'Blockierung aufgehoben'
              : 'Person blockiert'
          : currentlyBlocked
              ? 'Blockierung konnte nicht aufgehoben werden'
              : 'Person konnte nicht blockiert werden',
    );

    return success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = _searchController.text;
    final baseChats = _visibleRemoteChats(
      _controller.filteredChats(query),
    );
    final filteredChats = _applyInboxFilter(baseChats);
    final activeChats = filteredChats.where((chat) => !chat.isArchived).toList();
    final archivedChats = filteredChats.where((chat) => chat.isArchived).toList();
    final pinnedChats = activeChats.where((chat) => chat.isPinned).toList();
    final regularChats = activeChats.where((chat) => !chat.isPinned).toList();
    final activeBaseChats = baseChats.where((chat) => !chat.isArchived).toList();
    final allCount = activeBaseChats.length;
    final unreadCount =
        activeBaseChats.where((chat) => chat.hasUnreadMessages).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _topGlowColor(colorScheme),
            _pageBackground(colorScheme),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.07),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 120,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              _MessengerTopPanel(
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    const _MessengerHeroHeader(),
                    const SizedBox(height: 12),
                    MessengerSearchBar(
                      controller: _searchController,
                      isRefreshing: _isRefreshing || _isOpeningConversation,
                      onOpenComposer: _openNewConversationSheet,
                    ),
                    MessengerInboxFilterBar(
                      activeFilter: _activeFilter,
                      allCount: allCount,
                      unreadCount: unreadCount,
                      onChanged: (filter) {
                        if (_activeFilter == filter) return;

                        setState(() {
                          _activeFilter = filter;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: activeChats.isEmpty && archivedChats.isEmpty
                    ? MessengerSearchEmptyState(
                        query: query,
                        activeFilter: _activeFilter,
                      )
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
                          children: [
                            if (pinnedChats.isNotEmpty) ...[
                              const MessengerSectionHeader(title: 'Angepinnt'),
                              const SizedBox(height: 6),
                              ..._buildChatCards(pinnedChats),
                              const SizedBox(height: 16),
                            ],
                            if (regularChats.isNotEmpty) ...[
                              MessengerSectionHeader(
                                title: pinnedChats.isNotEmpty
                                    ? 'Alle Unterhaltungen'
                                    : 'Unterhaltungen',
                              ),
                              const SizedBox(height: 8),
                              ..._buildChatCards(regularChats),
                            ],
                            if (archivedChats.isNotEmpty) ...[
                              if (pinnedChats.isNotEmpty ||
                                  regularChats.isNotEmpty)
                                const SizedBox(height: 18),
                              MessengerSectionHeader(
                                title: 'Archiviert (${archivedChats.length})',
                              ),
                              const SizedBox(height: 8),
                              ..._buildChatCards(
                                archivedChats,
                                isArchivedSection: true,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _pageBackground(ColorScheme colorScheme) {
    if (colorScheme.brightness == Brightness.dark) {
      return Color.alphaBlend(
        Colors.white.withValues(alpha: 0.015),
        colorScheme.surface,
      );
    }

    return Colors.white;
  }

  Color _topGlowColor(ColorScheme colorScheme) {
    if (colorScheme.brightness == Brightness.dark) {
      return Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.06),
        colorScheme.surface,
      );
    }

    return Colors.white;
  }

  List<ChatModel> _applyInboxFilter(List<ChatModel> chats) {
    switch (_activeFilter) {
      case MessengerInboxFilter.all:
        return chats;
      case MessengerInboxFilter.unread:
        return chats.where((chat) => chat.hasUnreadMessages).toList();
      case MessengerInboxFilter.photos:
        return chats.where((chat) {
          final latest = _controller.latestMessageForChat(chat.id);
          return latest?.isImageMessage ?? false;
        }).toList();
      case MessengerInboxFilter.audio:
        return chats.where((chat) {
          final latest = _controller.latestMessageForChat(chat.id);
          return latest?.isAudioMessage ?? false;
        }).toList();
    }
  }

  List<Widget> _buildChatCards(
    List<ChatModel> chats, {
    bool isArchivedSection = false,
  }) {
    return List.generate(
      chats.length,
      (index) {
        final chat = chats[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == chats.length - 1 ? 0 : 9,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: MessengerConversationCard(
              key: ValueKey(chat.id),
              chat: chat,
              previewText:
                  _controller.conversationPreviewText(chat),
              latestMessage:
                  _controller.latestMessageForChat(chat.id),
              activityLabel:
                  _controller.participantActivityLabelForChat(
                chat.id,
              ),
              isTyping:
                  _controller.isParticipantTypingInChat(
                chat.id,
              ),
              isRecordingAudio:
                  _controller.isParticipantRecordingAudioInChat(
                chat.id,
              ),
              isUploadingMedia:
                  _controller.isParticipantUploadingMediaInChat(
                chat.id,
              ),
              isSendingMessage:
                  _controller.isParticipantSendingMessageInChat(
                chat.id,
              ),
              onOpen: () {
                _openExistingConversation(chat);
              },
              onTogglePinned: () {
                final isPinned =
                    _controller.togglePinned(chat.id);

                _showFeedback(
                  isPinned
                      ? 'Unterhaltung angepinnt'
                      : 'Unterhaltung gelöst',
                );
              },
              onToggleMuted: () {
                final isMuted =
                    _controller.toggleMuted(chat.id);

                _showFeedback(
                  isMuted
                      ? 'Unterhaltung stummgeschaltet'
                      : 'Unterhaltung wieder aktiviert',
                );
              },
              onToggleArchived: () {
                final isArchived =
                    _controller.toggleArchived(chat.id);

                _showFeedback(
                  isArchived
                      ? 'Unterhaltung archiviert'
                      : 'Unterhaltung aus dem Archiv zurückgeholt',
                );
              },
              onOpenProfile: () {
                _openConversationProfile(chat);
              },
              onToggleBlocked: () {
                return _toggleConversationBlocked(chat);
              },
              isBlocked: _controller.isChatBlocked(chat.id),
              onDelete: () {
                _confirmDeleteConversation(chat);
              },
              onMarkUnread: chat.hasUnreadMessages
                  ? null
                  : () async {
                      final marked =
                          await _controller.markChatAsUnread(
                        chat.id,
                      );

                      if (!mounted) {
                        return marked;
                      }

                      _showFeedback(
                        marked
                            ? 'Unterhaltung als ungelesen markiert'
                            : 'Unterhaltung konnte nicht als ungelesen markiert werden',
                      );

                      return marked;
                    },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showConversationQuickActions(ChatModel chat) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: colorScheme.scrim.withValues(alpha: 0.42),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.brightness == Brightness.dark
                        ? colorScheme.surface.withValues(alpha: 0.84)
                        : Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: colorScheme.brightness == Brightness.dark
                            ? 0.06
                            : 0.46,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ArchiveActionTile(
                          icon: chat.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          title: chat.isArchived
                              ? 'Aus Archiv holen'
                              : 'Archivieren',
                          subtitle: chat.isArchived
                              ? 'Zeigt diese Unterhaltung wieder in der Hauptliste.'
                              : 'Blendet diese Unterhaltung aus der Hauptliste aus.',
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _toggleArchived(chat);
                          },
                        ),
                        _ArchiveActionTile(
                          icon: Icons.delete_outline_rounded,
                          title: 'Unterhaltung löschen',
                          subtitle: 'Blendet diesen Chat nur für dich aus.',
                          isDestructive: true,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _confirmDeleteConversation(chat);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleArchived(ChatModel chat) {
    final isArchived = _controller.toggleArchived(chat.id);

    _showFeedback(
      isArchived
          ? 'Unterhaltung archiviert'
          : 'Unterhaltung wieder in der Hauptliste',
      action: SnackBarAction(
        label: 'Rückgängig',
        textColor: Theme.of(context).colorScheme.primary,
        onPressed: () {
          final reverted = _controller.toggleArchived(chat.id);
          _showFeedback(
            reverted
                ? 'Unterhaltung archiviert'
                : 'Unterhaltung wieder in der Hauptliste',
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteConversation(ChatModel chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Unterhaltung löschen?'),
          content: const Text(
            'Der Chat wird nur für dich aus der Liste entfernt. Nachrichten bleiben für andere Teilnehmer erhalten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final deleted = _controller.deleteChat(chat.id);
    if (!deleted) return;

    _showFeedback(
      'Unterhaltung gelöscht',
      action: SnackBarAction(
        label: 'Rückgängig',
        textColor: Theme.of(context).colorScheme.primary,
        onPressed: () {
          final restored = _controller.restoreLastDeletedChat();
          if (restored) {
            _showFeedback('Unterhaltung wiederhergestellt');
          }
        },
      ),
    );
  }
}



class _ArchiveActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ArchiveActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_ArchiveActionTile> createState() => _ArchiveActionTileState();
}

class _ArchiveActionTileState extends State<_ArchiveActionTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;

    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedColor = widget.isDestructive
        ? colorScheme.error
        : colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.982 : 1,
        duration: const Duration(milliseconds: 135),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(
              alpha: colorScheme.brightness == Brightness.dark
                  ? (_isPressed ? 0.060 : 0.040)
                  : (_isPressed ? 0.045 : 0.026),
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: resolvedColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.10,
                        color: widget.isDestructive
                      ? colorScheme.error.withValues(alpha: 0.90)
                      : colorScheme.onSurface.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.03,
                        color: colorScheme.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessengerHeroHeader extends StatelessWidget {
  const _MessengerHeroHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Messenger',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            height: 0.98,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.18,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MessengerTopPanel extends StatelessWidget {
  final Widget child;

  const _MessengerTopPanel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _panelColor(colorScheme),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1D8C9).withValues(alpha: 0.62),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 28,
                spreadRadius: -16,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
        ),
      ),
    );
  }

  Color _panelColor(ColorScheme colorScheme) {
    if (colorScheme.brightness == Brightness.dark) {
      return colorScheme.surface.withValues(alpha: 0.76);
    }

    return Colors.white.withValues(alpha: 0.96);
  }
}
