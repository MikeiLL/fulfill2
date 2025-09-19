import {
  lindt,
  choc,
  replace_content,
  on,
  DOM,
  apply_fixes,
} from "https://rosuav.github.io/choc/factory.js";
const {A, BUTTON, FORM, INPUT, LABEL, P, SPAN, TABLE, TBODY, TD, TH, TR, TEXTAREA} = lindt; //autoimport
import {simpleconfirm} from "./utils.js";
apply_fixes({methods: 1});
export function render(state) {
  if (state.error) {
    replace_content("#mainflashdlg>header", "Oops!");
    replace_content("#mainflashdlg>div", state.error);
    DOM("#mainflashdlg").showModal();
    return;
  }
  console.log(state);
  if (state.products) {
    let defaultoptions = {
      colors: ["red", "orange", "green", "blue", "green", "indigo", "violet"],
      sizes: ["small", "medium", "large"]
    }
    return replace_content("main", [
      FORM({id: "productlist"},TABLE(TBODY([
            state.products.map((p, idx) => TR({'data-id': p.id, 'data-idx': idx}, [
              TH([INPUT({name: 'productname', value: p.name || 'error'}), p.company ? ` (${p.company})` : '']),
              TD(TEXTAREA({value: JSON.stringify(p.options || defaultoptions, null, 2)} )),
              TD(BUTTON({'data-id': p.id, type: "button", class: "delete", 'data-endpoint': 'deleteproduct'}, "x"))
            ])),
        ]))),

        FORM({id: "newproduct", class: "productinputrow"},[
          LABEL([SPAN("name"), INPUT({type: "text", name: "name", autocomplete: "off"})]),
          BUTTON({id: "btnnew", type: "submit"}, "new")
        ]),
    ])
  }
  else if (state.options) {
    console.log(Object.entries(state.options[1].config))
    return replace_content("main", state.options.map(o => P({style: "display: flex; gap: 1em;"},[
      o.name,
      //Object.entries(o.config).map(([k, v]) => [SPAN(k), ": ", +v]),
      TEXTAREA(JSON.stringify(o.config))
    ])))
  }
  else return replace_content("main", [
        FORM({id: "newproducer"}, (
        TABLE(TBODY([
            state.producers.map((c, idx) => TR({'data-idx': idx}, [
              TH([A({href: `/products/${c.id}`}, c.company), ` (${c.id})`]),
              TD(c.email), TD(c.phone), TD(c.web),
              TD(BUTTON({'data-id': c.id, type: "button", class: "delete", 'data-endpoint': 'deleteproducer'}, "x"))
            ])),
            TR({class: "producerinputrow"},[
                TH([
                    LABEL([SPAN("company"), INPUT({type: "text", name: "company", autocomplete: "off"})])
                ]), TD(
                    LABEL([SPAN("email"), INPUT({type: "text", name: "email", autocomplete: "off", type: "email"})])
                ), TD(
                    LABEL([SPAN("phone"), INPUT({type: "text", name: "phone", autocomplete: "off"})])
                ), TD(
                    LABEL([SPAN("web"), INPUT({type: "text", name: "web", autocomplete: "off"})])
                ), TD(
                    BUTTON({id: "btnnew", type: "submit"}, "new")
                )])
        ])))), // end form
    ]);
}
on("click", "#btnnew", async (e) => {
    e.preventDefault();
    const closestForm = e.match.closest("form");
    fetch(`/${closestForm.id}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
          form: JSON.stringify(Object.fromEntries(new FormData(closestForm))),
          group: ws_group,
        }),
    })
    closestForm.reset();
});

on("click", ".delete", simpleconfirm("Delete producer?", async (e) => {
    e.preventDefault();
    fetch(`/${e.match.dataset.endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
          id: e.match.dataset.id,
          group: ws_group,
        }),
    })
}))

on("change", "#productlist textarea", (e) => {
  console.log(e.match.closest_data("id"));
  return;
  fetch(`/${e.match.dataset.endpoint}`, {
      method: "POST",
      headers: {
          "Content-Type": "application/json",
      },
      body: JSON.stringify({
        id: e.match.closest("tr").dataset.id,
        group: ws_group,
      }),
  })
});
