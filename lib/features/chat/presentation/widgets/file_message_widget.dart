import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class FileMessageWidget extends StatelessWidget {
  final String fileName;
  final String filePath;
  final int? fileSize;
  final String? fileType;

  const FileMessageWidget({
    super.key,
    required this.fileName,
    required this.filePath,
    this.fileSize,
    this.fileType,
  });

  IconData _getFileIcon() {
    if (fileType == null) return Icons.insert_drive_file;

    final type = fileType!.toLowerCase();
    if (type.contains('image')) {
      return Icons.image;
    } else if (type.contains('video')) {
      return Icons.videocam;
    } else if (type.contains('audio')) {
      return Icons.audiotrack;
    } else if (type.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (type.contains('doc') || type.contains('txt')) {
      return Icons.description;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getFileColor() {
    if (fileType == null) return Colors.grey;

    final type = fileType!.toLowerCase();
    if (type.contains('image')) {
      return Colors.green;
    } else if (type.contains('video')) {
      return Colors.blue;
    } else if (type.contains('audio')) {
      return Colors.orange;
    } else if (type.contains('pdf')) {
      return Colors.red;
    } else if (type.contains('doc') || type.contains('txt')) {
      return Colors.indigo;
    } else {
      return Colors.grey;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getFileColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(),
              color: _getFileColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_formatFileSize(fileSize)} • ${'file_message'.tr()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // TODO: Download or open file
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening $fileName...'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.download,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
