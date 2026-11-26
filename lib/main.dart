
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const DownloaderApp());
}

class DownloaderApp extends StatelessWidget {
  const DownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Downloader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DownloaderHome(),
    );
  }
}

class DownloadItem {
  final String name;
  final String path;
  final bool isVideo;

  DownloadItem({
    required this.name,
    required this.path,
    required this.isVideo,
  });
}

class DownloaderHome extends StatefulWidget {
  const DownloaderHome({super.key});

  @override
  State<DownloaderHome> createState() => _DownloaderHomeState();
}

class _DownloaderHomeState extends State<DownloaderHome> {
  final TextEditingController urlController = TextEditingController();
  final Dio dio = Dio();
  final AudioPlayer audioPlayer = AudioPlayer();

  final List<DownloadItem> downloads = [];

  bool downloading = false;
  double progress = 0;
  String status = '';
  String? currentPlaying;

  @override
  void dispose() {
    urlController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  String getFileName(String url, String extension) {
    try {
      final uri = Uri.parse(url);
      String name = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'media_${DateTime.now().millisecondsSinceEpoch}';

      name = Uri.decodeComponent(name);

      if (!name.contains('.')) {
        name = '$name.$extension';
      }

      name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      return name;
    } catch (_) {
      return 'media_${DateTime.now().millisecondsSinceEpoch}.$extension';
    }
  }

  Future<void> downloadMedia(bool video) async {
    final url = urlController.text.trim();

    if (url.isEmpty) {
      showMessage('أدخل رابط الملف أولاً');
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      showMessage('الرابط غير صحيح');
      return;
    }

    setState(() {
      downloading = true;
      progress = 0;
      status = 'جاري التحميل...';
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final folder = Directory('${directory.path}/Downloads');

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final filename = getFileName(url, video ? 'mp4' : 'mp3');
      final savePath = '${folder.path}/$filename';

      await dio.download(
        url,
        savePath,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              progress = received / total;
              status =
                  '${(progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      if (!mounted) return;

      setState(() {
        downloads.insert(
          0,
          DownloadItem(
            name: filename,
            path: savePath,
            isVideo: video,
          ),
        );
        downloading = false;
        progress = 1;
        status = 'اكتمل التحميل';
      });

      showMessage('تم تنزيل الملف بنجاح');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        downloading = false;
        status = 'فشل التحميل';
      });

      showMessage('فشل التنزيل. الرابط قد لا يكون رابط ملف مباشر.');
    }
  }

  Future<void> playAudio(DownloadItem item) async {
    try {
      await audioPlayer.setFilePath(item.path);
      await audioPlayer.play();

      if (mounted) {
        setState(() => currentPlaying = item.path);
      }
    } catch (e) {
      showMessage('تعذر تشغيل الملف الصوتي');
    }
  }

  Future<void> pauseAudio() async {
    await audioPlayer.pause();
  }

  Future<void> playVideo(DownloadItem item) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoScreen(path: item.path),
      ),
    );
  }

  Future<void> deleteFile(DownloadItem item) async {
    try {
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
      }

      if (mounted) {
        setState(() => downloads.remove(item));
      }

      showMessage('تم حذف الملف');
    } catch (_) {
      showMessage('تعذر حذف الملف');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget downloadButton({
    required String label,
    required IconData icon,
    required bool video,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: downloading
            ? null
            : () => downloadMedia(video),
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: video ? Colors.blueGrey : Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget downloadCard(DownloadItem item) {
    final playing = currentPlaying == item.path;

    return Card(
      color: const Color(0xFF201F27),
      child: ListTile(
        leading: Icon(
          item.isVideo ? Icons.video_file : Icons.music_note,
          color: item.isVideo ? Colors.blue : Colors.red,
          size: 32,
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(item.isVideo ? 'فيديو' : 'ملف صوتي'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              deleteFile(item);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'delete',
              child: Text('حذف'),
            ),
          ],
        ),
        onTap: () {
          if (item.isVideo) {
            playVideo(item);
          } else {
            playAudio(item);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Media Downloader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF191820),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.download_for_offline,
            size: 75,
            color: Colors.red,
          ),
          const SizedBox(height: 15),
          const Text(
            'تحميل صوت وفيديو',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أدخل رابط مباشر لملف صوتي أو فيديو',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://example.com/file.mp3',
              prefixIcon: const Icon(Icons.link),
              filled: true,
              fillColor: const Color(0xFF22212A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              downloadButton(
                label: 'تنزيل صوت',
                icon: Icons.music_note,
                video: false,
              ),
              const SizedBox(width: 10),
              downloadButton(
                label: 'تنزيل فيديو',
                icon: Icons.video_file,
                video: true,
              ),
            ],
          ),
          if (downloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              status,
              textAlign: TextAlign.center,
            ),
          ],
          if (status.isNotEmpty && !downloading) ...[
            const SizedBox(height: 12),
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
          const SizedBox(height: 25),
          const Divider(),
          const Text(
            'مكتبتي',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (downloads.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                'ماكو ملفات محمّلة لحد الآن',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ...downloads.map(downloadCard),
          if (currentPlaying != null) ...[
            const SizedBox(height: 15),
            Card(
              color: const Color(0xFF292731),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.red),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('تشغيل الصوت'),
                    ),
                    IconButton(
                      onPressed: pauseAudio,
                      icon: const Icon(Icons.pause),
                    ),
                    IconButton(
                      onPressed: () => audioPlayer.play(),
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class VideoScreen extends StatefulWidget {
  final String path;

  const VideoScreen({
    super.key,
    required this.path,
  });

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController controller;
  bool ready = false;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => ready = true);
          controller.play();
        }
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مشغل الفيديو')),
      backgroundColor: Colors.black,
      body: Center(
        child: ready
            ? AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: ready
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              child: Icon(
                controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}