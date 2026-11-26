import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const YTMusicTestApp());
}

class YTMusicTestApp extends StatelessWidget {
  const YTMusicTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YT Music Test',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WebViewController webController;
  final TextEditingController searchController =
      TextEditingController();

  int progress = 0;
  bool isLoading = true;
  String currentUrl = 'https://www.youtube.com';
  final List<String> importedAudio = [];

  @override
  void initState() {
    super.initState();

    webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF101116))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => progress = value);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              isLoading = true;
              currentUrl = url;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              isLoading = false;
              currentUrl = url;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تعذر تحميل الصفحة، تحقق من الإنترنت'),
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.youtube.com'));
  }

  void searchYouTube(String query) {
    final text = query.trim();
    if (text.isEmpty) return;

    final encoded = Uri.encodeComponent(text);
    final url =
        'https://www.youtube.com/results?search_query=$encoded';

    webController.loadRequest(Uri.parse(url));
    FocusScope.of(context).unfocus();
  }

  Future<void> goBack() async {
    if (await webController.canGoBack()) {
      await webController.goBack();
    }
  }

  Future<void> goForward() async {
    if (await webController.canGoForward()) {
      await webController.goForward();
    }
  }

  Future<void> reloadPage() async {
    await webController.reload();
  }

  Future<void> importAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;

      setState(() {
        importedAudio.addAll(
          result.files.map((file) => file.name),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم اختيار ${result.files.length} ملف صوتي',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء اختيار الملفات'),
        ),
      );
    }
  }

  void showDownloadInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'التنزيل متاح للملفات من المصادر التي تسمح بالتنزيل. '
          'يمكنك استيراد ملفات صوتية من جهازك.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF18171E),
        title: const Text(
          'YT Music Test',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: reloadPage,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: searchYouTube,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن أغنية أو فيديو...',
                      filled: true,
                      fillColor: const Color(0xFF22212A),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () =>
                      searchYouTube(searchController.text),
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Browser controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: goBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  onPressed: goForward,
                  icon: const Icon(Icons.arrow_forward),
                ),
                IconButton(
                  onPressed: reloadPage,
                  icon: const Icon(Icons.refresh),
                ),
                Expanded(
                  child: Text(
                    currentUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading bar
          if (isLoading)
            LinearProgressIndicator(
              value: progress == 0 ? null : progress / 100,
              minHeight: 2,
              color: Colors.red,
              backgroundColor: Colors.white12,
            ),

          // Web browser
          Expanded(
            child: WebViewWidget(
              controller: webController,
            ),
          ),

          // Action buttons
          Container(
            color: const Color(0xFF18171E),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: showDownloadInfo,
                    icon: const Icon(Icons.download),
                    label: const Text('تنزيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: importAudio,
                    icon: const Icon(Icons.library_music),
                    label: const Text('ملفاتي الصوتية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF302E39),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Imported audio list
          if (importedAudio.isNotEmpty)
            Container(
              height: 110,
              color: const Color(0xFF18171E),
              child: ListView.builder(
                itemCount: importedAudio.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.music_note,
                      color: Colors.red,
                    ),
                    title: Text(
                      importedAudio[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          importedAudio.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}