# JSONRPC2

JSONRPC2 server that implements:
- Unix Domain sockets server via ranch
- WebServer via cowboy
- WebSockets via cowboy

The server allows you to register a common handler for the servers. Requests and responses are hidden in the server implementation.