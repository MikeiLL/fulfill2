inherit http_websocket;

constant markdown = #"# Dashboard
<div id=indexbox>
  Hello, el Mundo!
</div>
";

mapping(string:mixed)|Concurrent.Future http_request(Protocols.HTTP.Server.Request req) {
	// for now group is arbitrarily set to customers.
	// atm supporting two sockets, customers and quotes
	return render(req, markdown, (["vars": (["ws_group": "" /* type and code may be specified here */])]));
}

__async__ mapping get_state(string|int group, string|void id, string|void type) {
	werror("Getting state for %O %O %O\n", group, id, type);
  return (["hello": "world."]);
}

protected void create(string name) {
	::create(name);
	G->G->http_endpoints[""] = http_request;
}
