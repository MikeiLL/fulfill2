inherit http_websocket;

constant markdown = #"# Dashboard

";


mapping(string:mixed)|Concurrent.Future http_request(Protocols.HTTP.Server.Request req) {
  return render(req, ([
    "vars": (["ws_group": "" /* type and code may be specified here */]),]));
}

__async__ mapping get_state(string|int group, string|void id, string|void type) {
  array(mapping) data = await(G->G->DB->run_query(#"
    SELECT * FROM products;
  "));
  if (!sizeof(data)) return 0;
  return (["products": data]);
}

void websocket_cmd_hello(mapping(string:mixed) conn, mapping(string:mixed) msg) {

  send_updates_all(conn->group);
}

protected void create(string name) {
  ::create(name);

}
