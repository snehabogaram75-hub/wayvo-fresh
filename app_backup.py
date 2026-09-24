from flask import Flask, render_template, request, jsonify, redirect, session
from database import get_db, init_db
import requests

app = Flask(__name__)
app.secret_key = "wayvo-secret-key"

init_db()

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/signup", methods=["POST"])
def signup():
    data = request.get_json() or {}
    email = data.get("email", "").strip()
    password = data.get("password", "")

    if not email or not password:
        return jsonify({
            "success": False,
            "message": "Please enter email and password."
        })

    conn = get_db()

    try:
        conn.execute(
            "INSERT INTO users (email, password) VALUES (?, ?)",
            (email, password)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Account created successfully. You can now login."
        })

    except Exception:
        return jsonify({
            "success": False,
            "message": "This email is already registered."
        })

    finally:
        conn.close()

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json() or {}
    email = data.get("email", "").strip()
    password = data.get("password", "")

    conn = get_db()

    user = conn.execute(
        "SELECT * FROM users WHERE email = ? AND password = ?",
        (email, password)
    ).fetchone()

    conn.close()

    if user:
        session["user_id"] = user["id"]
        session["email"] = user["email"]

        return jsonify({
            "success": True
        })

    return jsonify({
        "success": False,
        "message": "Invalid email or password."
    })

@app.route("/api/chats", methods=["GET"])
def get_chats():
    if "user_id" not in session:
        return jsonify({"success": False, "chats": []})

    conn = get_db()
    chats = conn.execute(
        "SELECT id, title, created_at FROM chats WHERE user_id = ? ORDER BY id DESC",
        (session["user_id"],)
    ).fetchall()
    conn.close()

    return jsonify({
        "success": True,
        "chats": [dict(chat) for chat in chats]
    })


@app.route("/api/chats/<int:chat_id>", methods=["GET"])
def get_chat(chat_id):
    if "user_id" not in session:
        return jsonify({"success": False})

    conn = get_db()

    chat = conn.execute(
        "SELECT id, title FROM chats WHERE id = ? AND user_id = ?",
        (chat_id, session["user_id"])
    ).fetchone()

    if not chat:
        conn.close()
        return jsonify({"success": False})

    messages = conn.execute(
        "SELECT role, content FROM messages WHERE chat_id = ? ORDER BY id ASC",
        (chat_id,)
    ).fetchall()

    conn.close()

    return jsonify({
        "success": True,
        "chat": dict(chat),
        "messages": [dict(m) for m in messages]
    })


@app.route("/api/chats/new", methods=["POST"])
def new_chat():
    if "user_id" not in session:
        return jsonify({"success": False})

    conn = get_db()
    cursor = conn.execute(
        "INSERT INTO chats (user_id, title) VALUES (?, ?)",
        (session["user_id"], "New Chat")
    )
    conn.commit()
    chat_id = cursor.lastrowid
    conn.close()

    session["chat_id"] = chat_id
    session["chat_history"] = []

    return jsonify({"success": True, "chat_id": chat_id})


@app.route("/chat")
def chat():
    if "user_id" not in session:
        return redirect("/")

    return render_template("chat.html")

@app.route("/api/chat", methods=["POST"])
def api_chat():
    if "user_id" not in session:
        return jsonify({
            "success": False,
            "message": "Please login first."
        }), 401

    data = request.get_json() or {}
    message = data.get("message", "").strip()

    if not message:
        return jsonify({
            "success": False,
            "message": "Please enter a message."
        }), 400

    history = session.get("chat_history", [])

    conversation = ""
    for item in history:
        conversation += f"{item["role"]}: {item["content"]}\n"

    conversation += f"You: {message}\nWAYVO:"

    prompt = f"""You are WAYVO, a friendly personal AI assistant.
When an image is attached, actually inspect and analyze the image. Do not assume the image contents from its filename.
If an image is attached, answer questions about what is visibly present in that image.

Rules:
- Remember and use relevant information from the conversation history.
- Answer the user's actual question directly.
- Keep normal answers very short, simple, clear, and natural.
- Usually answer in 1-3 sentences.
- Do not add extra explanations, suggestions, or questions unless they are useful.
- Give detailed answers only when the user asks for details.
- If the user asks what they previously said, use the conversation history.
- Do not claim to know something that is not in the conversation.
- For health questions, provide general information only and never claim to diagnose the user.
- If the user asks for a detailed answer, then provide more detail.
- Talk naturally, like a helpful personal assistant.

Conversation history:
{conversation}
"""

    try:
        r = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.2:3b",
                "prompt": prompt,
                "stream": False
            },
            timeout=120
        )

        ai_reply = r.json().get(
            "response",
            "Sorry, I could not generate a response."
        )

    except Exception:
        ai_reply = "WAYVO AI is not available right now."

    history.append({"role": "You", "content": message})
    history.append({"role": "WAYVO", "content": ai_reply})

    session["chat_history"] = history[-20:]
    session.modified = True

    if "user_id" in session:
        conn = get_db()

        chat_id = session.get("chat_id")

        if not chat_id:
            title = message[:40] if message else "New Chat"
            cursor = conn.execute(
                "INSERT INTO chats (user_id, title) VALUES (?, ?)",
                (session["user_id"], title)
            )
            chat_id = cursor.lastrowid
            session["chat_id"] = chat_id

        conn.execute(
            "INSERT INTO messages (chat_id, role, content) VALUES (?, ?, ?)",
            (chat_id, "You", message)
        )

        conn.execute(
            "INSERT INTO messages (chat_id, role, content) VALUES (?, ?, ?)",
            (chat_id, "WAYVO", ai_reply)
        )

        conn.commit()
        conn.close()

    return jsonify({
        "success": True,
        "reply": ai_reply
    })

if __name__ == "__main__":
    app.run(debug=False, host='0.0.0.0', port=5050)
