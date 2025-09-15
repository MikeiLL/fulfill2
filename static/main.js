import {
    lindt,
    choc,
    replace_content,
    on,
    DOM,
} from "https://rosuav.github.io/choc/factory.js";
const {A, BUTTON, FORM, INPUT, LABEL, P, SPAN, TABLE, TBODY, TD, TH, TR} = lindt; //autoimport
import {simpleconfirm} from "./utils.js";

export function render(state) {
  if (state.error) {
    replace_content("#mainflashdlg>header", "Oops!");
    replace_content("#mainflashdlg>div", state.error);
    DOM("#mainflashdlg").showModal();
    return;
  }
  console.log(state);
  if (state.products) {
    return replace_content("main", [
      FORM({id: "newproduct"}, (
        TABLE(TBODY([
            state.products.map((p, idx) => TR({'data-idx': idx}, [
              TH([p.name, p.company ? ` (${p.company})` : '']),
              TD(BUTTON({'data-id': p.id, type: "button", class: "delete", 'data-endpoint': 'deleteproduct'}, "x"))
            ])),
            TR({class: "productinputrow"},[
                TH([
                    LABEL([SPAN("name"), INPUT({type: "text", name: "name", autocomplete: "off"})])
                ]), TD(
                    BUTTON({id: "btnnew", type: "submit"}, "new")
                )])
        ])))), // end form
    ]);
  } else return replace_content("main", [
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
