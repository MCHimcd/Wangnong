from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import os
import time
import random
import threading
import json
from datetime import datetime, timedelta

# Try importing paho-mqtt (pip install paho-mqtt)
try:
    import paho.mqtt.client as mqtt
    MQTT_AVAILABLE = True
except ImportError:
    MQTT_AVAILABLE = False
    print("Warning: paho-mqtt not installed. MQTT simulation will be disabled.")

app = Flask(__name__)
CORS(app)  # Allow CORS for easy testing with App

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Temporary avatar strategy: use a fixed local file beside server.py.
# This may be replaced by upload/object storage/CDN in later versions.
FIXED_AVATAR_FILENAME = 'avatar_fixed.svg'

# ================= 增加全局 HTTP 调试日志 =================
@app.before_request
def log_request_info():
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] ---> HTTP Request: {request.method} {request.url}")
    print(f"Headers: {dict(request.headers)}")
    if request.is_json:
        try:
            body = request.get_json(silent=True)
            print(f"Body: {json.dumps(body, ensure_ascii=False, indent=2)}")
        except Exception as e:
            print(f"Failed to parse JSON body: {e}")
    elif request.data:
        print(f"Body: {request.data.decode('utf-8', errors='ignore')}")

@app.after_request
def log_response_info(response):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] <--- HTTP Response: {response.status}")
    if response.is_json:
        # 只打印前 200 个字符避免刷屏
        resp_body = json.dumps(response.get_json(), ensure_ascii=False)
        print(f"Response Body: {resp_body[:200]}{'...' if len(resp_body) > 200 else ''}\n")
    return response

# ================= 动态数据生成逻辑 =================

def generate_dynamic_stats(device_type):
    """为统计图表生成7天的动态柱状图数据"""
    unit_map = {
        'water_pump': '灌溉量(升)',
        'led_light': '补光时长(H)',
        'ai_camera': '识别病虫(次)',
        'fan': '排风时长(H)'
    }
    unit = unit_map.get(device_type, '值')
    
    points = []
    total = 0
    today = datetime.now()
    
    for i in range(6, -1, -1):
        date_label = (today - timedelta(days=i)).strftime("%m-%d")
        if device_type == 'water_pump':
            val = random.randint(5, 25)
        elif device_type == 'led_light':
            val = random.randint(2, 8)
        elif device_type == 'ai_camera':
            val = random.randint(0, 5)
        else:
            val = random.randint(1, 10)

        points.append({"timeLabel": date_label, "value": val})
        total += val

    return {
        "summary": {"total_value": total, "unit": unit},
        "points": points
    }


def generate_dynamic_history(metric='temperature', range_param='24h'):
    """生成传感器历史动态折线图数据"""
    points = []

    base_values = {
        'temperature': (25.0, 3.0),
        'humidity': (60.0, 10.0),
        'light': (10000.0, 2000.0),
        'co2': (400.0, 50.0),
        'soilTemp': (20.0, 2.0),
        'soilHumidity': (40.0, 5.0),
        'soilPh': (6.5, 0.5)
    }

    base_val, var = base_values.get(metric, (25.0, 3.0))

    if range_param == '7d':
        num_points = 7
        step_days = 1
    elif range_param == '30d':
        num_points = 30
        step_days = 1
    else:
        num_points = 24
        step_days = 0

    today = datetime.now()
    min_val, max_val, sum_val = float('inf'), float('-inf'), 0

    for i in range(num_points - 1, -1, -1):
        if step_days > 0:
            time_label = (today - timedelta(days=i)).strftime("%m-%d")
        else:
            time_label = (today - timedelta(hours=i)).strftime("%H:00")

        val = round(base_val + random.uniform(-var, var), 1)
        points.append({"timeLabel": time_label, "value": val})
        min_val = min(min_val, val)
        max_val = max(max_val, val)
        sum_val += val

    avg_val = round(sum_val / num_points, 1) if num_points > 0 else 0

    return {
        "metric": metric,
        "summary": {"max": max_val, "min": min_val, "avg": avg_val},
        "points": points
    }


ALERTS_DB = []
ALERTS_LOCK = threading.Lock()
ALERTS_MAX_SIZE = 200
ALERT_DEVICE_IDS = ["A03_Node_01", "A03_Node_02"]
ALERT_DEVICE_NAMES = {
    "A03_Node_01": "温室节点 1",
    "A03_Node_02": "温室节点 2"
}
ALERT_PUSH_INTERVAL_RANGE = (12, 20)
ALERT_TEMPLATES = [
    {
        "type": "temp_high",
        "type_name": "高温异常",
        "level": "critical",
        "source": "environment",
        "source_name": "环境监测",
        "message_builder": lambda name: f"设备{name}气温升至{random.uniform(33.0, 38.5):.1f}°C，建议立即通风降温。"
    },
    {
        "type": "humidity_low",
        "type_name": "空气湿度过低",
        "level": "warning",
        "source": "environment",
        "source_name": "环境监测",
        "message_builder": lambda name: f"设备{name}空气湿度降至{random.uniform(35.0, 45.0):.1f}%，建议及时补水。"
    },
    {
        "type": "soil_moisture_low",
        "type_name": "土壤湿度偏低",
        "level": "warning",
        "source": "environment",
        "source_name": "环境监测",
        "message_builder": lambda name: f"设备{name}土壤湿度仅{random.uniform(18.0, 28.0):.1f}%，需检查灌溉系统。"
    },
    {
        "type": "pest_warning",
        "type_name": "病害预警",
        "level": "warning",
        "source": "video",
        "source_name": "视频AI",
        "message_builder": lambda name: f"设备{name}画面疑似识别到叶片病斑，请尽快复核。"
    },
    {
        "type": "intrusion_warning",
        "type_name": "异常闯入预警",
        "level": "critical",
        "source": "video",
        "source_name": "视频AI",
        "message_builder": lambda name: f"设备{name}监控区域检测到异常闯入，请及时确认现场情况。"
    }
]


USERS_DB = {
    "admin": {
        "userId": "WangNong_001",
        "userName": "农场主",
        "phone": "13800000000",
        "password": "123456",
        "gender": "男",
        "birthDate": "1990-01-01",
        "avatarSrc": "https://example.com/avatar.jpg"
    }
}

DEVICES_DB = [
    {"id": "A03_Node_01", "name": "温室节点 1", "status": "online"},
    {"id": "A03_Node_02", "name": "温室节点 2", "status": "online"}
]

TOKENS_DB = {}


def find_user_with_key(username_or_phone):
    if username_or_phone in USERS_DB:
        return username_or_phone, USERS_DB[username_or_phone]

    for key, item in USERS_DB.items():
        if item.get("phone") == username_or_phone:
            return key, item
    return None, None


def find_user(username_or_phone):
    _, user = find_user_with_key(username_or_phone)
    return user


def get_token_from_header():
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header[7:].strip()
    return ""


def get_current_user_from_token():
    token = get_token_from_header()
    if not token:
        return "", None

    user_key = TOKENS_DB.get(token)
    if not user_key:
        return token, None

    return token, USERS_DB.get(user_key)


def query_alerts(query):
    scene = str(query.get('scene', '') or '').strip().lower()
    page = int(query.get('page', 1) or 1)
    size = int(query.get('size', 20) or 20)
    sort_by = query.get('sort_by', 'timestamp')
    order = query.get('order', 'desc')
    filter_type = query.get('filter_type', '')
    filter_status = query.get('filter_status', '')

    page = max(1, page)
    size = max(1, size)

    with ALERTS_LOCK:
        items = [dict(item) for item in ALERTS_DB]

    if scene == 'startup':
        unhandled_items = [item for item in items if not item.get('is_handled')]
        handled_items = [item for item in items if item.get('is_handled')]

        unhandled_items = sorted(unhandled_items, key=lambda x: x.get('timestamp', 0), reverse=True)
        handled_items = sorted(
            handled_items,
            key=lambda x: x.get('handle_time', 0) or x.get('timestamp', 0),
            reverse=True
        )

        handled_recent = handled_items[:10]
        startup_items = sorted(
            unhandled_items + handled_recent,
            key=lambda x: x.get('timestamp', 0),
            reverse=True
        )

        return {
            "total": len(startup_items),
            "unhandled_count": len(unhandled_items),
            "handled_recent_count": len(handled_recent),
            "items": startup_items
        }

    if filter_type and filter_type not in ('all', 'ALL'):
        items = [item for item in items if item.get('type') == filter_type or item.get('type_name') == filter_type]

    if filter_status and filter_status not in ('all', 'ALL'):
        normalized_status = str(filter_status).lower()
        if normalized_status in ('handled', 'true', '1'):
            items = [item for item in items if item.get('is_handled')]
        elif normalized_status in ('unhandled', 'false', '0'):
            items = [item for item in items if not item.get('is_handled')]

    reverse = (str(order).lower() != 'asc')
    if sort_by == 'type':
        items = sorted(items, key=lambda x: x.get('type_name', ''), reverse=reverse)
    else:
        items = sorted(items, key=lambda x: x.get('timestamp', 0), reverse=reverse)

    total = len(items)
    start = (page - 1) * size
    end = start + size
    unhandled_count = len([item for item in items if not item.get('is_handled')])
    handled_recent_count = min(10, len([item for item in items if item.get('is_handled')]))

    return {
        "total": total,
        "unhandled_count": unhandled_count,
        "handled_recent_count": handled_recent_count,
        "items": items[start:end]
    }


def get_unhandled_alert_count():
    with ALERTS_LOCK:
        return len([item for item in ALERTS_DB if not item.get('is_handled')])


def handle_alert_state(alert_id, action):
    now_ms = int(time.time() * 1000)
    with ALERTS_LOCK:
        target = next((item for item in ALERTS_DB if item.get('alert_id') == alert_id), None)

        if not target:
            target = {
                "alert_id": alert_id,
                "type": "runtime",
                "type_name": "运行时告警",
                "level": "info",
                "timestamp": now_ms,
                "message": "来自移动端的告警状态同步。",
                "source": "app",
                "source_name": "移动端",
                "is_handled": False,
                "handle_time": None
            }
            ALERTS_DB.insert(0, target)

        normalized_action = str(action or 'handle').lower()
        if normalized_action in ('unhandle', 'reopen'):
            target['is_handled'] = False
            target['handle_time'] = None
        else:
            target['is_handled'] = True
            target['handle_time'] = now_ms

        return dict(target)

# ================= Flask HTTP 路由 =================

@app.route('/api/v1/auth/login', methods=['POST'])
def login():
    req_data = request.get_json(silent=True) or {}
    username = str(req_data.get('username') or req_data.get('phone') or '').strip()
    password = str(req_data.get('password') or req_data.get('verificationCode') or '').strip()

    if not username or not password:
        return jsonify({
            "code": 400,
            "message": "username and password are required",
            "data": None
        }), 400

    user_key, user = find_user_with_key(username)
    if not user or user.get('password') != password:
        return jsonify({
            "code": 401,
            "message": "invalid username or password",
            "data": None
        }), 401

    token = f"live_token_{int(time.time())}_{username}"
    TOKENS_DB[token] = user_key

    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "token": token,
            "expires_in": 3600
        }
    })


@app.route('/api/v1/auth/register', methods=['POST'])
def register():
    req_data = request.get_json(silent=True) or {}
    phone = str(req_data.get('phone') or '').strip()
    verification_code = str(req_data.get('verificationCode') or '').strip()
    password = str(req_data.get('password') or '').strip()

    if not phone or not verification_code or not password:
        return jsonify({
            "code": 400,
            "message": "phone, verificationCode and password are required",
            "data": None
        }), 400

    exists = any(u.get('phone') == phone for u in USERS_DB.values())
    if exists:
        return jsonify({
            "code": 409,
            "message": "phone already registered",
            "data": None
        }), 409

    username = phone
    USERS_DB[username] = {
        "userId": f"WangNong_{len(USERS_DB) + 1:03d}",
        "userName": f"用户{phone[-4:]}",
        "phone": phone,
        "password": password,
        "gender": "男",
        "birthDate": "1990-01-01",
        "avatarSrc": "https://example.com/avatar.jpg"
    }

    return jsonify({
        "code": 200,
        "message": "success",
        "data": None
    })


@app.route('/api/v1/auth/forgot-password', methods=['POST'])
def forgot_password():
    req_data = request.get_json(silent=True) or {}
    phone = str(req_data.get('phone') or '').strip()
    verification_code = str(req_data.get('verificationCode') or '').strip()
    new_password = str(req_data.get('newPassword') or '').strip()

    if not phone or not verification_code or not new_password:
        return jsonify({
            "code": 400,
            "message": "phone, verificationCode and newPassword are required",
            "data": None
        }), 400

    user = find_user(phone)
    if not user:
        return jsonify({
            "code": 404,
            "message": "user not found",
            "data": None
        }), 404

    user['password'] = new_password
    return jsonify({
        "code": 200,
        "message": "success",
        "data": None
    })


@app.route('/api/v1/auth/password', methods=['PUT'])
def change_password():
    req_data = request.get_json(silent=True) or {}
    old_password = str(req_data.get('oldPassword') or '').strip()
    new_password = str(req_data.get('newPassword') or '').strip()

    if not old_password or not new_password:
        return jsonify({
            "code": 400,
            "message": "oldPassword and newPassword are required",
            "data": None
        }), 400

    _, user = get_current_user_from_token()
    if not user:
        return jsonify({
            "code": 401,
            "message": "unauthorized",
            "data": None
        }), 401

    if user.get('password') != old_password:
        return jsonify({
            "code": 400,
            "message": "old password is incorrect",
            "data": None
        }), 400

    user['password'] = new_password
    return jsonify({
        "code": 200,
        "message": "success",
        "data": None
    })


@app.route('/api/v1/auth/logout', methods=['POST'])
def logout():
    token = get_token_from_header()
    if token:
        TOKENS_DB.pop(token, None)

    return jsonify({
        "code": 200,
        "message": "success",
        "data": None
    })

@app.route('/api/v1/auth/profile', methods=['GET'])
def get_profile():
    _, user = get_current_user_from_token()
    if not user:
        user = USERS_DB.get('admin')

    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "userId": user.get('userId', ''),
            "userName": user.get('userName', ''),
            "gender": user.get('gender', ''),
            "birthDate": user.get('birthDate', ''),
            "avatarSrc": user.get('avatarSrc', '')
        }
    })

@app.route('/api/v1/auth/profile', methods=['PUT'])
def update_profile():
    req_data = request.get_json(silent=True) or {}
    _, user = get_current_user_from_token()
    if not user:
        user = USERS_DB.get('admin')

    if user:
        user['userName'] = str(req_data.get('userName') or user.get('userName', ''))
        user['gender'] = str(req_data.get('gender') or user.get('gender', ''))
        user['birthDate'] = str(req_data.get('birthDate') or user.get('birthDate', ''))
        user['avatarSrc'] = str(req_data.get('avatarSrc') or user.get('avatarSrc', ''))

    print(f"Updating profile with: {req_data}")
    return jsonify({
        "code": 200,
        "message": "success",
        "data": None
    })


@app.route('/avatar_fixed.svg', methods=['GET'])
def get_fixed_avatar_file():
    return send_from_directory(BASE_DIR, FIXED_AVATAR_FILENAME, mimetype='image/svg+xml')


@app.route('/api/v1/auth/avatar/use-fixed', methods=['POST'])
def use_fixed_avatar():
    _, user = get_current_user_from_token()
    if not user:
        user = USERS_DB.get('admin')

    avatar_url = f"{request.host_url.rstrip('/')}/{FIXED_AVATAR_FILENAME}"

    if user:
        user['avatarSrc'] = avatar_url

    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "userId": user.get('userId', ''),
            "userName": user.get('userName', ''),
            "gender": user.get('gender', ''),
            "birthDate": user.get('birthDate', ''),
            "avatarSrc": user.get('avatarSrc', avatar_url)
        }
    })


@app.route('/api/v1/traceability/scan', methods=['POST'])
def traceability_scan():
    req_data = request.get_json(silent=True) or {}
    trace_code = str(req_data.get('code') or '').strip()
    print(f"[Traceability] Received code: {trace_code}")

    fixed_text = "溯源码识别结果（测试固定文本）：作物番茄，地块A03，当前状态正常。"
    return fixed_text, 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/api/v1/articles', methods=['GET'])
def get_articles():
    # 模拟知识库文章列表
    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "total": 4,
            "items": [
                {
                    "id": "1",
                    "title": "云端种梦智能温室系统介绍(来自服务器)",
                    "date": "2024-04-10 15:48:31",
                    "thumbnail": "https://example.com/thumbnails/1.jpg"
                },
                {
                    "id": "2",
                    "title": "智能农业中的物联网技术应用",
                    "date": "2024-05-12 10:20:00",
                    "thumbnail": "https://example.com/thumbnails/2.jpg"
                }
            ]
        }
    })

@app.route('/api/v1/articles/<article_id>', methods=['GET'])
def get_article_detail(article_id):
    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "id": article_id,
            "title": f"文章详情 {article_id} (从服务器加载)",
            "date": "2024-04-10 15:48:31",
            "thumbnail": "https://example.com/thumbnails/1.jpg",
            "content": f"这是从 Python 服务器返回的动态文章内容，当前加载的 ID 是 {article_id}。云端种梦智能温室系统是一款融合了物联网、人工智能和大数据技术的现代农业解决方案。通过部署于温室内的多维度传感器（温湿度、光照、土壤环境等），系统能实时采集并分析农作物生长数据。",
            "images": []
        }
    })

@app.route('/api/v1/cameras/<device_id>/live', methods=['GET'])
def get_camera_live(device_id):
    status = "online"
    stream_url = "https://media.w3.org/2010/05/sintel/trailer.mp4"
    camera_name = f"{device_id}号大棚摄像头"
    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "cameraId": f"cam_{device_id}",
            "cameraName": camera_name,
            "status": status,
            "streamTag": "MAIN_STREAM",
            "resolution": "1080P",
            "lastHeartbeat": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "streamUrl": stream_url
        }
    })

@app.route('/api/v1/cameras/<device_id>/playback', methods=['GET'])
def get_camera_playback(device_id):
    date_str = request.args.get('date', datetime.now().strftime("%Y-%m-%d"))
    return jsonify({
        "code": 200,
        "message": "success",
        "data": [
            {
                "id": "PB_123",
                "date": f"{date_str} 08:00:00",
                "duration": "01:00:00",
                "quality": "HD",
                "available": True,
                "abnormalCount": 2
            },
            {
                "id": "PB_124",
                "date": f"{date_str} 14:30:00",
                "duration": "00:45:00",
                "quality": "720P",
                "available": True,
                "abnormalCount": 0
            }
        ]
    })

@app.route('/api/v1/cameras/<device_id>/keyframes', methods=['GET'])
def get_camera_keyframes(device_id):
    date_str = request.args.get('date', datetime.now().strftime("%Y-%m-%d"))
    return jsonify({
        "code": 200,
        "message": "success",
        "data": [
            {
                "id": "KF_001",
                "captureTime": f"{date_str} 08:15:30",
                "label": "入侵检测",
                "confidence": 0.92,
                "thumbnailHint": "https://example.com/kf_001.jpg",
                "isAbnormal": True,
                "abnormalType": "intrusion",
                "severity": "critical"
            }
        ]
    })

@app.route('/api/v1/pest-detection/analyze', methods=['POST'])
def analyze_pest():
    # 模拟接受 FormData (因为测试阶段我们可能只是接收请求)
    # 直接返回AI识别结果
    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "pestName": "番茄早疫病(网络AI模型识别)",
            "confidence": f"{round(random.uniform(85, 99), 1)}%",
            "severity": "High",
            "color": "#e74c3c",
            "suggestion": "建议喷洒百菌清或代森锰锌类杀菌剂，加强通风降低湿度。"
        }
    })

@app.route('/api/v1/equipment/stats', methods=['POST'])
def get_equipment_stats():
    payload = request.get_json(silent=True) or {}
    query = payload.get('query', {})
    device_type = query.get('device_type', 'water_pump')
    
    return jsonify({
        "code": 200,
        "message": "success",
        "data": generate_dynamic_stats(device_type)
    })

@app.route('/api/v1/sensors/<device_id>/history', methods=['GET'])
def get_sensor_history(device_id):
    range_param = request.args.get('range', '24h')
    metric = request.args.get('metric', 'temperature')
    return jsonify({
        "code": 200,
        "message": "success",
        "data": generate_dynamic_history(metric, range_param)
    })


@app.route('/api/v1/devices', methods=['GET'])
def get_devices():
    return jsonify({
        "code": 200,
        "message": "success",
        "data": DEVICES_DB
    })


@app.route('/api/v1/devices/<device_id>', methods=['GET'])
def get_device_detail(device_id):
    device_info = next((item for item in DEVICES_DB if item.get('id') == device_id), None)
    device_name = (device_info or {}).get('name', ALERT_DEVICE_NAMES.get(device_id, f"设备 {device_id}"))
    device_status = (device_info or {}).get('status', 'online')

    if device_id == "A03_Node_01" and "device_state" in globals():
        runtime_state = device_state
    else:
        runtime_state = {
            "environment": {
                "temperature": 24.6,
                "humidity": 57.2,
                "light": 9800.0,
                "co2": 410.0,
                "soilTemp": 20.4,
                "soilHumidity": 39.0,
                "soilPh": 6.4
            },
            "equipment": {
                "water_pump": False,
                "led_light": False,
                "fan": False,
                "camera": False
            },
            "mode": "manual"
        }

    env = runtime_state.get("environment", {})
    equip = runtime_state.get("equipment", {})
    is_smart_mode = str(runtime_state.get("mode", "manual")).lower() == "smart"

    return jsonify({
        "code": 200,
        "message": "success",
        "data": {
            "id": device_id,
            "name": device_name,
            "status": device_status,
            "sensorData": {
                "temperature": float(env.get("temperature", 0.0)),
                "humidity": float(env.get("humidity", 0.0)),
                "light": float(env.get("light", 0.0)),
                "co2": float(env.get("co2", 0.0)),
                "soilTemp": float(env.get("soilTemp", 0.0)),
                "soilHumidity": float(env.get("soilHumidity", 0.0)),
                "soilPh": float(env.get("soilPh", 0.0))
            },
            "deviceState": {
                "waterValveOn": False,
                "waterPumpOn": bool(equip.get("water_pump", False)),
                "ledOn": bool(equip.get("led_light", False)),
                "fanOn": bool(equip.get("fan", False)),
                "extensionOn": bool(equip.get("camera", False)),
                "smartMode": is_smart_mode
            }
        }
    })


@app.route('/api/v1/alerts/list', methods=['POST'])
def get_alerts_list():
    payload = request.get_json(silent=True) or {}
    query = payload.get('query', {}) if isinstance(payload, dict) else {}
    return jsonify({
        "code": 200,
        "message": "success",
        "data": query_alerts(query)
    })


@app.route('/api/v1/alerts/handle', methods=['POST'])
def handle_alert():
    payload = request.get_json(silent=True) or {}
    data = payload.get('data', {}) if isinstance(payload, dict) else {}
    alert_id = str(data.get('alert_id', '')).strip()
    action = data.get('action', 'handle')

    if not alert_id:
        return jsonify({
            "code": 400,
            "message": "alert_id is required",
            "data": None
        }), 400

    print(f"[Alert] Handle request received: alert_id={alert_id}, action={action}")
    updated = handle_alert_state(alert_id, action)
    return jsonify({
        "code": 200,
        "message": "success",
        "data": updated
    })

# ================= MQTT 模拟终端设备 =================

MQTT_BROKER = "broker.emqx.io"  # 如果您没有本地Broker，可以改为 "broker.emqx.io"
MQTT_PORT = 1883
DEVICE_ID = "A03_Node_01"
TELEMETRY_TOPIC = f"/wangnong_2026/device/{DEVICE_ID}/telemetry"
COMMAND_TOPIC = f"/wangnong_2026/device/{DEVICE_ID}/command"
ALERT_TOPIC_TEMPLATE = "/wangnong_2026/device/{device_id}/alert"
mqtt_runtime_client = None

# 设备内部状态
device_state = {
    "environment": {
        "temperature": 25.0,
        "humidity": 60.0,
        "light": 10000.0,
        "co2": 400.0,
        "soilTemp": 20.0,
        "soilHumidity": 40.0,
        "soilPh": 6.5
    },
    "equipment": {
        "water_pump": False,
        "led_light": False,
        "fan": False,
        "camera": False
    },
    "mode": "manual"
}

def on_connect(client, userdata, flags, rc, *args):
    print(f"[MQTT] Connected to {MQTT_BROKER}:{MQTT_PORT} with result code {rc}")
    client.subscribe(COMMAND_TOPIC)
    print(f"[MQTT] Subscribed to {COMMAND_TOPIC}")


def create_random_alert():
    device_id = random.choice(ALERT_DEVICE_IDS)
    device_name = ALERT_DEVICE_NAMES.get(device_id, device_id)
    template = random.choice(ALERT_TEMPLATES)
    timestamp = int(time.time() * 1000)
    return {
        "alert_id": f"AL_{timestamp}_{random.randint(100, 999)}",
        "device_id": device_id,
        "type": template["type"],
        "type_name": template["type_name"],
        "level": template["level"],
        "timestamp": timestamp,
        "message": template["message_builder"](device_name),
        "source": template["source"],
        "source_name": template["source_name"],
        "is_handled": False,
        "handle_time": None
    }


def append_alert(alert):
    with ALERTS_LOCK:
        ALERTS_DB.insert(0, alert)
        if len(ALERTS_DB) > ALERTS_MAX_SIZE:
            del ALERTS_DB[ALERTS_MAX_SIZE:]


def publish_alert(client, alert):
    topic = ALERT_TOPIC_TEMPLATE.format(device_id=alert.get("device_id", DEVICE_ID))
    payload = {
        "msg_type": "alert",
        "device_id": alert.get("device_id", DEVICE_ID),
        "timestamp": alert.get("timestamp", int(time.time() * 1000)),
        "data": alert
    }
    dumped_payload = json.dumps(payload, ensure_ascii=False)

    if client:
        client.publish(topic, dumped_payload, qos=1)

    print(
        f"[{datetime.now().strftime('%H:%M:%S')}] [MQTT] Published Alert -> "
        f"Device={alert.get('device_id', DEVICE_ID)} | {alert.get('type_name')} | {alert.get('message')}"
    )


def alert_loop():
    while True:
        time.sleep(random.randint(ALERT_PUSH_INTERVAL_RANGE[0], ALERT_PUSH_INTERVAL_RANGE[1]))

        unhandled_count = get_unhandled_alert_count()
        if unhandled_count > 5:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] [Alert] Skip generation: unhandled_count={unhandled_count} > 5")
            continue

        alert = create_random_alert()
        append_alert(alert)
        publish_alert(mqtt_runtime_client, alert)

def on_message(client, userdata, msg):
    print(f"[MQTT] Received command on {msg.topic}: {msg.payload.decode()}")
    try:
        payload = json.loads(msg.payload.decode())
        action = payload.get("action", {})
        target = action.get("target_device")
        cmd = action.get("command")

        if target == "mode":
            print(f"[MQTT Action] Actuating Mode -> {cmd}")
            device_state["mode"] = cmd
        else:
            is_on = (cmd == "turn_on")
            if target in device_state["equipment"]:
                device_state["equipment"][target] = is_on
                print(f"[MQTT Action] Actuating {target} -> {'ON' if is_on else 'OFF'}")

        # 指令执行后立即推送状态同步
        publish_telemetry(client)
    except Exception as e:
        print(f"[MQTT] Parse command error: {e}")

def publish_telemetry(client):
    # 模拟环境数据漂移
    env = device_state["environment"]
    env["temperature"] += random.uniform(-0.5, 0.5)
    env["humidity"] += random.uniform(-1.0, 1.0)
    env["light"] += random.uniform(-100.0, 100.0)
    env["co2"] += random.uniform(-5.0, 5.0)
    env["soilTemp"] += random.uniform(-0.2, 0.2)
    env["soilHumidity"] += random.uniform(-0.5, 0.5)
    env["soilPh"] += random.uniform(-0.02, 0.02)
    
    # 限制在合理范围
    env["temperature"] = max(10, min(env["temperature"], 40))
    env["humidity"] = max(20, min(env["humidity"], 90))
    env["light"] = max(0, min(env["light"], 50000))
    env["co2"] = max(300, min(env["co2"], 2000))
    env["soilTemp"] = max(5, min(env["soilTemp"], 40))
    env["soilHumidity"] = max(0, min(env["soilHumidity"], 100))
    env["soilPh"] = max(4.0, min(env["soilPh"], 9.0))

    # 自动模式下随机切换设备开关，模拟策略联动行为
    if device_state.get("mode") == "smart":
        equip = device_state["equipment"]
        if random.random() < 0.20:
            equip["water_pump"] = not equip["water_pump"]
        if random.random() < 0.25:
            equip["led_light"] = not equip["led_light"]
        if random.random() < 0.20:
            equip["fan"] = not equip["fan"]
        if random.random() < 0.10:
            equip["camera"] = not equip["camera"]
    
    payload = {
        "msg_type": "telemetry",
        "device_id": DEVICE_ID,
        "timestamp": int(time.time() * 1000),
        "data": device_state
    }
    dumped_payload = json.dumps(payload)
    client.publish(TELEMETRY_TOPIC, dumped_payload, qos=1)
    
    # 打印完整的 MQTT 发送日志，便于核对所有传感器是否都在更新
    env_summary = (
        f"AirTemp={env['temperature']:.1f}C, AirHumidity={env['humidity']:.1f}%, "
        f"Light={env['light']:.0f}Lux, CO2={env['co2']:.1f}ppm, "
        f"SoilTemp={env['soilTemp']:.1f}C, SoilHumidity={env['soilHumidity']:.1f}%, "
        f"SoilPh={env['soilPh']:.2f}"
    )
    eq_summary = (
        f"Pump={'ON' if device_state['equipment']['water_pump'] else 'OFF'}, "
        f"LED={'ON' if device_state['equipment']['led_light'] else 'OFF'}, "
        f"Fan={'ON' if device_state['equipment']['fan'] else 'OFF'}, "
        f"Camera={'ON' if device_state['equipment']['camera'] else 'OFF'}, "
        f"Mode={device_state['mode']}"
    )
    print(f"[{datetime.now().strftime('%H:%M:%S')}] [MQTT] Published Telemetry -> Device={DEVICE_ID} | {env_summary} | {eq_summary}")

def mqtt_loop():
    global mqtt_runtime_client
    if not MQTT_AVAILABLE: return
    try:
        # 支持 paho-mqtt 1.x 和 2.x
        try:
            from paho.mqtt.enums import CallbackAPIVersion
            client = mqtt.Client(CallbackAPIVersion.VERSION1, "WangNong_Sim_Device")
        except ImportError:
            client = mqtt.Client("WangNong_Sim_Device")
            
        client.on_connect = on_connect
        client.on_message = on_message
        mqtt_runtime_client = client
        
        print(f"[MQTT] Trying to connect to {MQTT_BROKER}...")
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_start()
        
        while True:
            publish_telemetry(client)
            time.sleep(5)  # 每5秒推送一次心跳和数据
    except Exception as e:
        mqtt_runtime_client = None
        print(f"[MQTT] Failed to start MQTT Simulator: {e}")
        print("如果是由于没有开启本地MQTT Broker，您可以将代码中的 MQTT_BROKER 改为 'broker.emqx.io' 进行外网测试。")

if __name__ == '__main__':
    # 启动后台 MQTT 模拟设备线程
    threading.Thread(target=mqtt_loop, daemon=True).start()
    threading.Thread(target=alert_loop, daemon=True).start()
    
    print("Starting Wangnong Dynamic HTTP & MQTT Mock Server on port 8080...")
    app.run(host='0.0.0.0', port=8080, debug=False, use_reloader=False)

