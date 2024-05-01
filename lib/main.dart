import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions options = const WindowOptions(
    title: 'Easy MP3',
    size: Size(800, 600),
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy MP3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
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
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  bool _downloading = false;

  void _download() async {
    setState(() {
      _downloading = true;
    });
    final url = _urlController.text;
    var yt = YoutubeExplode();
    _outputController.text = 'Downloading...';
    var video = await yt.videos.get(url);
    _outputController.text += '\nTitle: ${video.title}';
    _outputController.text += '\nAuthor: ${video.author}';
    _outputController.text += '\nDuration: ${video.duration}';

    var sanitizedTitle = video.title.replaceAll(RegExp(r'[^\w\s]+'), '');
    String? outputFileName = await FilePicker.platform.saveFile(
      dialogTitle: 'Save MP3',
      type: FileType.custom,
      allowedExtensions: ['m4a'],
      fileName: '$sanitizedTitle.m4a',
    );

    if (outputFileName == null) {
      return;
    }
    if (!outputFileName.contains(".m4a")) {
      outputFileName += ".m4a";
    }
    _outputController.text += '\nOutput: $outputFileName';

    var manifest = await yt.videos.streamsClient.getManifest(url);
    var audioStreamInfo = manifest.audioOnly.first;
    var audioStream = yt.videos.streamsClient.get(audioStreamInfo);
    var file = File(outputFileName);
    var fileStream = file.openWrite();
    await for (var data in audioStream) {
      fileStream.add(data);
    }
    await fileStream.flush();
    await fileStream.close();
    _outputController.text += '\nDownloaded to $outputFileName';
    await Process.run("ffmpeg", [
      "-i",
      outputFileName,
      "-c:v",
      "copy",
      "-c:a",
      "libmp3lame",
      "-q:a",
      "4",
      outputFileName.replaceAll('.m4a', '.mp3')
    ]).then((value) => {File(outputFileName!).delete()});
    _outputController.text +=
        '\nConverted to ${outputFileName.replaceAll('.m4a', '.mp3')}';
    setState(() {
      _downloading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                      hintText: 'Enter YouTube URL',
                      border: OutlineInputBorder()),
                )),
                const SizedBox(width: 12),
                IconButton.filled(
                  icon: const Icon(Icons.search),
                  onPressed: _download,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_downloading)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),
            Expanded(
                child: TextField(
              controller: _outputController,
              readOnly: true,
              maxLines: 10,
              decoration: const InputDecoration(
                  hintText: 'Output', border: OutlineInputBorder()),
            )),
          ],
        ),
      ),
    );
  }
}
