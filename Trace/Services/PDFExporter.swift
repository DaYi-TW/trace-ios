import UIKit

enum PDFExporter {
    static func makePDF(for event: TraceEvent) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
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
            var y: CGFloat = 44
            let margin: CGFloat = 40
            let width = pageRect.width - margin * 2

            draw("留痕 Trace｜事件案件摘要", attributes: titleAttributes, x: margin, y: &y, width: width)
            draw("本文件為使用者提供資料之整理結果，不構成法律意見、法律判定或證據能力認證。", attributes: bodyAttributes, x: margin, y: &y, width: width)
            y += 12
            draw("事件總覽", attributes: headingAttributes, x: margin, y: &y, width: width)
            draw("標題：\(event.title)\n發生時間：\(event.occurredAt.formatted(date: .long, time: .shortened))\n工作情境：\(event.context.isEmpty ? "未填寫" : event.context)", attributes: bodyAttributes, x: margin, y: &y, width: width)
            y += 12
            draw("使用者原始陳述", attributes: headingAttributes, x: margin, y: &y, width: width)
            draw(event.narrative.isEmpty ? "未填寫" : event.narrative, attributes: bodyAttributes, x: margin, y: &y, width: width)
            y += 12
            draw("工作影響", attributes: headingAttributes, x: margin, y: &y, width: width)
            draw(event.workImpact.isEmpty ? "未填寫" : event.workImpact, attributes: bodyAttributes, x: margin, y: &y, width: width)
            y += 12
            draw("附件索引", attributes: headingAttributes, x: margin, y: &y, width: width)
            for (index, attachment) in event.attachments.enumerated() {
                let details = "E-\(String(format: "%03d", index + 1))  \(attachment.fileName)\n匯入：\(attachment.importedAt.formatted(date: .numeric, time: .shortened))｜SHA-256：\(attachment.sha256)\n狀態：\(attachment.imageState)｜OCR：\(attachment.ocrStatus)"
                if y > 710 { context.beginPage(); y = 44 }
                draw(details, attributes: bodyAttributes, x: margin, y: &y, width: width)
                y += 8
            }
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("Trace-\(event.id.uuidString).pdf")
        try data.write(to: output, options: .atomic)
        return output
    }

    private static func draw(_ text: String, attributes: [NSAttributedString.Key: Any], x: CGFloat, y: inout CGFloat, width: CGFloat) {
        let rect = CGRect(x: x, y: y, width: width, height: 680)
        let size = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).integral.size
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: size.height), withAttributes: attributes)
        y += size.height + 6
    }
}
