import 'package:flutter/material.dart';
import '../../services/video_search_service.dart';
import '../../models/video_summary.dart';
import '../../../video/models/video_model.dart';
import '../../../video/services/video_service.dart';
import '../widgets/keyword_chip.dart';
import 'video_details_screen.dart';
import '../../../playlist/screens/playlist_player_screen.dart';

class VideoSearchScreen extends StatefulWidget {
  final VideoService videoService;

  VideoSearchScreen({
    super.key,
    VideoService? videoService,
  }) : videoService = videoService ?? VideoService();

  @override
  State<VideoSearchScreen> createState() => _VideoSearchScreenState();
}

class _VideoSearchScreenState extends State<VideoSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoModel> _allVideos = [];
  List<VideoModel> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videos = await widget.videoService.getAllVideos();
      setState(() {
        _allVideos = videos;
        _searchResults = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading videos: $e';
        _isLoading = false;
      });
    }
  }

  void _playAllVideos() {
    if (_searchResults.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistPlayerScreen(
          videos: _searchResults,
          title: _searchController.text.isEmpty 
              ? 'All Videos' 
              : 'Search Results: ${_searchController.text}',
        ),
      ),
    );
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (query.isEmpty) {
        setState(() {
          _searchResults = _allVideos;
          _isLoading = false;
        });
      } else {
        final results = await widget.videoService.searchVideosByKeyword(query);
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching videos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Search bar in app bar
          SliverAppBar(
            floating: true,
            pinned: true,
            title: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search videos by keyword...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchController.text.isEmpty
                          ? 'All Videos'
                          : 'Search Results',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _searchResults.isEmpty ? null : _playAllVideos,
                      icon: const Icon(Icons.play_circle_filled),
                      label: const Text('Play All'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator or error message
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          // No results found state
          else if (_searchResults.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'No videos available'
                      : 'No videos found for "${_searchController.text}"',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          // Video list
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = _searchResults[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlaylistPlayerScreen(
                              videos: _searchResults,
                              title: _searchController.text.isEmpty 
                                  ? 'All Videos' 
                                  : 'Search Results: ${_searchController.text}',
                              initialVideoIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // Thumbnail
                            Container(
                              width: 120,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (video.thumbnailUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        video.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 68,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.video_library),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Title and keywords
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.suggestedTitle ?? 'Untitled Video',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (video.keywords?.isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      video.keywords!
                                          .map((k) => k.replaceAll('_', ' '))
                                          .join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _searchResults.length,
              ),
            ),
        ],
      ),
    );
  }
} 