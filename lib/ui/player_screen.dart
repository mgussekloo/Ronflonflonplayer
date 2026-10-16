import 'dart:async';
import 'package:flutter/material.dart';
import '../models/episode.dart';
import '../player/player_controller.dart';
import '../services/library_repository.dart';
import 'poster_theme.dart';

String formatTime(Duration value) {
  final seconds = value.inSeconds.clamp(0, 9007199254740);
  final minutes = seconds ~/ 60;
  return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

String episodeDate(Episode episode) {
  final date = episode.date;
  if (date == null) return 'Date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.controller,
    required this.library,
  });
  final PlayerController controller;
  final LibraryRepository library;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _offline = false;
  String? _error;
  String _query = '';
  bool _hideFinished = false;
  PlayerController get player => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.library.load();
      if (!mounted) return;
      await player.setEpisodes(result.episodes);
      if (!mounted) return;
      setState(() {
        _offline = result.offline;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach Archive.org. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(player.save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    widget.library.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final episodes = player.episodes
          .where(
            (episode) =>
                (!_hideFinished ||
                    !player.state.completed.contains(episode.id)) &&
                '${episode.label} ${episodeDate(episode)} ${episode.fileName}'
                    .toLowerCase()
                    .contains(_query),
          )
          .toList();
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PosterHeader(onAbout: () => _showAbout(context)),
                          const SizedBox(height: 24),
                          _PlayerCard(player: player),
                          if (_offline)
                            const _Notice(
                              text:
                                  'Using the saved episode list. Previously downloaded episodes can still play.',
                            ),
                          if (player.warning != null)
                            _Notice(text: player.warning!, warning: true),
                          if (player.message != null)
                            _Notice(text: player.message!, warning: true),
                          const SizedBox(height: 28),
                          Text(
                            'The episodes',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: PosterTheme.ink,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${player.episodes.length} available · ${player.episodes.where((e) => player.state.completed.contains(e.id)).length} finished',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Find an episode or date',
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() {
                              _query = value.trim().toLowerCase();
                            }),
                          ),
                          const SizedBox(height: 10),
                          FilterChip(
                            label: const Text('Hide finished'),
                            selected: _hideFinished,
                            onSelected: (value) => setState(() {
                              _hideFinished = value;
                            }),
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Text(_error!),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: _load,
                                    child: const Text('Try again'),
                                  ),
                                ],
                              ),
                            ),
                          if (!_loading && _error == null && episodes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No episodes match this view.'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.builder(
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final finished = player.state.completed.contains(
                          episode.id,
                        );
                        final selected = player.current?.id == episode.id;
                        final position = player.state.positionFor(episode.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: selected
                              ? PosterTheme.yellow
                              : PosterTheme.cream,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? PosterTheme.ink
                                    : PosterTheme.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: PosterTheme.ink,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                finished
                                    ? Icons.check
                                    : selected && player.playing
                                    ? Icons.equalizer
                                    : Icons.play_arrow_rounded,
                                color: selected
                                    ? PosterTheme.yellow
                                    : PosterTheme.ink,
                              ),
                            ),
                            title: Text(
                              episode.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${episodeDate(episode)} · ${formatTime(episode.duration)}${finished
                                  ? ' · Finished'
                                  : position > Duration.zero
                                  ? ' · ${formatTime(position)} played'
                                  : ''}',
                            ),
                            onTap: player.busy
                                ? null
                                : () => player.playEpisode(episode),
                            trailing: finished
                                ? IconButton(
                                    tooltip: 'Mark unfinished',
                                    icon: const Icon(Icons.undo),
                                    onPressed: player.busy
                                        ? null
                                        : () => player.markUnfinished(episode),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Audio from Internet Archive · Progress saved on this device only.\nEpisodes download when selected and are removed from app storage when finished.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  void _showAbout(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('A little radio time machine'),
      content: const SingleChildScrollView(
        child: Text(
          'This independent player uses the Ronflonflon collection on Archive.org. '
          'Episode numbers come from filenames; exact duplicate uploads are hidden. '
          'Missing numbers and incorrect or unavailable dates in the source are not filled in.\n\n'
          'An episode downloads fully before it plays. Unfinished downloads are kept for resuming; '
          'finished audio is removed from the app cache, not from the episode list. '
          'Selecting a finished episode downloads it again.\n\n'
          'Your current episode, position, and finished markers stay in this browser/device. '
          'Clearing site data removes them. Browsers can also evict audio when storage is low. '
          'There is no account or cross-device sync. Audio and metadata requests go to Archive.org.\n\n'
          'Offline audio requires HTTPS or localhost. Offline app startup is not included. '
          'Keep this page open while downloading or listening.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _PlayerCard extends StatefulWidget {
  const _PlayerCard({required this.player});
  final PlayerController player;
  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  double? _dragPosition;
  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final episode = player.current;
    final resume = player.resumeEpisode;
    final finished =
        episode != null && player.state.completed.contains(episode.id);
    final total = player.duration.inMilliseconds.toDouble();
    final position =
        (_dragPosition ?? player.position.inMilliseconds.toDouble()).clamp(
          0.0,
          total > 0 ? total : 1.0,
        );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PosterTheme.cream,
        border: Border.all(color: PosterTheme.ink, width: 2.5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: PosterTheme.ink, offset: Offset(5, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              player.busy
                  ? 'GETTING READY'
                  : player.playing
                  ? 'NOW PLAYING'
                  : finished
                  ? 'EPISODE FINISHED'
                  : 'YOUR LISTENING ROOM',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              episode?.label ?? 'Welcome to Ronflonflon',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              episode == null
                  ? 'Start at the beginning. We’ll remember your place.'
                  : episodeDate(episode),
            ),
            if (player.busy) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: player.downloadProgress),
              const SizedBox(height: 10),
              Text(
                player.downloadProgress == null
                    ? 'Opening or downloading audio…'
                    : player.downloadProgress! >= 1
                    ? 'Opening downloaded audio…'
                    : 'Downloading audio · ${(player.downloadProgress! * 100).round()}%',
              ),
              const SizedBox(height: 6),
              const Text(
                'Only this episode is downloaded. Large recordings may take a moment.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (episode != null && !finished && !player.busy) ...[
              const SizedBox(height: 8),
              Slider(
                value: position,
                max: total > 0 ? total : 1,
                label: formatTime(Duration(milliseconds: position.round())),
                onChanged: total > 0 && player.canSeek
                    ? (value) => setState(() {
                        _dragPosition = value;
                      })
                    : null,
                onChangeEnd: (value) {
                  setState(() {
                    _dragPosition = null;
                  });
                  unawaited(player.seek(Duration(milliseconds: value.round())));
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatTime(Duration(milliseconds: position.round()))),
                  Text(formatTime(player.duration)),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (episode != null && !finished)
                  IconButton.outlined(
                    tooltip: 'Back 15 seconds',
                    onPressed: !player.canSeek
                        ? null
                        : () => player.seek(
                            player.position - const Duration(seconds: 15),
                          ),
                    icon: const Icon(Icons.replay),
                  ),
                FilledButton.icon(
                  onPressed: player.busy || (episode == null && resume == null)
                      ? null
                      : () {
                          if (finished && resume != null) {
                            unawaited(player.playEpisode(resume));
                          } else {
                            unawaited(player.togglePlayback());
                          }
                        },
                  icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    player.playing
                        ? 'Pause'
                        : finished && resume != null
                        ? 'Continue · ${resume.label}'
                        : episode == null
                        ? 'Start listening'
                        : finished
                        ? 'Play again'
                        : 'Resume',
                  ),
                ),
                if (episode != null && !finished)
                  IconButton.outlined(
                    tooltip: 'Forward 30 seconds',
                    onPressed: !player.canSeek
                        ? null
                        : () => player.seek(
                            player.position + const Duration(seconds: 30),
                          ),
                    icon: const Icon(Icons.forward_30),
                  ),
                if (episode != null && !finished)
                  TextButton.icon(
                    onPressed: player.busy ? null : player.markFinished,
                    icon: const Icon(Icons.done),
                    label: const Text('Mark finished'),
                  ),
                if (player.buffering && !player.busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(warning ? Icons.warning_amber : Icons.wifi_off, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
