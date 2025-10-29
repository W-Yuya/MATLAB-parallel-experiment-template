import socket
import threading
import time
import os
import signal
import json
import re
from flask import Flask, jsonify, request
from flask_cors import CORS

# ----- 設定 -----
HOST = '127.0.0.1'
PORT = 12345

# SHUTDOWN_MESSAGE と INIT_PREFIX, FINISH_MESSAGE はJSON形式になったため不要になりますが、
# 互換性のため残しておくこともできます。ここではJSONベースに特化させます。
# SHUTDOWN_MESSAGE = "SHUTDOWN_SERVER"
# INIT_PREFIX = "INIT:"
# FINISH_MESSAGE = "FINISH"

# ----- 状態管理 -----
received_indices = set()
total_sum = 0
lock = threading.Lock()
status_flag = "waiting"  # "waiting" | "running" | "done"
init_time = None
end_time = None
total = 100
worker_map = {}  # worker_id -> list of indices (例: {'Worker 1': [1, 5, 9], 'local': [2, 6]})
index_log = []  # List of dicts with keys: timestamp, index, worker

# ----- Flask WebAPI -----
app = Flask(__name__)
CORS(app)

@app.route('/status')
def status():
    with lock:
        done = len(received_indices)
        if status_flag == "running":
            elapsed = time.time() - init_time if init_time else 0
        elif status_flag == "done":
            elapsed = end_time - init_time if init_time and end_time else 0
        else:
            elapsed = 0

        avg_time = elapsed / done if done > 0 else 0
        est_remaining = (total - done) * avg_time if done > 0 else 0

        # ワーカー別完了タスク数
        worker_counts = {str(k): len(v) for k, v in worker_map.items()}

        # ここでは簡易的に、ワーカーごとの平均時間は全体平均を流用します。
        # 個々のタスクにかかった時間を正確に記録・計算するには、
        # index_log に開始時刻と終了時刻を持たせるなどのより詳細なロギングが必要です。
        worker_times = {str(k): round(avg_time, 2) if v > 0 else 0 for k, v in worker_counts.items()}
        
        log_entries = index_log[-50:]  # 最新50件

        return jsonify({
            "received": done,
            "total": total,
            "percent": round(done / total * 100, 1),
            "status": status_flag,
            "elapsed": round(elapsed, 1),
            "workers": worker_counts, # 修正: worker_mapから直接タスク数を取得
            "avg_time": round(avg_time, 2),
            "est_remaining": round(est_remaining, 1),
            "worker_times": worker_times,
            "log": log_entries
        })

@app.route('/shutdown', methods=['POST'])
def shutdown():
    print("Webからシャットダウン要求を受信")
    def delayed_shutdown():
        time.sleep(1)
        os.kill(os.getpid(), signal.SIGINT) # SIGINTを送信してメインスレッドを終了させる
    threading.Thread(target=delayed_shutdown).start()
    return jsonify({"message": "サーバーをシャットダウンしました。"})

# ----- 通信処理 -----
def handle_client(conn, addr):
    global total_sum, status_flag, init_time, end_time, total
    print(f"クライアント {addr} が接続")
    buffer = "" # 受信データを一時的に保持するバッファ

    while True:
        try:
            data = conn.recv(4096) # バッファサイズを大きくしました
            if not data:
                print(f"クライアント {addr} が接続を閉じました。")
                break
            
            # 受信データをUTF-8でデコードし、バッファに追加
            # decode中にエラーが発生する可能性があるためtry-exceptで囲む
            buffer += data.decode('utf-8') 
            
            # 改行文字でメッセージを区切る
            # 最後の要素は不完全なメッセージかもしれないのでバッファに戻す
            messages = buffer.split('\n')
            buffer = messages.pop() if messages and not buffer.endswith('\n') else "" # 最後の要素が空でなければバッファに戻す

            for msg_str in messages:
                if not msg_str.strip(): # 空行はスキップ
                    continue

                print(f"受信 (処理中): {msg_str}")
                try:
                    message = json.loads(msg_str) # JSONとしてパース

                    with lock: # 共有リソースへのアクセスはロックで保護
                        msg_type = message.get('type')

                        if msg_type == 'INIT':
                            total = message.get('num_experiment', 100) # デフォルト値100
                            init_time = time.time()
                            status_flag = "running"
                            received_indices.clear()
                            worker_map.clear()
                            index_log.clear()
                            total_sum = 0
                            print(f"--- 実験開始 (全体: {total}) ---")
                        
                        elif msg_type == 'PROGRESS':
                            task_id = message.get('task_id')
                            worker_id = message.get('worker_id', 'unknown') # ワーカーIDがない場合を考慮

                            # ワーカーIDの成形(Venus1 -> Venus01, グラフで整列させるため)
                            worker_id = format_with_zero_padding(worker_id)
                            
                            if task_id is not None:
                                received_indices.add(task_id)
                                worker_map.setdefault(worker_id, []).append(task_id)
                                index_log.append({
                                    "timestamp": time.time(),
                                    "index": task_id,
                                    "worker": worker_id
                                })
                                total_sum += task_id
                                print(f"処理済み: {len(received_indices)}/{total} (タスク: {task_id}, ワーカー: {worker_id})") # 頻繁に出力されるのでコメントアウト

                        elif msg_type == 'FINISH':
                            end_time = time.time()
                            status_flag = "done"
                            print("\n--- 実験終了 ---")
                            print(f"受信数: {len(received_indices)}")
                            print(f"経過時間: {round(end_time - init_time, 1)} 秒")
                        
                        # SHUTDOWN_SERVERメッセージを受信した場合（Matlab側で送信するなら残す）
                        # elif msg_str == SHUTDOWN_MESSAGE:
                        #     conn.sendall(b"SERVER_SHUTDOWN_ACK")
                        #     print("シャットダウンメッセージを受信しました。クライアント接続を閉じます。")
                        #     break # whileループを抜けて接続を閉じる

                        else:
                            print(f"不明なメッセージタイプを受信: {message}")

                except json.JSONDecodeError as e:
                    print(f"JSONデコード失敗: {msg_str} ({e})")
                    with open("json_decode_errors.log", "a", encoding="utf-8") as f:
                        f.write(f"[{time.time()}] JSONDecodeError: {msg_str}\n")
                except Exception as e:
                    print(f"メッセージ処理中にエラーが発生: {msg_str} ({e})")
        except UnicodeDecodeError as e:
            print(f"UTF-8デコード失敗: {e}. 受信データの一部: {data[:50]}...")
            buffer = "" # エラーが発生した場合はバッファをリセット
        except Exception as e:
            print(f"クライアント通信中に予期せぬエラー: {e}")
            break # エラー発生時は接続を閉じる

    conn.close()

# ----- 起動 -----
def flask_thread():
    # Flaskアプリはデバッグモードを無効にし、本番環境のように実行
    # production_readyなサーバーWSGIを使用するのが理想 (例: Gunicorn, Waitress)
    # 簡易的にapp.runを使用する場合でも、threaded=Trueやuse_reloader=Falseを設定
    print("Flask Webサーバー (ポート5000) 起動中...")
    app.run(port=5000, debug=False, use_reloader=False, threaded=True)

def start_server():
    # Flaskスレッドを先に開始
    flask_daemon_thread = threading.Thread(target=flask_thread, daemon=True)
    flask_daemon_thread.start()

    # TCPサーバーの準備
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # ソケットの再利用を許可
        s.bind((HOST, PORT))
        s.listen()
        print(f"TCPサーバーが {HOST}:{PORT} で待機中...")
        while True:
            try:
                conn, addr = s.accept()
                # クライアントごとにスレッドを立てて処理
                threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()
            except KeyboardInterrupt:
                print("サーバーを停止します。")
                break
            except Exception as e:
                print(f"TCPサーバーでエラーが発生しました: {e}")
                # エラーが繰り返し発生する場合は、ここで終了するか再試行するかを検討
                break

def format_with_zero_padding(input_string):
    """
    文字列の末尾にある数字を識別し、1桁の数字であれば2桁にゼロパディングします。
    """
    # 正規表現パターン:
    # 1. (.*?)  : 任意の文字が0回以上続く（非貪欲マッチ）。接頭辞（例: Venus, Worker）をキャプチャグループ1とする。
    # 2. (\d{1,2}) : 1桁または2桁の数字にマッチ。数字部分をキャプチャグループ2とする。
    # 3. $      : 文字列の末尾を示す。
    pattern = r'(.*?)(\d{1,2})$'
    
    match = re.match(pattern, input_string)
    
    if match:
        print(f"ここ：{match.group(1)} + {match.group(2)}")
        prefix = match.group(1) # 例: 'Venus'
        number_str = match.group(2) # 例: '1', '12'
        number = int(number_str)

        # 数字を2桁にゼロパディングする（例: 1 -> '01', 12 -> '12'）
        # f-string の :02d 形式で実現
        padded_number = f'{number:02d}'
        
        return prefix + padded_number
    else:
        # パターンにマッチしない場合は、元の文字列をそのまま返す
        return input_string

if __name__ == "__main__":
    start_server()