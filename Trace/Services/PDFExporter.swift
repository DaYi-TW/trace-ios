import UIKit

enum PDFExporter {
    static func makePDF(for event: TraceEvent) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - margin * 2

        let preparedAttachments: [(EvidenceAttachment, Data?)] = try event.attachments
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { attachment in
                let data = try? Data(contentsOf: EvidenceStore.url(for: attachment))
                return (attachment, data)
            }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var y: CGFloat = margin
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.label
            ]
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label
            ]
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.secondaryLabel
            ]

            func beginPageIfNeeded(_ requiredHeight: CGFloat) {
                if y + requiredHeight > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                }
            }

            func draw(_ text: String, attributes: [NSAttributedString.Key: Any], spacing: CGFloat = 6) {
                let size = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).integral.size
                beginPageIfNeeded(size.height + spacing)
                (text as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: size.height),
                    withAttributes: attributes
                )
                y += size.height + spacing
            }

            context.beginPage()
            draw("留痕 Trace｜事件證據包", attributes: titleAttributes, spacing: 10)
            draw("本文件是材料整理工具的輸出，不是法律判定或調查報告。原始附件、雜湊與使用者確認內容應一併保存。", attributes: bodyAttributes)
            draw("事件摘要", attributes: headingAttributes, spacing: 4)
            draw("標題：\(event.title)\n發生時間：\(event.occurredAt.formatted(date: .long, time: .shortened))\n情境：\(event.context.isEmpty ? "未填寫" : event.context)", attributes: bodyAttributes)

            let revision = event.currentRevision
            draw("事件敘述", attributes: headingAttributes, spacing: 4)
            draw(revision?.narrative.isEmpty == false ? revision!.narrative : (event.narrative.isEmpty ? "未填寫" : event.narrative), attributes: bodyAttributes)
            draw("可觀察的工作影響", attributes: headingAttributes, spacing: 4)
            draw(revision?.workImpact.isEmpty == false ? revision!.workImpact : (event.workImpact.isEmpty ? "未填寫" : event.workImpact), attributes: bodyAttributes)
            if let uncertainties = revision?.uncertainties, !uncertainties.isEmpty {
                draw("待確認事項：\n• " + uncertainties.joined(separator: "\n• "), attributes: bodyAttributes)
            }

            draw("附件清單（\(preparedAttachments.count) 件）", attributes: headingAttributes, spacing: 4)
            for (index, pair) in preparedAttachments.enumerated() {
                let attachment = pair.0
                let fileData = pair.1
                beginPageIfNeeded(170)
                draw("E-\(String(format: "%03d", index + 1))｜\(attachment.fileName)", attributes: headingAttributes, spacing: 3)
                draw("類型：\(attachment.kind.rawValue)  大小：\(ByteCountFormatter.string(fromByteCount: attachment.byteCount, countStyle: .file))\n匯入：\(attachment.importedAt.formatted(date: .numeric, time: .shortened))\nSHA-256：\(attachment.sha256)\n完整性：\(integrityLabel(for: attachment))", attributes: captionAttributes)

                if attachment.kind == .image, let fileData, let image = UIImage(data: fileData) {
                    let maxHeight: CGFloat = 180
                    let scale = min(contentWidth / image.size.width, maxHeight / image.size.height)
                    let imageRect = CGRect(x: margin, y: y, width: image.size.width * scale, height: image.size.height * scale)
                    beginPageIfNeeded(imageRect.height + 8)
                    image.draw(in: imageRect)
                    y = imageRect.maxY + 8
                }

                if !attachment.sourceApp.isEmpty || !attachment.imageState.isEmpty {
                    draw("聊天來源：\(attachment.sourceApp.isEmpty ? "未確認" : attachment.sourceApp)\n截圖狀態：\(attachment.imageState)", attributes: captionAttributes)
                }
                let transcript = attachment.confirmedText.isEmpty ? attachment.rawOCRText : attachment.confirmedText
                if !transcript.isEmpty {
                    draw("OCR／逐字稿（\(attachment.confirmedText.isEmpty ? "尚未確認" : "使用者已確認")）：\n\(transcript)", attributes: bodyAttributes)
                }
            }
        }

        let output = FileManager.default.temporaryDirectory.appendingPathComponent("Trace-\(event.id.uuidString).pdf")
        try data.write(to: output, options: .atomic)
        return output
    }

    private static func integrityLabel(for attachment: EvidenceAttachment) -> String {
        switch attachment.integrityStatus {
        case .valid: return "已驗證"
        case .mismatch: return "雜湊不一致"
        case .missing: return "原始檔遺失"
        case .unverified: return "尚未驗證"
        }
    }
}
