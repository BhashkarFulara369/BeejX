import 'package:flutter_test/flutter_test.dart';
import 'package:beejx/services/offline_rag_service.dart';

void main() {
  group('WordPieceTokenizer', () {
    final tokenizer = WordPieceTokenizer();

    setUp(() {
      // Mock Vocab Manually since we can't load file in unit test easily
      tokenizer.vocab = {
        '[CLS]': 101,
        '[SEP]': 102,
        '[UNK]': 100,
        'hello': 200,
        'world': 201,
        'farm': 202,
        'helper': 203,
        'gehu': 204
      };
    });

    test('Should tokenize known words', () {
      final text = "farm helper";
      final tokens = tokenizer.tokenize(text);
      
      // Expected: [CLS] + farm + helper + [SEP] + padding
      expect(tokens[0], 101); // [CLS]
      expect(tokens[1], 202); // farm
      expect(tokens[2], 203); // helper
      expect(tokens[3], 102); // [SEP]
    });

    test('Should handle unknown punctuation as UNK (if not in vocab)', () {
      final text = "Hello, World"; // comma is not in vocab
      final tokens = tokenizer.tokenize(text);
      
      // hello(200) -> ,(UNK=100) -> world(201)
      expect(tokens, contains(101)); // CLS
      expect(tokens, contains(200)); // hello
      expect(tokens, contains(100)); // comma -> UNK
      expect(tokens, contains(201)); // world
    });

    test('Should handle mixed case', () {
      final text = "HeLLo";
      final tokens = tokenizer.tokenize(text);
      expect(tokens, contains(200)); // should match 'hello'
    });
  });
}
