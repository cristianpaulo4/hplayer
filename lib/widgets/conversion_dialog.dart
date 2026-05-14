import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ConversionDialog extends StatefulWidget {
  final String filePath;

  const ConversionDialog({super.key, required this.filePath});

  @override
  State<ConversionDialog> createState() => _ConversionDialogState();
}

class _ConversionDialogState extends State<ConversionDialog> {
  String selectedFormat = 'mp4';
  bool isConverting = false;
  double progress = 0.0;
  String? statusMessage;
  int? sessionId;

  final List<String> formats = ['mp4', 'mkv', 'avi', 'mov'];

  Future<void> _startConversion() async {
    setState(() {
      isConverting = true;
      progress = 0.0;
      statusMessage = 'Iniciando conversão...';
    });

    final inputPath = widget.filePath;
    final fileName = p.basenameWithoutExtension(inputPath);
    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = p.join(outputDir.path, '${fileName}_converted.$selectedFormat');

    // FFmpeg command to convert HEVC to H.264 (for maximum compatibility)
    // -i input -c:v libx264 -preset fast -crf 22 -c:a aac output
    final ffmpegCommand = '-i "$inputPath" -c:v libx264 -preset fast -crf 22 -c:a aac -y "$outputPath"';

    FFmpegKit.execute(ffmpegCommand).then((session) async {
      final returnCode = await session.getReturnCode();
      if (mounted) {
        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            isConverting = false;
            progress = 1.0;
            statusMessage = 'Sucesso! Salvo em: $outputPath';
          });
        } else if (ReturnCode.isCancel(returnCode)) {
          setState(() {
            isConverting = false;
            statusMessage = 'Conversão cancelada.';
          });
        } else {
          setState(() {
            isConverting = false;
            statusMessage = 'Erro na conversão.';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Converter Vídeo HEVC', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escolha o formato de destino:', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          DropdownButton<String>(
            value: selectedFormat,
            dropdownColor: const Color(0xFF2A2A2A),
            isExpanded: true,
            underline: Container(height: 2, color: Colors.deepPurpleAccent),
            items: formats.map((String format) {
              return DropdownMenuItem<String>(
                value: format,
                child: Text(format.toUpperCase(), style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: isConverting ? null : (value) {
              setState(() {
                selectedFormat = value!;
              });
            },
          ),
          const SizedBox(height: 20),
          if (isConverting) ...[
            const LinearProgressIndicator(color: Colors.deepPurpleAccent),
            const SizedBox(height: 10),
          ],
          if (statusMessage != null)
            Text(
              statusMessage!,
              style: TextStyle(
                color: statusMessage!.contains('Erro') ? Colors.redAccent : Colors.greenAccent,
                fontSize: 12,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar', style: TextStyle(color: Colors.white54)),
        ),
        if (!isConverting)
          ElevatedButton(
            onPressed: _startConversion,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Converter Agora', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}
