import 'dart:convert';
import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      darkTheme: ThemeData(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  XFile? selectedContent;
  final picker = ImagePicker();
  VideoPlayerController? cameraVideoPlayerController;
  Map<String, dynamic> transcribe = {"text": "texttext"};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Home Page"),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            (selectedContent != null)
                ? SizedBox(
                    width: double.infinity,
                    height: 224,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: VideoPlayer(
                            cameraVideoPlayerController!,
                          ),
                        ),
                        Visibility(
                          visible: cameraVideoPlayerController!.value.isPlaying,
                          child: Container(
                            height: 224,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                        Center(
                          child: InkWell(
                            onTap: () {
                              cameraVideoPlayerController!.value.isPlaying
                                  ? cameraVideoPlayerController!.pause()
                                  : cameraVideoPlayerController!.play();
                            },
                            child: Icon(
                              cameraVideoPlayerController!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : DottedBorder(
                    color: Colors.blue,
                    strokeWidth: 1,
                    borderType: BorderType.RRect,
                    radius: const Radius.circular(12.0),
                    child: GestureDetector(
                      onTap: () async {
                        selectedContent = await picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        setState(() {
                          selectedContent = selectedContent;
                          cameraVideoPlayerController =
                              VideoPlayerController.file(
                            File(selectedContent!.path),
                          )..initialize();
                        });
                        String? audioUrl =
                            await uploadFile((selectedContent?.path)!);
                        transcribe = await transcribeAudio(audioUrl!);
                        setState(() {
                          transcribe = transcribe;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        height: 224,
                        decoration: BoxDecoration(
                          color: const Color(0xffE0DDF8),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_download_outlined),
                              Container(height: 2.0),
                              Text(
                                "Ajoutez votre fichier (vidéo/audio)",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.65,
                                  color: Colors.blue,
                                ),
                              ),
                              Container(height: 2.0),
                              Text(
                                "MP4 ou MP3",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w300,
                                  fontSize: 10.0,
                                  color: Colors.blue,
                                ),
                              ),
                              Container(height: 2.0),
                              Text(
                                "Jusqu’à 10min (2Gb max)",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w300,
                                  fontSize: 10.0,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            Container(
              height: 20,
            ),
            Visibility(
                visible: transcribe.length != 1,
                child: SizedBox(
                    width: MediaQuery.of(context).size.width - 50,
                    child: Text(transcribe["text"])))
          ],
        )));
  }

  static const String baseUrl = 'https://api.assemblyai.com/v2';
  static const String baseUrlGet = 'api.assemblyai.com';
  static const String token = 'e5722962d4ea43498f1dcbd66704e957';

  Future<String?> uploadFile(String path) async {
    try {
      final headers = {
        'authorization': token,
        "Content-Type": "application/octet-stream"
      };
      final data = await File(path).readAsBytes();
      final response = await http.post(Uri.parse("$baseUrl/upload"),
          headers: headers, body: data);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData["upload_url"];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> transcribeAudio(String audioUrl) async {
    // Set the headers for the request, including the API token and content type
    final headers = {
      'authorization': token,
      'content-type': 'application/json',
    };
    final body = jsonEncode({'audio_url': audioUrl, 'language_code': 'fr'});
    // Send a POST request to the transcription API with the audio URL in the request body
    final response = await http.post(Uri.parse("$baseUrl/transcript"),
        headers: headers, body: body);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final transcriptId = responseData['id'];
      // Poll the transcription API until the transcript is ready
      while (true) {
        // Send a GET request to the polling endpoint to retrieve the status of the transcript
        final response2 = await http.get(
            Uri.https(baseUrlGet, "/v2/transcript/$transcriptId"),
            headers: headers);
        if (response2.statusCode == 200) {
          final json = jsonDecode(response2.body);
          if (json["status"] == "completed") {
            return json;
          } // If the transcription has failed, throw an error with the error message
          else if (json['status'] == "error") {
            throw Exception("Transcription failed: ${json['error']}");
          }
          // If the transcription is still in progress, wait for a few seconds before polling again
          else {
            await Future.delayed(const Duration(seconds: 3));
          }
        } else {
          throw Exception("hmmmmmmmm");
        }
      }
    } else {
      throw Exception("aaaaaaaa");
    }
  }
}
