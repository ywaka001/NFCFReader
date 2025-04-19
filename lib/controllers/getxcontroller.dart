import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcFGetxController extends GetxController {
  final sIdm = ''.obs;
  final sEmpNo = ''.obs;

  // 社員番号抜き出し
  String getEmployeeNumber(List<int> response) {
    String sEmployeeNumber = "";

    // 13バイト目 (index 12) がブロックデータ数
    int iDataCount = response[12]; // バイトの値をそのまま取得
    List<List<int>> blockDataList = [];

    // ブロックデータを抽出 (14バイト目から開始)
    int dataStartIndex = 13; // 14バイト目のインデックス
    for (int i = 0; i < iDataCount; i++) {
      blockDataList.add(response.sublist(dataStartIndex, dataStartIndex + 16));
      dataStartIndex += 16; // 次のブロックの開始位置へ移動
    }

    if (blockDataList.length >= 2) {
      // List[0] の 13, 14, 15 バイト目を取得
      String part1 =
          String.fromCharCodes(blockDataList[0].sublist(13, 16)); // 3バイト分抽出

      // List[1] の 0, 1, 2 バイト目を取得
      String part2 =
          String.fromCharCodes(blockDataList[1].sublist(0, 3)); // 3バイト分抽出

      // 取得したデータを結合して社員番号として返す
      sEmployeeNumber = part1 + part2;
    }

    return sEmployeeNumber;
  }

  // NFCF読み込み
  void readFelicaBlocks() async {
    if (!await NfcManager.instance.isAvailable()) {
      print('NFCが使用できません');
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          var nfcF = tag.data['nfcf'];
          if (nfcF == null) {
            print('FeliCaデータが見つかりません');
            return;
          }

          // サービスコード
          List<int> serviceCode = [0x0B, 0x00]; // サービスコード 00,0B
          List<int> blockList = [0x80, 0x01, 0x80, 0x02];

          // リクエストコマンドの作成
          final cmd = [
            0x06, // コマンドコード (Read Without Encryption)
            ...nfcF['identifier'], // IDm
            serviceCode.length ~/ 2, // サービス数
            ...serviceCode, // サービスコード
            blockList.length ~/ 2, // ブロック数
            ...blockList // ブロックリスト
          ];
          final command = Uint8List.fromList([cmd.length + 1, ...cmd]);

          // NFCコマンド送信
          final nfcf = NfcF.from(tag);
          var response = await nfcf?.transceive(data: command);

          if (response != null && response.length >= 2) {
            // ステータスフラグチェック
            int status1 = response[10];
            int status2 = response[11];

            if (status1 == 0x00 && status2 == 0x00) {
              // ブロックデータ取得 (2バイトのステータスフラグをスキップ)
              List<int> blockData = response.sublist(2);
              print('読み取り成功: ${blockData.map((e) => e.toRadixString(16))}');

              // 社員番号
              final sEmployeeNumber = getEmployeeNumber(response);
              print('社員番号: $sEmployeeNumber');

              sEmpNo.value = sEmployeeNumber;
              sIdm.value = nfcF['identifier']
                  .map((e) => e.toRadixString(16).padLeft(2, '0'))
                  .join(" ");
            } else {
              print(
                  'エラー発生: Status1=${status1.toRadixString(16)}, Status2=${status2.toRadixString(16)}');
            }
          } else {
            print('レスポンスが不正です');
          }
        } catch (e) {
          print('エラー発生: $e');
        } finally {
          NfcManager.instance.stopSession();
        }
      },
    );
  }
}
