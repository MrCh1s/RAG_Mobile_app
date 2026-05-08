import Foundation

class BERTTokenizer {
    private var vocabulary: [String: Int] = [:]
    private var idToToken: [Int: String] = [:]
    
    init(vocabURL: URL) {
        loadVocabulary(url: vocabURL)
    }
    
    private func loadVocabulary(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                let token = line.trimmingCharacters(in: .whitespaces)
                if !token.isEmpty {
                    vocabulary[token] = index
                    idToToken[index] = token
                }
            }
            print("✓ Đã nạp Vocabulary: \(vocabulary.count) từ.")
        } catch {
            print("Lỗi: Không thể nạp vocab.txt - \(error)")
        }
    }
    
    func tokenize(text: String, maxLen: Int = 128) -> (inputIds: [Int32], attentionMask: [Int32]) {
        var inputIds = [Int32]()
        var attentionMask = [Int32]()
        
        // 1. Thêm token bắt đầu [CLS]
        let clsId = Int32(vocabulary["[CLS]"] ?? 101)
        inputIds.append(clsId)
        
        // 2. Tách từ và WordPiece tokenization đơn giản
        let words = text.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        
        for word in words {
            let wordPieces = wordPieceTokenize(word: word)
            for piece in wordPieces {
                if inputIds.count < maxLen - 1 {
                    inputIds.append(Int32(vocabulary[piece] ?? (vocabulary["[UNK]"] ?? 100)))
                }
            }
        }
        
        // 3. Thêm token kết thúc [SEP]
        let sepId = Int32(vocabulary["[SEP]"] ?? 102)
        if inputIds.count < maxLen {
            inputIds.append(sepId)
        }
        
        // 4. Tạo Attention Mask (1 cho token thực, 0 cho padding)
        attentionMask = Array(repeating: 1, count: inputIds.count)
        
        // 5. Padding cho đủ maxLen
        while inputIds.count < maxLen {
            inputIds.append(0) // [PAD] id thường là 0
            attentionMask.append(0)
        }
        
        return (inputIds, attentionMask)
    }
    
    private func wordPieceTokenize(word: String) -> [String] {
        if vocabulary[word] != nil { return [word] }
        
        var pieces = [String]()
        var start = 0
        while start < word.count {
            var end = word.count
            var curPiece = ""
            var found = false
            
            while start < end {
                var substr = String(word[word.index(word.startIndex, offsetBy: start)..<word.index(word.startIndex, offsetBy: end)])
                if start > 0 { substr = "##" + substr }
                
                if vocabulary[substr] != nil {
                    curPiece = substr
                    start = end
                    found = true
                    break
                }
                end -= 1
            }
            
            if !found {
                pieces.append("[UNK]")
                break
            } else {
                pieces.append(curPiece)
            }
        }
        return pieces
    }
}
