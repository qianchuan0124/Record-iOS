import Foundation
import zlib

enum XLSXReadError: Error {
    case invalidArchive
    case missingWorkbook
    case missingSheet
    case invalidSheet
}

enum XLSXReader {
    static func rows(from data: Data, preferredSheet: String? = nil) throws -> [[String]] {
        let sheets = try sheets(from: data)
        if let preferredSheet, let rows = sheets[preferredSheet] {
            return rows
        }
        guard let rows = sheets.values.first else {
            throw XLSXReadError.missingSheet
        }
        return rows
    }

    static func sheets(from data: Data) throws -> [String: [[String]]] {
        let archive = try ZIPArchiveReader(data: data)
        guard let workbook = archive.file(named: "xl/workbook.xml") else {
            throw XLSXReadError.missingWorkbook
        }

        let sheetList = try WorkbookParser.parse(workbook)
        let relationships = archive.file(named: "xl/_rels/workbook.xml.rels")
            .flatMap { try? RelationshipParser.parse($0) } ?? [:]
        let sharedStrings = archive.file(named: "xl/sharedStrings.xml")
            .flatMap { try? SharedStringParser.parse($0) } ?? []

        var result: [String: [[String]]] = [:]
        for sheet in sheetList {
            let target = relationships[sheet.relationshipID] ?? "worksheets/sheet1.xml"
            let sheetPath = normalizedPath(target)
            guard let sheetData = archive.file(named: sheetPath) ?? archive.file(named: "xl/worksheets/sheet1.xml") else {
                continue
            }
            if let rows = try? SheetParser.parse(sheetData, sharedStrings: sharedStrings) {
                result[sheet.name] = rows
            }
        }

        guard !result.isEmpty else {
            throw XLSXReadError.missingSheet
        }
        return result
    }

    private static func normalizedPath(_ target: String) -> String {
        if target.hasPrefix("/") {
            return String(target.dropFirst())
        }
        if target.hasPrefix("xl/") {
            return target
        }
        return "xl/" + target
    }
}

private struct WorkbookSheet {
    let name: String
    let relationshipID: String
}

private final class WorkbookParser: NSObject, XMLParserDelegate {
    private var sheets: [WorkbookSheet] = []

    static func parse(_ data: Data) throws -> [WorkbookSheet] {
        let delegate = WorkbookParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw XLSXReadError.missingWorkbook }
        return delegate.sheets
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "sheet",
              let name = attributeDict["name"] else { return }
        let relationshipID = attributeDict["r:id"] ?? attributeDict["id"] ?? ""
        sheets.append(WorkbookSheet(name: name, relationshipID: relationshipID))
    }
}

private enum RelationshipParser {
    static func parse(_ data: Data) throws -> [String: String] {
        let delegate = RelationshipDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw XLSXReadError.invalidArchive }
        return delegate.relationships
    }
}

private final class RelationshipDelegate: NSObject, XMLParserDelegate {
    var relationships: [String: String] = [:]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "Relationship",
              let id = attributeDict["Id"],
              let target = attributeDict["Target"] else { return }
        relationships[id] = target
    }
}

private enum SharedStringParser {
    static func parse(_ data: Data) throws -> [String] {
        let delegate = SharedStringDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw XLSXReadError.invalidArchive }
        return delegate.strings
    }
}

private final class SharedStringDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var inString = false
    private var inText = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "si" {
            current = ""
            inString = true
        } else if elementName == "t" && inString {
            inText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inString && inText {
            current += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "t" {
            inText = false
        } else if elementName == "si" {
            strings.append(current)
            inString = false
        }
    }
}

private enum SheetParser {
    static func parse(_ data: Data, sharedStrings: [String]) throws -> [[String]] {
        let delegate = SheetDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw XLSXReadError.invalidSheet }
        return delegate.rows
    }
}

private final class SheetDelegate: NSObject, XMLParserDelegate {
    private struct Cell {
        let column: Int
        let type: String
    }

    private let sharedStrings: [String]
    private(set) var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentCell: Cell?
    private var nextColumn = 0
    private var buffer = ""
    private var inValue = false
    private var inText = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "row" {
            currentRow = []
            nextColumn = 0
        } else if elementName == "c" {
            let ref = attributeDict["r"] ?? ""
            let column = columnIndex(from: ref) ?? nextColumn
            nextColumn = column + 1
            currentCell = Cell(column: column, type: attributeDict["t"] ?? "")
            buffer = ""
        } else if elementName == "v" && currentCell != nil {
            inValue = true
        } else if elementName == "t" && currentCell?.type == "inlineStr" {
            inText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue || inText {
            buffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "v" {
            inValue = false
        } else if elementName == "t" {
            inText = false
        } else if elementName == "c" {
            finishCell()
        } else if elementName == "row" {
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
            currentRow = []
        }
    }

    private func finishCell() {
        guard let cell = currentCell else { return }
        var value = buffer
        if cell.type == "s", let index = Int(value), sharedStrings.indices.contains(index) {
            value = sharedStrings[index]
        } else if cell.type == "b" {
            value = value == "1" ? "是" : "否"
        }

        if currentRow.count <= cell.column {
            currentRow.append(contentsOf: Array(repeating: "", count: cell.column - currentRow.count + 1))
        }
        currentRow[cell.column] = value
        buffer = ""
        currentCell = nil
    }

    private func columnIndex(from reference: String) -> Int? {
        var value = 0
        var found = false
        for character in reference.uppercased() {
            guard let ascii = character.asciiValue, ascii >= 65, ascii <= 90 else { break }
            found = true
            value = value * 26 + Int(ascii - 64)
        }
        return found ? value - 1 : nil
    }
}

private struct ZIPArchiveReader {
    private struct CentralEntry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localOffset: Int
    }

    private let bytes: [UInt8]

    init(data: Data) throws {
        bytes = [UInt8](data)
        guard !bytes.isEmpty else { throw XLSXReadError.invalidArchive }
    }

    func file(named name: String) -> Data? {
        guard let entry = centralEntries().first(where: { $0.name == name }) else { return nil }
        return extract(entry)
    }

    private func centralEntries() -> [CentralEntry] {
        guard let eocd = findEndOfCentralDirectory() else { return [] }
        let count = Int(readUInt16(eocd + 10))
        var offset = Int(readUInt32(eocd + 16))
        var entries: [CentralEntry] = []

        for _ in 0..<count {
            guard offset + 46 <= bytes.count, readUInt32(offset) == 0x02014b50 else { break }
            let method = readUInt16(offset + 10)
            let compressedSize = Int(readUInt32(offset + 20))
            let uncompressedSize = Int(readUInt32(offset + 24))
            let nameLength = Int(readUInt16(offset + 28))
            let extraLength = Int(readUInt16(offset + 30))
            let commentLength = Int(readUInt16(offset + 32))
            let localOffset = Int(readUInt32(offset + 42))
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= bytes.count else { break }
            let name = String(decoding: bytes[nameStart..<nameEnd], as: UTF8.self)
            entries.append(CentralEntry(
                name: name,
                method: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localOffset: localOffset
            ))
            offset = nameEnd + extraLength + commentLength
        }

        return entries
    }

    private func extract(_ entry: CentralEntry) -> Data? {
        let offset = entry.localOffset
        guard offset + 30 <= bytes.count, readUInt32(offset) == 0x04034b50 else { return nil }
        let nameLength = Int(readUInt16(offset + 26))
        let extraLength = Int(readUInt16(offset + 28))
        let dataStart = offset + 30 + nameLength + extraLength
        let dataEnd = dataStart + entry.compressedSize
        guard dataEnd <= bytes.count else { return nil }
        let compressed = Array(bytes[dataStart..<dataEnd])

        switch entry.method {
        case 0:
            return Data(compressed)
        case 8:
            return inflateRaw(compressed, expectedSize: entry.uncompressedSize)
        default:
            return nil
        }
    }

    private func findEndOfCentralDirectory() -> Int? {
        guard bytes.count >= 22 else { return nil }
        let minimum = max(0, bytes.count - 22 - 65_535)
        for offset in stride(from: bytes.count - 22, through: minimum, by: -1) {
            if readUInt32(offset) == 0x06054b50 {
                return offset
            }
        }
        return nil
    }

    private func readUInt16(_ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private func readUInt32(_ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
        (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) |
        (UInt32(bytes[offset + 3]) << 24)
    }

    private func inflateRaw(_ compressed: [UInt8], expectedSize: Int) -> Data? {
        var stream = z_stream()
        guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        let capacity = max(expectedSize, 1)
        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { output.deallocate() }

        let status = compressed.withUnsafeBytes { inputBuffer -> Int32 in
            stream.next_in = UnsafeMutablePointer(mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(compressed.count)
            stream.next_out = output
            stream.avail_out = uInt(capacity)
            return inflate(&stream, Z_FINISH)
        }
        guard status == Z_STREAM_END else { return nil }
        return Data(bytes: output, count: Int(stream.total_out))
    }
}
