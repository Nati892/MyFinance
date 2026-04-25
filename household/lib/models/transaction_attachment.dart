class TransactionAttachment {
  final int id;
  final String filename;
  final bool isImage;
  final String mimeType;
  final String? thumbUrl;
  final String fileUrl;

  const TransactionAttachment({
    required this.id,
    required this.filename,
    required this.isImage,
    required this.mimeType,
    this.thumbUrl,
    required this.fileUrl,
  });

  factory TransactionAttachment.fromJson(Map<String, dynamic> json) =>
      TransactionAttachment(
        id:       json['id'] as int,
        filename: json['filename'] as String,
        isImage:  json['isImage'] as bool? ?? false,
        mimeType: json['mimeType'] as String? ?? '',
        thumbUrl: json['thumbUrl'] as String?,
        fileUrl:  json['fileUrl'] as String,
      );
}
