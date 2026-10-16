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
  if (date == null) return 'Datum onbekend';
  const months = [
    'jan',
    'feb',
    'mrt',
    'apr',
    'mei',
    'jun',
    'jul',
    'aug',
    'sep',
    'okt',
    'nov',
    'dec',
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
              'Geen verbinding met Archive.org. Controleer je internetverbinding en probeer het opnieuw.';
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
                                  'Je ziet de opgeslagen lijst met uitzendingen. Eerder gedownloade uitzendingen kun je nog beluisteren.',
                            ),
                          if (player.warning != null)
                            _Notice(text: player.warning!, warning: true),
                          if (player.message != null)
                            _Notice(text: player.message!, warning: true),
                          const SizedBox(height: 28),
                          Text(
                            'De uitzendingen',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: PosterTheme.ink,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${player.episodes.length} beschikbaar · ${player.episodes.where((e) => player.state.completed.contains(e.id)).length} beluisterd',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Zoek een uitzending of datum',
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() {
                              _query = value.trim().toLowerCase();
                            }),
                          ),
                          const SizedBox(height: 10),
                          FilterChip(
                            label: const Text(
                              'Verberg beluisterde uitzendingen',
                            ),
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
                                    child: const Text('Opnieuw proberen'),
                                  ),
                                ],
                              ),
                            ),
                          if (!_loading && _error == null && episodes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Geen uitzendingen gevonden.'),
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
                                  ? ' · Beluisterd'
                                  : position > Duration.zero
                                  ? ' · ${formatTime(position)} beluisterd'
                                  : ''}',
                            ),
                            onTap: player.busy
                                ? null
                                : () => player.playEpisode(episode),
                            trailing: finished
                                ? IconButton(
                                    tooltip: 'Markeer als niet beluisterd',
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
                        'Audio van Internet Archive · Je luisterpositie wordt alleen op dit apparaat bewaard.\nUitzendingen worden gedownload zodra je ze kiest. Na het beluisteren worden ze uit de appopslag verwijderd.',
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
      title: const Text('Over deze speler'),
      content: const SingleChildScrollView(
        child: Text(
          'Deze onafhankelijke speler gebruikt de Ronflonflon-collectie op Archive.org. '
          'De uitzendingsnummers komen uit de bestandsnamen; identieke uploads worden verborgen. '
          'Ontbrekende nummers en onjuiste of ontbrekende datums in de bron worden niet aangevuld of gecorrigeerd.\n\n'
          'Een uitzending wordt volledig gedownload voordat deze wordt afgespeeld. '
          'Uitzendingen die je nog niet hebt uitgeluisterd, blijven bewaard zodat je verder kunt luisteren. '
          'Na het beluisteren wordt de audio uit de appopslag verwijderd, maar de uitzending blijft in de lijst staan. '
          'Als je een beluisterde uitzending kiest, wordt deze opnieuw gedownload.\n\n'
          'Je huidige uitzending, luisterpositie en beluisterde uitzendingen worden alleen in deze browser op dit apparaat bewaard. '
          'Als je de websitegegevens wist, verdwijnen ze. Je browser kan ook audio verwijderen als de opslagruimte bijna vol is. '
          'Er is geen account en er wordt niets gesynchroniseerd tussen apparaten. Audio en uitzendingsgegevens worden opgehaald bij Archive.org.\n\n'
          'Offline luisteren vereist HTTPS of localhost. Je kunt de app niet zonder internetverbinding openen. '
          'Houd deze pagina open tijdens het downloaden of luisteren.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Begrepen'),
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
                  ? 'EVEN GEDULD'
                  : player.playing
                  ? 'JE LUISTERT NAAR'
                  : finished
                  ? 'UITZENDING BELUISTERD'
                  : 'JOUW LUISTERKAMER',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              episode?.label ?? 'Welkom bij Ronflonflon',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              episode == null
                  ? 'Begin bij het begin. We onthouden waar je bent gebleven.'
                  : episodeDate(episode),
            ),
            if (player.busy) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: player.downloadProgress),
              const SizedBox(height: 10),
              Text(
                player.downloadProgress == null
                    ? 'Audio openen of downloaden…'
                    : player.downloadProgress! >= 1
                    ? 'Gedownloade audio openen…'
                    : 'Audio downloaden · ${(player.downloadProgress! * 100).round()}%',
              ),
              const SizedBox(height: 6),
              const Text(
                'Alleen deze uitzending wordt gedownload. Bij grote opnamen kan dit even duren.',
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
                    tooltip: '15 seconden terug',
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
                        ? 'Pauzeren'
                        : finished && resume != null
                        ? 'Verder luisteren · ${resume.label}'
                        : episode == null
                        ? 'Begin met luisteren'
                        : finished
                        ? 'Opnieuw afspelen'
                        : 'Verder luisteren',
                  ),
                ),
                if (episode != null && !finished)
                  IconButton.outlined(
                    tooltip: '30 seconden vooruit',
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
                    label: const Text('Markeer als beluisterd'),
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
