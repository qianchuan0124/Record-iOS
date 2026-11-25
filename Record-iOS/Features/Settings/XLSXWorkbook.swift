import Foundation

enum XLSXCell {
    case text(String)
    case number(Double)
    case integer(Int)
}

struct XLSXSheet {
    let name: String
    let rows: [[XLSXCell]]
}

enum XLSXWorkbook {
    static func make(sheets: [XLSXSheet]) -> Data {
        var files: [(String, Data)] = [
            ("[Content_Types].xml", Data(contentTypesXML(sheets: sheets).utf8)),
            ("_rels/.rels", Data(rootRelationshipsXML.utf8)),
            ("xl/workbook.xml", Data(workbookXML(sheets: sheets).utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRelationshipsXML(sheets: sheets).utf8)),
            ("xl/styles.xml", Data(stylesXML.utf8))
        ]

        for (index, sheet) in sheets.enumerated() {
            files.append((
                "xl/worksheets/sheet\(index + 1).xml",
                Data(worksheetXML(sheet: sheet).utf8)
            ))
        }

        return ZIPWriter.make(files: files)
    }

    private static func contentTypesXML(sheets: [XLSXSheet]) -> String {
        let sheetOverrides = sheets.indices.map {
            "<Override PartName=\"/xl/worksheets/sheet\($0 + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        \(sheetOverrides)
        </Types>
        """
    }

    private static var rootRelationshipsXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private static func workbookXML(sheets: [XLSXSheet]) -> String {
        let sheetEntries = sheets.enumerated().map { index, sheet in
            "<sheet name=\"\(escape(sheet.name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>\(sheetEntries)</sheets>
        </workbook>
        """
    }

    private static func workbookRelationshipsXML(sheets: [XLSXSheet]) -> String {
        var entries = sheets.indices.map { index in
            "<Relationship Id=\"rId\(index + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(index + 1).xml\"/>"
        }
        entries.append(
            "<Relationship Id=\"rId\(sheets.count + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        )

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \(entries.joined())
        </Relationships>
        """
    }

    private static var stylesXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
        <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
        <borders count="1"><border/></borders>
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
        <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
        <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
        </styleSheet>
        """
    }

    private static func worksheetXML(sheet: XLSXSheet) -> String {
        let rows = sheet.rows.enumerated().map { rowIndex, cells in
            let cellsXML = cells.enumerated().map { columnIndex, cell in
                cellXML(reference: "\(columnName(columnIndex))\(rowIndex + 1)", cell: cell)
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cellsXML)</row>"
        }.joined()

        let widths = columnWidths(for: sheet.rows)
        let colsXML: String
        if widths.isEmpty {
            colsXML = ""
        } else {
            colsXML = "<cols>" + widths.enumerated().map { index, width in
                "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
            }.joined() + "</cols>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetViews><sheetView workbookViewId="0"/></sheetViews>
        \(colsXML)
        <sheetData>\(rows)</sheetData>
        </worksheet>
        """
    }

    private static func columnWidths(for rows: [[XLSXCell]]) -> [String] {
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return [] }

        return (0..<columnCount).map { column in
            let length = rows.reduce(0) { result, row in
                guard row.indices.contains(column) else { return result }
                return max(result, displayLength(row[column]))
            }
            let width = min(max(length + 3, 10), 40)
            return "\(width)"
        }
    }

    private static func displayLength(_ cell: XLSXCell) -> Int {
        switch cell {
        case .text(let value):
            return value.reduce(0) { $0 + ($1.unicodeScalars.first.map { $0.value > 0x2E7F ? 2 : 1 } ?? 1) }
        case .number(let value):
            return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value).count
        case .integer(let value):
            return "\(value)".count
        }
    }

    private static func cellXML(reference: String, cell: XLSXCell) -> String {
        switch cell {
        case .text(let value):
            return "<c r=\"\(reference)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
        case .number(let value):
            let number = value.isFinite
                ? String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
                : "0"
            return "<c r=\"\(reference)\"><v>\(number)</v></c>"
        case .integer(let value):
            return "<c r=\"\(reference)\"><v>\(value)</v></c>"
        }
    }

    private static func columnName(_ index: Int) -> String {
        var value = index + 1
        var result = ""
        while value > 0 {
            value -= 1
            if let scalar = UnicodeScalar(65 + value % 26) {
                result = String(Character(scalar)) + result
            }
            value /= 26
        }
        return result
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private enum ZIPWriter {
    private struct Entry {
        let name: String
        let data: Data
        let crc: UInt32
        let offset: UInt32
    }

    static func make(files: [(String, Data)]) -> Data {
        var data = Data()
        var entries: [Entry] = []
        entries.reserveCapacity(files.count)

        for (name, content) in files {
            let nameBytes = Data(name.utf8)
            let crc = crc32(content)
            let offset = UInt32(data.count)

            appendUInt32(0x04034b50, to: &data)
            appendUInt16(20, to: &data)
            appendUInt16(0x0800, to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(33, to: &data)
            appendUInt32(crc, to: &data)
            appendUInt32(UInt32(content.count), to: &data)
            appendUInt32(UInt32(content.count), to: &data)
            appendUInt16(UInt16(nameBytes.count), to: &data)
            appendUInt16(0, to: &data)
            data.append(nameBytes)
            data.append(content)

            entries.append(Entry(name: name, data: content, crc: crc, offset: offset))
        }

        let centralOffset = UInt32(data.count)
        for entry in entries {
            let nameBytes = Data(entry.name.utf8)

            appendUInt32(0x02014b50, to: &data)
            appendUInt16(20, to: &data)
            appendUInt16(20, to: &data)
            appendUInt16(0x0800, to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(33, to: &data)
            appendUInt32(entry.crc, to: &data)
            appendUInt32(UInt32(entry.data.count), to: &data)
            appendUInt32(UInt32(entry.data.count), to: &data)
            appendUInt16(UInt16(nameBytes.count), to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(0, to: &data)
            appendUInt16(0, to: &data)
            appendUInt32(0, to: &data)
            appendUInt32(entry.offset, to: &data)
            data.append(nameBytes)
        }

        let centralSize = UInt32(data.count) - centralOffset
        appendUInt32(0x06054b50, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(0, to: &data)
        appendUInt16(UInt16(entries.count), to: &data)
        appendUInt16(UInt16(entries.count), to: &data)
        appendUInt32(centralSize, to: &data)
        appendUInt32(centralOffset, to: &data)
        appendUInt16(0, to: &data)

        return data
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? 0xEDB88320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
