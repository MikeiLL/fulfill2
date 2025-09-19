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
  console.log(state);
  if (state.error) {
    replace_content("#mainflashdlg>header", "Oops!");
    replace_content("#mainflashdlg>div", state.error);
    DOM("#mainflashdlg").showModal();
    return;
  }
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
    fetch(`/products`, {
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
  ws_sync.send({
    "cmd": "product_options",
    "option": e.match.value,
  });
});
