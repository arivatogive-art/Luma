// Pfad: lib/features/search/presentation/search_screen.dart
import 'package:flutter/material.dart';

import '../../profile/presentation/profile_screen.dart';
import '../application/profile_search_controller.dart';
import '../domain/profile_search_result.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ProfileSearchController _controller;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = ProfileSearchController()..addListener(_handleChanged);
    _textController = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openProfile(ProfileSearchResult result) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Profil'),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: ProfileScreen(userId: result.uid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suche'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: _controller.updateQuery,
              onSubmitted: _controller.search,
              decoration: InputDecoration(
                hintText: 'Nach Name oder @Benutzername suchen',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _textController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Suche löschen',
                        onPressed: () {
                          _textController.clear();
                          _controller.updateQuery('');
                          _focusNode.requestFocus();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_controller.state) {
      case ProfileSearchState.initial:
        return _CenteredMessage(
          icon: Icons.search_rounded,
          title: 'Menschen finden',
          message: 'Suche nach einem Namen oder @Benutzernamen.',
        );
      case ProfileSearchState.loading:
        return const Center(child: CircularProgressIndicator());
      case ProfileSearchState.empty:
        return _CenteredMessage(
          icon: Icons.person_search_rounded,
          title: 'Keine Treffer',
          message: 'Für „${_controller.query}“ wurde kein Profil gefunden.',
        );
      case ProfileSearchState.error:
        return _ErrorState(
          message: _controller.errorMessage ??
              'Die Suche konnte nicht geladen werden.',
          onRetry: _controller.retry,
        );
      case ProfileSearchState.loaded:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          itemCount: _controller.results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (context, index) {
            final result = _controller.results[index];
            return _ProfileSearchTile(
              result: result,
              onTap: () => _openProfile(result),
            );
          },
        );
    }
  }
}

class _ProfileSearchTile extends StatelessWidget {
  const _ProfileSearchTile({
    required this.result,
    required this.onTap,
  });

  final ProfileSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = result.username.trim();
    final avatarUrl = result.avatarUrl.trim();

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: CircleAvatar(
        radius: 24,
        foregroundImage:
            avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
        child: avatarUrl.isNotEmpty
            ? null
            : Text(
                _initialFor(result),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              result.displayName.isEmpty ? 'Luma Nutzer' : result.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (result.isVerified) ...<Widget>[
            const SizedBox(width: 5),
            Icon(
              Icons.verified_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
      subtitle: username.isEmpty
          ? null
          : Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  String _initialFor(ProfileSearchResult result) {
    final source = result.displayName.trim().isNotEmpty
        ? result.displayName.trim()
        : result.username.trim();
    if (source.isEmpty) return '?';
    return source.substring(0, 1).toUpperCase();
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.search_off_rounded, size: 42),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => onRetry(),
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
