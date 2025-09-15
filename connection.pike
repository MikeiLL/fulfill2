inherit annotated;

@retain: mapping http_session;

__async__ void http_handler(Protocols.HTTP.Server.Request req)
{

	write("incoming http request: %O %O\n", req->get_ip(), req->not_query);

	req->misc->session = http_session[req->cookies->session] || ([]);

	catch {req->misc->json = Standards.JSON.decode_utf8(req->body_raw);};

	[function handler, array args] = find_http_handler(req->not_query);

	//If we receive URL-encoded form data, assume it's UTF-8.
	// Deprecated leftover Stolebot code.
	if (req->request_headers["content-type"] == "application/x-www-form-urlencoded" && mappingp(req->variables))
	{
		//NOTE: We currently don't UTF-8-decode the keys; they should usually all be ASCII anyway.
		foreach (req->variables; string key; mixed value) catch {
			if (stringp(value)) req->variables[key] = utf8_to_string(value);
		};
	}
	mapping|string resp;
	if (mixed ex = handler && catch {
		mixed h = handler(req, @args); //Either a promise or a result (mapping/string).
		resp = objectp(h) && h->on_await ? await(h) : h; //Await if promise, otherwise we already have it.
	}) {
		werror("HTTP handler crash: %O\n", req->not_query);
		werror(describe_backtrace(ex));
		resp = (["error": 500, "data": "Internal server error\n", "type": "text/plain; charset=\"UTF-8\""]);
	}
	if (!resp)
	{
		//werror("HTTP request: %s %O %O\n", req->request_type, req->not_query, req->variables);
		//werror("Headers: %O\n", req->request_headers);
		resp = render_template("text.md", (["text": "Didn't find what you were looking for."])) | (["error": 404]);
	}
	if (stringp(resp)) resp = render_template("text.md", (["text": resp]));
	//All requests should get to this point with a response.

	//As of 20190122, the Pike HTTP server doesn't seem to handle keep-alive.
	//The simplest fix is to just add "Connection: close" to all responses.
	if (!resp->extra_heads) resp->extra_heads = ([]);
	resp->extra_heads->Connection = "close";
	resp->extra_heads["Access-Control-Allow-Origin"] = "*";
	resp->extra_heads["Access-Control-Allow-Private-Network"] = "true";
	if (sizeof(req->misc->session)) {
		// generate a session cookie
		mapping sess = req->misc->session;
		if (!sess->cookie) sess->cookie = MIME.encode_base64url(random_string(12));
		http_session[sess->cookie] = sess;

		Stdio.write_file("session.json", Standards.JSON.encode(http_session));
		// https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
		resp->extra_heads["Set-Cookie"] = sprintf("session=%s; Path=/; Max-Age=604800; HttpOnly%s",
			sess->cookie, (req->my_fd->query_context) ? "; Secure" : "");
	}
	req->response_and_finish(resp);
	// Garbage collect with quarter second Timeout.
	call_out(gc, 0.25);
}

void ws_msg(Protocols.WebSocket.Frame frm, mapping conn)
{
	if (function f = bounce(this_function)) {f(frm, conn); return;}

	mixed data;
	if (catch {data = Standards.JSON.decode(frm->text);}) return; //Ignore frames that aren't text or aren't valid JSON
	if (!stringp(data->cmd)) return;
	if (data->cmd == "init")
	{
		//Initialization is done with a type and a group.
		//The type has to match a module ("inherit websocket_handler")
		//The group has to be a string or integer.
		if (conn->type) return; //Can't init twice
		object handler = G->G->websocket_types[data->type];
		if (!handler) return; //Ignore any unknown types.
		if (string err = handler->websocket_validate(conn, data)) {
			conn->sock->send_text(Standards.JSON.encode((["cmd": "*DC*", "error": err])));
			conn->sock->close();
			return;
		}
		string group = (stringp(data->group) || intp(data->group)) ? data->group : "";
		conn->type = data->type; conn->group = group;
		handler->websocket_groups[group] += ({conn->sock});
	}
	string type = has_prefix(data->cmd||"", "prefs_") ? "prefs" : conn->type;
	if (object handler = G->G->websocket_types[type]) handler->websocket_msg(conn, data);
	else write("Message: %O\n", data);
}

void ws_close(int reason, mapping conn)
{
	if (function f = bounce(this_function)) {f(reason, conn); return;}
	werror("WebSocket close: %O\n", conn);
	if (object handler = G->G->websocket_types[conn->type])
	{
		handler->websocket_msg(conn, 0);
		handler->websocket_groups[conn->group] -= ({conn->sock});
	}
	if (object handler = conn->prefs_uid && G->G->websocket_types->prefs) //Disconnect from preferences
	{
		handler->websocket_msg(conn, 0);
		handler->websocket_groups[conn->prefs_uid] -= ({conn->sock});
	}
	m_delete(conn, "sock"); //De-floop
}

void ws_handler(array(string) proto, Protocols.WebSocket.Request req)
{
	if (function f = bounce(this_function)) {f(proto, req); return;}
	if (req->not_query != "/ws")
	{
		req->response_and_finish((["error": 404, "type": "text/plain", "data": "Not found"]));
		return;
	}
	//Lifted from Protocols.HTTP.Server.Request since, for some reason,
	//this isn't done for WebSocket requests. (not using this.)
	if (req->request_headers->cookie)
		foreach (MIME.decode_headerfield_params(req->request_headers->cookie); ; ADT.OrderedMapping m)
			foreach (m; string key; string value)
				if (value) req->cookies[key] = value;
	//End lifted from Pike's sources
	string remote_ip = req->get_ip(); //Not available after accepting the socket for some reason
	Protocols.WebSocket.Connection sock = req->websocket_accept(0);
	mapping conn = (["sock": sock, //Minstrel Hall style floop (reference loop to the socket)
		"remote_ip": remote_ip,
		"session": http_session[req->cookies->session] || ([]),
	]);
	sock->set_id(conn);
	sock->onmessage = ws_msg;
	sock->onclose = ws_close;
}

class trytls {
	inherit Protocols.WebSocket.Request;
	void opportunistic_tls(string s) {
		SSL.File ssl = SSL.File(my_fd, G->G->tlsctx);
		ssl->accept(s);
		attach_fd(ssl, server_port, request_callback);
	}
}

protected void create(string name)
{
	::create(name);
	if(!http_session) {
		catch {http_session = Standards.JSON.decode(Stdio.read_file("session.json"));}; //If error, ignore
		if (!mappingp(http_session)) http_session = ([]);
		G->G->http_session = http_session;
	}
	register_bouncer(ws_handler); register_bouncer(ws_msg); register_bouncer(ws_close);
	string cert = Stdio.read_file("certificate.pem");
	string key = Stdio.read_file("privkey.pem");
	if (cert && key) {
		string pk = Standards.PEM.simple_decode(key);
		array certs = Standards.PEM.Messages(cert)->get_certificates();
		G->G->tlsctx = SSL.Context();
		G->G->tlsctx->add_cert(pk, certs, ({"*"}));
	}
	// Keep the existing socket if we have one.
	if (G->G->httpserver) G->G->httpserver->callback = http_handler;
	else {
		//Do we have a socket from systemd?
		object|int port = 8085;
		string desc = "port " + port;
		if ((int)getenv("LISTEN_PID") == getpid() && (int)getenv("LISTEN_FDS") > 0) {
			port = Stdio.Port();
			port->listen_fd(3);
			desc = "system-provided socket";
		}
		G->G->httpserver = Protocols.WebSocket.Port(http_handler, ws_handler, port, "::");

		//Opportunistic TLS. Use it if we have it.
		if (G->G->tlsctx) {
			werror("Using opportunistic TLS\n");
			G->G->httpserver->request_program = Function.curry(trytls)(ws_handler);}

		write("WebSocket server started on %s\n", desc);
	}
}
