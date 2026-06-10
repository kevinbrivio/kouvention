import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:universal_file_viewer/universal_file_viewer.dart';
import 'package:path/path.dart' as path;

class DocumentPreview extends StatelessWidget {
  final File file;
  const DocumentPreview({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(file.path);
    
    return Center(
      child: Column(
        children: [
          Expanded(child: UniversalFileViewer(file: file)),
          Gap(6.h),
          Text(
            fileName,
            style: context.text.subDescription.copyWith(
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}
