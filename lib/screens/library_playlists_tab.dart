import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/app_state.dart';

class LibraryPlaylistsTab extends StatefulWidget {
  final AppState appState;

  const LibraryPlaylistsTab({super.key, required this.appState});

  @override
  State<LibraryPlaylistsTab> createState() => _LibraryPlaylistsTabState();
}

class _LibraryPlaylistsTabState extends State<LibraryPlaylistsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;

        return Scaffold(
          backgroundColor: const Color(0xFF111113),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111113),
            elevation: 0,
            title: const Text(
              'Biblioteca',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded, color: Colors.pinkAccent, size: 28),
                tooltip: 'Nueva Playlist',
                onPressed: () => _showCreatePlaylistDialog(context, appState),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.pinkAccent,
              labelColor: Colors.pinkAccent,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Canciones y Medios'),
                Tab(text: 'Playlists'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSongsView(context, appState),
              _buildPlaylistsView(context, appState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongsView(BuildContext context, AppState appState) {
    final filtered = appState.library.where((item) {
      final q = _searchQuery.toLowerCase();
      return item.title.toLowerCase().contains(q) ||
          item.artist.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Buscador estilo Apple Music
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar en tus canciones o artistas...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1F1F23),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Botones gemelos "Reproducir" y "Aleatorio" estilo Apple Music
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF252529),
                      foregroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Reproducir',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      appState.playItem(filtered.first, contextList: filtered);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF252529),
                      foregroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text(
                      'Aleatorio',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      final shuffled = List<MediaItemModel>.from(filtered)..shuffle();
                      appState.playItem(shuffled.first, contextList: shuffled);
                    },
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no tienes música descargada.\nVe a la pestaña YouTube y pulsa "Descargar".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isPlayingThis = appState.currentTrack?.id == item.id;

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.thumbnailUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.white12,
                            child: const Icon(Icons.music_note, color: Colors.white),
                          ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlayingThis ? Colors.pinkAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${item.artist} • ${item.format}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                        color: const Color(0xFF252528),
                        onSelected: (action) {
                          if (action == 'play_next') {
                            appState.playNextInQueue(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('⏭️ Se reproducirá a continuación: ${item.title}')),
                            );
                          } else if (action == 'add_queue') {
                            appState.addToEndOfQueue(item);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('➕ Añadido a la cola: ${item.title}')),
                            );
                          } else if (action == 'add_playlist') {
                            _showAddToPlaylistSheet(context, appState, item);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'play_next',
                            child: Row(
                              children: [
                                Icon(Icons.queue_play_next_rounded, color: Colors.pinkAccent, size: 20),
                                SizedBox(width: 10),
                                Text('Reproducir a continuación', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'add_queue',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 20),
                                SizedBox(width: 10),
                                Text('Agregar al final de la cola', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'add_playlist',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_add_rounded, color: Colors.white70, size: 20),
                                SizedBox(width: 10),
                                Text('Agregar a una Playlist...', style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => appState.playItem(item, contextList: filtered),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsView(BuildContext context, AppState appState) {
    if (appState.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Aún no has creado ninguna Playlist.',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Crear Primera Playlist', style: TextStyle(color: Colors.white)),
              onPressed: () => _showCreatePlaylistDialog(context, appState),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: appState.playlists.length,
      itemBuilder: (context, index) {
        final pl = appState.playlists[index];
        final tracks = appState.getPlaylistTracks(pl);

        return Card(
          color: const Color(0xFF1E1E22),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.pinkAccent, Colors.deepPurpleAccent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.library_music_rounded, color: Colors.white),
            ),
            title: Text(
              pl.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${tracks.length} canción(es)',
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
              onPressed: () => appState.deletePlaylist(pl.id),
            ),
            onTap: () => _openPlaylistDetailSheet(context, appState, pl),
          ),
        );
      },
    );
  }

  void _openPlaylistDetailSheet(
    BuildContext context,
    AppState appState,
    PlaylistModel pl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: appState,
          builder: (_, __) {
            final tracks = appState.getPlaylistTracks(pl);
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pl.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (tracks.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            label: const Text('Reproducir Todo', style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              appState.playItem(tracks.first, contextList: tracks);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: tracks.isEmpty
                          ? const Center(
                              child: Text(
                                'Esta playlist está vacía.\nAgrega canciones desde el menú de 3 puntos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: tracks.length,
                              itemBuilder: (_, idx) {
                                final t = tracks[idx];
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      t.thumbnailUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text(t.title, style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(t.artist, style: const TextStyle(color: Colors.white54)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    onPressed: () => appState.removeTrackFromPlaylist(pl.id, t.id),
                                  ),
                                  onTap: () => appState.playItem(t, contextList: tracks),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, AppState appState) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242428),
        title: const Text('Nueva Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre de la playlist (ej. Favoritas, Gym)...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                appState.createPlaylist(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(
    BuildContext context,
    AppState appState,
    MediaItemModel item,
  ) {
    if (appState.playlists.isEmpty) {
      _showCreatePlaylistDialog(context, appState);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Selecciona una Playlist',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            ...appState.playlists.map(
              (pl) => ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: Colors.pinkAccent),
                title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  appState.addTrackToPlaylist(pl.id, item.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Agregado a "${pl.name}"')),
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
