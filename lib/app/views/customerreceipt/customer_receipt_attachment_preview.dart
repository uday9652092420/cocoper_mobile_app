import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/customer_receipt.dart';

Future<void> showCustomerReceiptAttachmentPreview(
  BuildContext context,
  CustomerReceiptAttachment attachment,
) {
  final isPdf = attachment.name.toLowerCase().endsWith('.pdf');
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 900,
        height: MediaQuery.sizeOf(context).height * 0.84,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close attachment preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: isPdf
                  ? SfPdfViewer.memory(attachment.bytes)
                  : InteractiveViewer(
                      child: Image.memory(
                        attachment.bytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Unable to preview this image.'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
