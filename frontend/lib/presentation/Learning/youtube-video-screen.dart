import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // Import for Random
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'video-player-dialog.dart';
import 'continue-watching-section.dart';
import 'all-videos-section.dart';
import 'video-utils.dart';

class YouTubeVideoScreen extends StatefulWidget {
  const YouTubeVideoScreen({Key? key}) : super(key: key);

  @override
  _YouTubeVideoScreenState createState() => _YouTubeVideoScreenState();
}

class _YouTubeVideoScreenState extends State<YouTubeVideoScreen> {
  List<Map<String, String>> videos = [];
  bool isLoading = true;
  String? errorMessage;
  YoutubePlayerController? _controller;
  List<Map<String, dynamic>> continueWatchingList = [];
  bool _isCaptionOn = false;
  String? _currentUserId;
  late StreamSubscription<User?> _authSubscription;
  String? _currentVideoId;
  int _currentVideoPosition = 0;
  final Random _random = Random(); // Random number generator

  // Backend URL
  final String backendUrl =
      'https://lexfy-vocabulary-enhancement-app.onrender.com/api/learning/videos';

  // Number of requests to make to ensure variety
  final int numberOfRequests =
      5; // Adjust this based on how many different categories you want

  @override
  void initState() {
    super.initState();

    // Clear any existing data
    _clearContinueWatchingList();

    // Get the current user and set up auth listener
    _getCurrentUser();

    // Listen for auth state changes
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // If user changed, update the ID and reload data
      if (_currentUserId != user?.uid) {
        setState(() {
          _currentUserId = user?.uid;
          // Clear the list immediately to avoid showing previous user's data
          continueWatchingList = [];
        });

        // Load the new user's data
        _loadContinueWatchingList();
      }
    });

    _initializeData();
  }

  Future<void> _getCurrentUser() async {
    // Get current user ID from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _currentUserId = user?.uid;
    });
  }

  Future<void> _initializeData() async {
    await fetchMixedVideos();
    await _loadContinueWatchingList();
  }

  // Clear the continue watching list in memory
  void _clearContinueWatchingList() {
    setState(() {
      continueWatchingList = [];
    });
  }

  // Shuffle a list using the Fisher-Yates algorithm
  void _shuffleList<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      int j = _random.nextInt(i + 1);
      // Swap elements
      T temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  // Interleave multiple lists to ensure variety
  List<T> _interleaveLists<T>(List<List<T>> lists) {
    // Find the maximum length of any list
    int maxLength = 0;
    for (var list in lists) {
      if (list.length > maxLength) {
        maxLength = list.length;
      }
    }

    // Create a result list
    List<T> result = [];

    // Interleave the lists
    for (int i = 0; i < maxLength; i++) {
      for (var list in lists) {
        if (i < list.length) {
          result.add(list[i]);
        }
      }
    }

    return result;
  }

  // Fetch videos from your backend
  Future<List<Map<String, String>>> fetchVideosFromBackend() async {
    try {
      final response = await http.get(Uri.parse(backendUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((video) => {
                  "id": video["id"].toString(),
                  "title": video["title"].toString(),
                  "thumbnail": video["thumbnail"].toString(),
                })
            .toList();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching videos: $error');
      return [];
    }
  }

  // Fetch videos from multiple requests to ensure variety
  Future<void> fetchMixedVideos() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Make multiple requests to get different categories
      List<List<Map<String, String>>> allCategoryVideos = [];

      // Make several requests to get different random queries
      for (int i = 0; i < numberOfRequests; i++) {
        final categoryVideos = await fetchVideosFromBackend();
        if (categoryVideos.isNotEmpty) {
          // Add a fake category based on request number for tracking
          for (var video in categoryVideos) {
            video["category"] = "category_$i";
          }
          allCategoryVideos.add(categoryVideos);
        }

        // Add a small delay between requests to ensure different random queries
        if (i < numberOfRequests - 1) {
          await Future.delayed(Duration(milliseconds: 300));
        }
      }

      // If we got videos from at least one request
      if (allCategoryVideos.isNotEmpty) {
        // Interleave the videos from different requests
        final mixedVideos = _interleaveLists(allCategoryVideos);

        // Remove duplicates (in case the same video appears in multiple requests)
        final Map<String, Map<String, String>> uniqueVideos = {};
        for (var video in mixedVideos) {
          if (!uniqueVideos.containsKey(video["id"])) {
            uniqueVideos[video["id"]!] = video;
          }
        }

        // Convert back to list and shuffle
        final List<Map<String, String>> finalVideos =
            uniqueVideos.values.toList();
        _shuffleList(finalVideos);

        setState(() {
          videos = finalVideos;
          isLoading = false;
        });
      } else {
        throw Exception('No videos found from any request');
      }
    } catch (error) {
      print('Error fetching mixed videos: $error');

      // For testing purposes, add some mock data if the API fails
      final List<Map<String, String>> mockVideos = [
        {
          "id": "axYAW7PuSIM",
          "title":
              "English study plan - 20-minute daily English learning routine - Marina Mogilko",
          "thumbnail": "https://img.youtube.com/vi/axYAW7PuSIM/0.jpg",
          "category": "grammar",
        },
        {
          "id": "2r3wiPc",
          "title":
              "Improve your English with this study PLAN: Intermediate to Advanced ",
          "thumbnail": "https://img.youtube.com/vi/2r3wiPc/0.jpg",
          "category": "speaking",
        },
        {
          "id": "uPACgfqVVy4",
          "title":
              "100 Common English Questions and Answers | How to Ask and Answer Questions in English",
          "thumbnail": "https://img.youtube.com/vi/uPACgfqVVy4/0.jpg",
          "category": "writing",
        },
        {
          "id": "BAJMNQXzrgg",
          "title":
              "How to improve your English speaking skills FAST (4 simple steps)",
          "thumbnail": "https://img.youtube.com/vi/BAJMNQXzrgg/0.jpg",
          "category": "vocabulary",
        },
        {
          "id": "eAGtfIjhP1k",
          "title":
              "Plural Nouns Pronunciation - /s/ /z/ or /iz/? (pronounce PERFECTLY every time!) ",
          "thumbnail": "https://img.youtube.com/vi/eAGtfIjhP1k/0.jpg",
          "category": "listening",
        },
        {
          "id": "8xgKH00iyt8",
          "title":
              "Prepositions Simplified Correct Usage of 'Work In At As For' for English Learners",
          "thumbnail": "https://img.youtube.com/vi/8xgKH00iyt8/0.jpg",
          "category": "professional",
        },
      ];

      // Shuffle the mock videos
      _shuffleList(mockVideos);

      setState(() {
        videos = mockVideos;
        isLoading = false;
      });
    }
  }

  Future<void> _saveVideoProgress(
      String videoId, int progress, int duration) async {
    // If no user is logged in, don't save progress
    if (_currentUserId == null) {
      return;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String watchKey = 'continueWatchingList_$_currentUserId';

      // Find video info from our videos list
      final Map<String, String>? videoInfo =
          videos.firstWhere((v) => v["id"] == videoId, orElse: () => {});

      if (videoInfo == null || videoInfo.isEmpty) {
        return;
      }

      final Map<String, dynamic> entry = {
        "id": videoId,
        "title": videoInfo["title"],
        "thumbnail": videoInfo["thumbnail"],
        "category": videoInfo["category"],
        "progress": progress,
        "duration": duration,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "userId": _currentUserId, // Store user ID in the entry for verification
      };

      // Get the current list for this specific user
      final List<String> savedList = prefs.getStringList(watchKey) ?? [];

      // Parse existing list and filter out the current video
      final List<Map<String, dynamic>> existingList = [];
      for (var item in savedList) {
        try {
          final Map<String, dynamic> parsedItem = json.decode(item);
          // Only include items for the current user and not the current video
          if (parsedItem["userId"] == _currentUserId &&
              parsedItem["id"] != videoId) {
            existingList.add(parsedItem);
          }
        } catch (e) {
          // Skip items that can't be parsed
        }
      }

      // Only add to continue watching if not finished (less than 10 seconds from end)
      if (progress < duration - 10) {
        existingList.add(entry);
      }

      // Sort by timestamp (newest first)
      existingList.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

      // Take only the 10 most recent items
      final updatedList =
          existingList.take(10).map((item) => json.encode(item)).toList();

      // Save to SharedPreferences
      await prefs.setStringList(watchKey, updatedList);

      // Reload the list to update UI
      await _loadContinueWatchingList();
    } catch (e) {
      // Handle errors silently
    }
  }

  Future<void> _loadContinueWatchingList() async {
    // If no user is logged in, show empty list
    if (_currentUserId == null) {
      setState(() {
        continueWatchingList = [];
      });
      return;
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String watchKey = 'continueWatchingList_$_currentUserId';
      final List<String> savedList = prefs.getStringList(watchKey) ?? [];

      final List<Map<String, dynamic>> loadedList = [];
      for (var item in savedList) {
        try {
          final Map<String, dynamic> parsedItem = json.decode(item);
          // Double-check that this item belongs to the current user
          if (parsedItem["userId"] == _currentUserId) {
            loadedList.add(parsedItem);
          }
        } catch (e) {
          // Skip items that can't be parsed
        }
      }

      loadedList.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

      setState(() {
        continueWatchingList = loadedList;
      });
    } catch (e) {
      setState(() {
        continueWatchingList = [];
      });
    }
  }

  Future<void> _removeFromContinueWatching(String videoId) async {
    if (_currentUserId == null) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String watchKey = 'continueWatchingList_$_currentUserId';
      final List<String> savedList = prefs.getStringList(watchKey) ?? [];

      final updatedList = savedList.where((item) {
        try {
          final parsedItem = json.decode(item);
          // Only keep items that are not the one to remove AND belong to current user
          return parsedItem["id"] != videoId &&
              parsedItem["userId"] == _currentUserId;
        } catch (e) {
          return false; // Remove items that can't be parsed
        }
      }).toList();

      await prefs.setStringList(watchKey, updatedList);
      await _loadContinueWatchingList();
    } catch (e) {
      // Handle errors silently
    }
  }

  void _toggleCaptions() {
    // Store current video state
    if (_controller != null) {
      _currentVideoId = _controller!.metadata.videoId;
      _currentVideoPosition = _controller!.value.position.inSeconds;
    }

    setState(() {
      _isCaptionOn = !_isCaptionOn;
    });

    // Recreate controller with new caption settings if we're currently playing a video
    if (_controller != null && _currentVideoId != null) {
      _controller!.pause();

      // Create a new controller with updated caption settings
      _controller = YoutubePlayerController(
        initialVideoId: _currentVideoId!,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          startAt: _currentVideoPosition,
          enableCaption: _isCaptionOn,
          captionLanguage: 'en',
          controlsVisibleAtStart: true,
        ),
      );

      // Force dialog to rebuild with new controller
      Navigator.of(context).pop();
      _playVideoWithCurrentSettings(_currentVideoId!);
    }
  }

  // Helper method to play video with current settings
  void _playVideoWithCurrentSettings(String videoId) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(
        controller: _controller!,
        videoId: videoId,
        isCaptionOn: _isCaptionOn,
        onCaptionToggle: _toggleCaptions,
        onVideoEnd: _removeFromContinueWatching,
      ),
    ).then((_) {
      if (_controller != null && _controller!.value.position.inSeconds > 0) {
        _saveVideoProgress(
          videoId,
          _controller!.value.position.inSeconds,
          _controller!.metadata.duration.inSeconds,
        );
      }
      _controller?.pause();
    });
  }

  // Play video using a dialog that includes settings.
  void _playVideo(String videoId, {int startAt = 0}) {
    _currentVideoId = videoId;
    _currentVideoPosition = startAt;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        startAt: startAt,
        enableCaption: _isCaptionOn,
        captionLanguage: 'en',
        controlsVisibleAtStart: true,
      ),
    );

    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(
        controller: _controller!,
        videoId: videoId,
        isCaptionOn: _isCaptionOn,
        onCaptionToggle: _toggleCaptions,
        onVideoEnd: _removeFromContinueWatching,
      ),
    ).then((_) {
      if (_controller != null && _controller!.value.position.inSeconds > 0) {
        _saveVideoProgress(
          videoId,
          _controller!.value.position.inSeconds,
          _controller!.metadata.duration.inSeconds,
        );
      }
      _controller?.pause();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define your brand colors
    const Color primaryColor =
        Color(0xFF636AE8); // Your logo color (adjust as needed)
    const Color secondaryColor = Color(0xFF636AE8);
    const Color accentColor = Color(0xFF8C9EFF);
    const Color backgroundColor = Color(0xFFF5F7FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: fetchMixedVideos,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : errorMessage != null
                ? Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Continue watching section (will be hidden when empty)
                        if (continueWatchingList.isNotEmpty)
                          ContinueWatchingSection(
                            continueWatchingList: continueWatchingList,
                            onPlayVideo: _playVideo,
                            onRemoveVideo: _removeFromContinueWatching,
                          ),
                        // All videos section (now mixed from different requests)
                        AllVideosSection(
                          videos: videos,
                          onPlayVideo: _playVideo,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
