inherit http_websocket;
inherit annotated;

mapping default_settings = ([
  "text": "G",
  "primarycolor": "#770055",
  "secondarycolor": "#00dddd",
  "textcolor": "#6677cc",
  "shape": "circle",
  "font": "Lato",
]);

@retain: mapping favicon_configs = ([]);

array fontblacklist = ({
    "/Users/mikekilmer/Library/Fonts/FontBase",
    "/Users/mikekilmer/Library/Fonts/WebAkharThick",
    "/Users/mikekilmer/Library/Fonts/WebLipiHeavy",
    "/Users/mikekilmer/Library/Fonts/akrobat",
    "/Users/mikekilmer/Library/Fonts/encodings.dir",
    "/Users/mikekilmer/Library/Fonts/fonts.dir",
    "/Users/mikekilmer/Library/Fonts/fonts.list",
    "/Users/mikekilmer/Library/Fonts/fonts.scale",
    "/Users/mikekilmer/Library/Fonts/hebrew",
    "/Users/mikekilmer/Library/Fonts/muller_narrow font",
    "/Users/mikekilmer/Library/Fonts/skyfonts-google",
    "AdobeJensonSmallCaps",
    "Aloja Extended",
    "Amiri Quran",
    "Amiri Quran Colored",
    "Arabic Transparent",
    "DejaVu Math TeX Gyre",
    "DSSerifUni",
    "DVMarticulations",
    "LilyJAZZ-11",
    "LilyJAZZ-13",
    "LilyJAZZ-14",
    "LilyJAZZ-16",
    "LilyJAZZ-18",
    "LilyJAZZ-20",
    "LilyJAZZ-23",
    "LilyJAZZ-26",
    "LilyJAZZ-Brace",
    "TeX Gyre Adventor",
    "TeX Gyre Bonum",
    "TeX Gyre Chorus",
    "TeX Gyre Cursor",
    "TeX Gyre Heros",
    "TeX Gyre Heros Cn",
    "TeX Gyre Pagella",
    "TeX Gyre Schola",
    "TeX Gyre Termes",
    "all-the-icons",
    "file-icons",
    "github-octicons",
    "icomoon",
    "lilyjazz-chord",
    "Material Icons",
    "Noto Sans Anatolian Hieroglyphs",
    "Noto Sans Bamum",
    "Noto Sans Egyptian Hieroglyphs",
    "Noto Sans Old Persian",
    "Noto Sans Symbols",
    "Noto Sans UI",
    "OpenDyslexic Nerd Font",
    "OpenDyslexic Nerd Font Mono",
    "OpenDyslexicAlta NF",
    "OpenDyslexicAlta Nerd Font",
    "OpenDyslexicMono NF",
    "OpenDyslexicMono Nerd Font",
    "OpenDyslexicMono Nerd Font Mono",
    "Saab",
    "Weather Icons",
});

constant markdown = #"# Dashboard
<form id=controls>
  <label>Single Letter Text<input type=text name=text size=1></label>
  <label>Primary Color<input type=color name=primarycolor></label>
  <label>Secondary Color<input type=color name=secondarycolor></label>
  <label>Text Color<input type=color name=textcolor></label>
  <label>Shape/Pattern<select name=shape>
    <option value=none>None</option>
    <option value=circle>Circle</option>
    <option value=diamond>Diamond</option>
    <option value=6star>Six Pointed Star</option>
    <option value=hsplit>Horizontal Split</option>
    <option value=vsplit>Vertical Split</option>
    <option value=dsplitl>Diagonal Split Left</option>
    <option value=dsplitr>Diagonal Split Right</option>
    <option value=hstripe>Horizontal Stripes</option>
    <option value=vstripe>Vertical Stripes</option>
    <option value=dtriangle>Down Triangle</option>
    <option value=utriangle>Up Triangle</option>
    </select>
  </label>
  <label>Font<select name=font>$$fonts$$</select></label>
</form>
<div id=indexbox>
  <figure>
    <img id=preview>
    <figcaption>
      <a id=download download>Download</a>
    </figcaption>
  </figure>
  <div>
    <textarea id=cfgs readonly></textarea>
  </div>
</div>
";

constant http_path_pattern = "/favicon/%[^/]";

mapping(string:mixed)|Concurrent.Future http_request(Protocols.HTTP.Server.Request req, string tag) {
  if (!tag || tag == "") return redirect("/");
  if (sizeof(tag) > 64) return redirect("/");
  array fonts = sort(indices(Image.Fonts.list_fonts()));
  return render(req, ([
    "vars": (["ws_group": tag /* type and code may be specified here */]),
    "fonts": "<option>" + (fonts - fontblacklist) * "</option><option>" + "</option>",
    // above is a simplified approach to:
    //"fonts": map(fonts & select_fonts, lambda(string name){return sprintf("<option value=\"%s\">%<s</option>\n", (string) name);}) * "",
  ]));
}

mapping(string:mixed) generate_image(Protocols.HTTP.Server.Request req) {
  if (!req->variables->text) return redirect("/favicon/" + String.string2hex(random_string(4)));
  // first intersect (right side) then merge (pipe)
  mapping cfg = default_settings | (default_settings & req->variables);
  Image.Image icon = generate_favicon(cfg);
  array attrs = values(cfg); sort(indices(cfg), attrs);
  string etag = "W/\"" + String.string2hex(Crypto.SHA1.hash(attrs * ",")) + "\""; // weak etag
  return ([
		"type": "image/png", "data": Image.PNG.encode(icon),
		"extra_heads": (["ETag": etag, "Cache-Control": "max-age=604800"]), // 604800 seconds in a week
	]);
}

mapping get_state(string|int group, string|void id, string|void type) {
  mapping cfg = default_settings | (favicon_configs[group] || ([]));
  array keys = indices(cfg), values = values(cfg); sort(keys, values);
  array params = ({});
  //NOTE: Not using Protocols.HTTP.http_encode_query as we want to guarantee that the keys are in a consistent order
  foreach (keys; int i; string k) params += ({k + "=" + Protocols.HTTP.uri_encode(values[i])});
  cfg->url = "/favicon?" + params * "&";
  cfg->cfgfields = indices(default_settings);
  return cfg;
}

void websocket_cmd_configure(mapping(string:mixed) conn, mapping(string:mixed) msg) {
  if (!favicon_configs[conn->group]) favicon_configs[conn->group] = ([]);
  favicon_configs[conn->group] |= default_settings & msg;
  send_updates_all(conn->group);
}

protected void create(string name) {
  ::create(name);

  Image.Fonts.set_font_dirs(({"/Users/mikekilmer/Library/Fonts"}));
  G->G->http_endpoints[name] = generate_image;
}
