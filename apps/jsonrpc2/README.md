# JSONRPC2

Protocol independent JSONRPC2 server.
- TCP server via  latest ranch
- WebServer via  latest cowboy
- WebSockets via latest cowboy

The server allows you to register a common handler for the servers. Requests and responses are hidden in the server implementation.