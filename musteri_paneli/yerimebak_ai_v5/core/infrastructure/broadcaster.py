import asyncio
from typing import Set, Any
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.add(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: Any):
        """
        Broadcasts a message to all active WebSocket connections.
        Can be a string or a dict (will be JSON stringified).
        """
        import json
        if isinstance(message, (dict, list)):
            message_text = json.dumps(message, ensure_ascii=False)
        else:
            message_text = str(message)

        for connection in list(self.active_connections):
            try:
                await connection.send_text(message_text)
            except Exception:
                self.active_connections.remove(connection)

# Singleton
broadcaster = ConnectionManager()
