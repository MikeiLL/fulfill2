import { choc, on, DOM } from "https://rosuav.github.io/choc/factory.js";
const {H1} = choc; //autoimport
import * as utils from "./utils.js";

export function render(state) {
  const frm = DOM("#controls").elements;
  for (let attr in state) if (frm[attr]) frm[attr].value = state[attr];
  const img = DOM("#preview");
  if (state.url && state.url !== img.src) {
    img.src = state.url;
    DOM("#download").href = state.url;
    DOM("#cfgs").value = state.cfgfields.map((k) => k + ": " + state[k]).join("\n")
  }
}

on("change", "input, select", (e) => ws_sync.send({
  cmd: "configure",
  [e.match.name]: e.match.value,
}))
